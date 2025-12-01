# Architecture Overview

このプロジェクトは **Clean Architecture (Hexagonal Architecture)** に基づいて設計されています。

## Clean Architectureの解釈

Clean Architectureの核心は「**依存関係の方向を制御する**」ことです。外側の層（Infrastructure）は内側の層（Application, Model）に依存しますが、逆は許されません。

### 依存関係ルール
```
Infrastructure → Application → Model
    ↓                ↓           ↓
  外部技術         ユースケース  ビジネスルール
```

- **Model（最も内側）**: ビジネスルールとエンティティ。外部に依存しない純粋なドメインロジック。
- **Application（中間層）**: ユースケース。Modelを使用してビジネスフローを実装。
- **Infrastructure（最も外側）**: 外部技術（HTTP, DB, Queue）。ApplicationとModelのインターフェースに依存。

## ディレクトリ構造と責任境界

```
internal/
├── model/              # ドメインモデル・インターフェース（最も内側）
├── application/        # ユースケース（中間層）
└── infrastructure/     # 外部技術実装（最も外側）
```

### `internal/model/`
**役割**: ドメインエンティティ、ビジネスルール、インターフェース定義

**責任**:
- ビジネスエンティティの定義（User, Post, Followなど）
- ビジネスルールの検証（例: フォロー関係の整合性）
- インターフェースの定義（Repository, Consumer, MessageHandlerなど）
- カスタムエラー定義（ErrNotFound, ErrDuplicateなど）

**依存関係**: 外部ライブラリに依存しない（標準ライブラリのみ許可）

### `internal/application/`
**役割**: ユースケースの実装

**責任**:
- ビジネスフローの実装（Create, Update, Follow, PostTweetなど）
- トランザクション境界の定義
- ドメインモデルの組み立て
- バリデーション

**依存関係**: `internal/model` のみに依存（Infrastructureには依存しない）

### `internal/infrastructure/`
**役割**: 外部技術の実装

**責任**:
- HTTP APIハンドラー
- データベースアクセス（Repository実装）
- メッセージキューコンシューマー/プロデューサー
- 外部サービス連携

**依存関係**: `internal/application` と `internal/model` に依存可能

## マルチドメイン構成例: SNSアプリケーション

SNSのように複数のドメインがある場合の構成例を示します。

### ドメイン構成
- **User**: ユーザー管理
- **Follow**: フォロー/フォロワー関係
- **Post**: 投稿（ツイート）
- **Timeline**: タイムライン（複数ドメインの集約）

### ディレクトリ構造

```
internal/
├── model/
│   ├── user.go           # Userエンティティ、リクエスト/レスポンス
│   ├── follow.go         # Followエンティティ
│   ├── post.go           # Postエンティティ
│   ├── timeline.go       # Timelineエンティティ
│   ├── error.go          # 共通エラー
│   ├── consumer.go       # Consumerインターフェース
│   └── message.go        # Messageインターフェース
│
├── application/
│   ├── user/
│   │   └── service.go    # User CRUD
│   ├── follow/
│   │   └── service.go    # Follow/Unfollow, GetFollowers, GetFollowing
│   ├── post/
│   │   └── service.go    # Post CRUD, Like, Retweet
│   └── timeline/
│       └── service.go    # GetHomeTimeline（複数ドメインを集約）
│
└── infrastructure/
    ├── http/
    │   ├── handler/
    │   │   ├── user_handler.go
    │   │   ├── follow_handler.go
    │   │   ├── post_handler.go
    │   │   └── timeline_handler.go
    │   └── server.go
    │
    ├── database/
    │   └── postgres/
    │       ├── queries/
    │       │   ├── users.sql
    │       │   ├── follows.sql
    │       │   ├── posts.sql
    │       │   └── timeline.sql     # JOIN込みクエリ
    │       └── schema/
    │           ├── 001_users.sql
    │           ├── 002_follows.sql
    │           └── 003_posts.sql
    │
    └── queue/
        └── handler/
            ├── user_created.go
            ├── follow_created.go
            └── post_created.go
```

### ドメイン間の依存関係の扱い

#### 原則: Application層で他ドメインのServiceを注入
`timeline.Service` は複数ドメインのデータを必要とするため、以下のように実装します：

```go
// internal/application/timeline/service.go
package timeline

import (
    "context"
    "github.com/example/internal/application/post"
    "github.com/example/internal/application/follow"
    "github.com/example/internal/model"
)

type Service struct {
    postService   *post.Service
    followService *follow.Service
}

func NewService(postService *post.Service, followService *follow.Service) *Service {
    return &Service{
        postService:   postService,
        followService: followService,
    }
}

func (s *Service) GetHomeTimeline(ctx context.Context, userID string, limit int) ([]*model.Post, error) {
    // 1. フォロー中のユーザーIDリストを取得
    followingIDs, err := s.followService.GetFollowingIDs(ctx, userID)
    if err != nil {
        return nil, err
    }

    // 2. フォロー中のユーザーの投稿を取得（自分の投稿も含む）
    return s.postService.GetPostsByUserIDs(ctx, append(followingIDs, userID), limit)
}
```

#### データベースレイヤーでの集約も可能
パフォーマンスが重要な場合、SQLのJOINで取得する専用クエリを用意します：

```sql
-- internal/infrastructure/database/postgres/queries/timeline.sql
-- name: GetHomeTimeline :many
SELECT p.*
FROM posts p
INNER JOIN follows f ON p.user_id = f.following_id
WHERE f.follower_id = $1
   OR p.user_id = $1
ORDER BY p.created_at DESC
LIMIT $2;
```

この場合、`timeline.Service` は直接 `*sqlc.Queries` に依存します。

### 責任境界の判断基準

| ドメイン | application層の責任 | infrastructure層の責任 |
|---------|-------------------|----------------------|
| **User** | バリデーション、重複チェック | DB CRUD |
| **Follow** | フォロー関係の整合性チェック（自分自身をフォローしない等） | DB CRUD、N+1問題の解決 |
| **Post** | 投稿内容のバリデーション、文字数制限 | DB CRUD、メディア保存 |
| **Timeline** | フォローリストと投稿の集約ロジック | 高速なJOINクエリの実行 |

### ポイント
1. **1ドメイン = 1ディレクトリ**（application, infrastructure両方）
2. **Application層は他のApplication層のServiceを注入可能**（DIで解決）
3. **Model層にドメイン間の依存は書かない**（純粋なエンティティのみ）
4. **Infrastructure層は複数ドメインのデータを効率的に取得する最適化を担当**

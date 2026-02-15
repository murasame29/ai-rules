# STYLEGUIDE.md

コーディングスタイルとコミュニケーションルールを定義します。

---

## 📚 目次

1. [Golang Coding Rules](#1-golang-coding-rules)
2. [命名規則](#2-命名規則)
3. [Communication Rules](#3-communication-rules)

---

## 1. Golang Coding Rules

### Project Structure
```
cmd/        # エントリポイント
internal/   # プライベートコード
pkg/        # 共有ライブラリ
```

### Error Handling

```go
// Wrapping - 常にコンテキストを追加
if err != nil {
    return fmt.Errorf("failed to create user: %w", err)
}

// Checking - errors.Is, errors.As を使用
if errors.Is(err, ErrNotFound) {
    return nil, ErrUserNotFound
}

// Custom Errors - internal/model で定義
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
)
```

### Context
- 第一引数に `ctx context.Context` を受け取る
- 構造体に保持しない

```go
// Good
func (s *Service) GetUser(ctx context.Context, id string) (*User, error)

// Bad - 構造体にcontextを保持
type Service struct {
    ctx context.Context  // NG
}
```

### Logging
- `log/slog` を使用
- トレースIDを含める

```go
logger.InfoContext(ctx, "user created",
    slog.String("user_id", user.ID),
)
```

### Testing
- テーブル駆動テストを推奨
- モック (`gomock` 等) を使用可能に設計

```go
func TestGetUser(t *testing.T) {
    tests := []struct {
        name    string
        id      string
        want    *User
        wantErr bool
    }{
        {"valid user", "123", &User{ID: "123"}, false},
        {"not found", "999", nil, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // test implementation
        })
    }
}
```

---

## 2. 命名規則

### パッケージ名
- 小文字、単数形
- 短く、説明的に

```go
// Good
package user
package auth

// Bad
package users      // 複数形
package userService // camelCase
```

### 変数・関数名
| 種類 | 規則 | 例 |
|------|------|-----|
| エクスポート | PascalCase | `GetUser`, `UserService` |
| 非エクスポート | camelCase | `getUserByID`, `userRepo` |
| 定数 | PascalCase | `MaxRetries`, `DefaultTimeout` |
| インターフェース | 動詞+er | `Reader`, `UserRepository` |

### ファイル名
- snake_case
- テストは `_test.go` サフィックス

```
user_service.go
user_service_test.go
```

### 略語
- 一般的な略語は大文字: `ID`, `URL`, `HTTP`, `API`
- 先頭の場合は全て大文字または小文字: `userID`, `HTTPClient`

---

## 3. Communication Rules (AI Agent)

AIエージェントとのコミュニケーションルール。

| 項目 | ルール |
|------|--------|
| Language | 日本語 (Japanese) |
| Technical Terms | 英単語のまま使用 |
| Tone | プロフェッショナルかつ簡潔 |

### 例
```
Good: "Dependency Injection を使用してください"
Bad:  "依存性注入を使用してください"
```

### コードコメント
- 公開APIには必ずGoDocコメントを記述
- 日本語でも英語でも可（プロジェクトで統一）

```go
// GetUser はユーザーIDからユーザー情報を取得します。
// 見つからない場合は ErrNotFound を返します。
func (s *Service) GetUser(ctx context.Context, id string) (*User, error)
```

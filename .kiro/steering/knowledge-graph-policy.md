# Knowledge Graph 運用ルール（Qdrant Memory）

エンティティ・関係が追跡できる形で蓄積すること。

## 使用ツール

- `qdrant-find`: 過去の知見を検索
- `qdrant-store`: 知見を保存

このサーバーはローカルの `fastembed`（`sentence-transformers/all-MiniLM-L6-v2`）で
埋め込みを生成するため、外部APIキーは不要。エンティティ/リレーションの構造化API
（`create_entities`等）は無いので、`metadata`（payload）にentity/relation情報を
自分で構造化して埋め込む。

## ドメイン分離（コレクション選択）

Qdrantはワークスペースごとにコレクションを分けて、ドメイン間で知見が
混ざらないようにしている。ツールは同名でも、開いているワークスペースの
`.kiro/settings/mcp.json` によって接続先コレクションが変わる。

- `qdrant-memory`: ワークスペース専属の知見。ワークスペースの
  `.kiro/settings/mcp.json` で `COLLECTION_NAME` を上書きしている
  （例: `optfit` → `murasame29-optfit`）。**そのワークスペース/ドメイン固有の
  情報はここに記録する。**
- `qdrant-common`: 全ワークスペースに共通するコレクション
  （`murasame29-common`）。ユーザーレベル設定のみで定義されており、
  どのワークスペースからも同じ場所を指す。**ドメインを問わず使う汎用的な
  知見（個人の作業習慣、共通で使うコマンド、複数ドメインに関係するインフラの
  知見など）はここに記録する。**

判断に迷う場合は「他のドメイン（homelab/副業）から見ても意味を持つ情報か」
で判断し、Yesなら `qdrant-common`、No（そのドメイン固有）なら `qdrant-memory`
に記録する。ドメイン固有の情報を誤って `qdrant-common` に書かない
（プロジェクトの内部事情や機密性のある業務知見が他ドメインから検索できて
しまうため）。

## タスク開始時

1. これから取り組むタスクに関連するキーワード（機能名、コンポーネント名、
   ファイルパスなど）で `qdrant-find` を実行し、過去の知見・決定事項・詰まった点が
   ないか確認する。
2. ドメイン固有の知見だけでなく、`qdrant-common` も合わせて検索し、
   共通の知見（作業習慣・共通インフラ等）が使えないか確認する。
3. 関連する知見が見つかった場合は、その内容を踏まえて作業を進める。

## タスク完了時

`qdrant-store` で以下の形式に従い記録する。

```json
{
  "information": "何をしたか・何が分かったかを1〜3文の自然文で",
  "metadata": {
    "entity": "対象の一意な識別子（例: optfit-core-ci, cloud-to-edge-stuck-monitor）",
    "entity_type": "component | task | decision | incident | config など",
    "relations": [
      { "to": "関連エンティティの識別子", "type": "uses | depends_on | blocks | part_of など" }
    ],
    "tags": ["自由なキーワード"],
    "date": "YYYY-MM-DD"
  }
}
```

### 記録すべき内容

- 設計判断とその理由（なぜAを選びBを選ばなかったか）
- 詰まった点と解決策（同じ問題に二度時間を使わないため）
- 変更した設定・インフラの状態（例: Qdrantサーバーの構成、バックアップ方式）
- エンティティ間の関係（例: `qdrant-memory` は `qdrant-server` に `depends_on`）

### 記録の粒度

- タスク単位で1件以上。大きなタスクは複数の観察に分けてよい。
- 同じエンティティについて複数回記録する場合は `entity` 識別子を統一し、
  後から `qdrant-find` で名寄せしやすくする。

## 注意

- 秘密情報（APIキー、パスワード、個人情報）は記録しない。
- entityの識別子は英数字とハイフンで統一し、表記ゆれ（大文字小文字・別名）を避ける。

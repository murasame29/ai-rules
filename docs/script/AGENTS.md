# Script AGENTS.md

CLI、Makefile、シェルスクリプトに関するルールを定義します。

---

## 📚 目次

1. [CLI設計ルール](#1-cli設計ルール)
2. [Makefile規約](#2-makefile規約)
3. [シェルスクリプト規約](#3-シェルスクリプト規約)

---

## 1. CLI設計ルール

### ライブラリ
- **推奨**: `github.com/spf13/cobra`
- **設定**: `github.com/spf13/viper` (環境変数/設定ファイル)

### 構造
```
cmd/
└── cli/
    ├── main.go      # エントリポイント
    ├── root.go      # ルートコマンド
    └── user.go      # サブコマンド
```

### コマンド設計原則
- サブコマンド形式: `app <resource> <action>`
- 例: `app user create`, `app user list`
- フラグは長形式と短形式を提供: `--output`, `-o`

### 出力形式
- デフォルト: 人間が読みやすい形式
- `--output json` でJSON出力をサポート
- エラーは `stderr` に出力

---

## 2. Makefile規約

### 基本構造
```makefile
.PHONY: all build test lint clean

# デフォルトターゲット
all: build

# ビルド
build:
	go build -o bin/app ./cmd/app

# テスト
test:
	go test -v ./...

# リント
lint:
	golangci-lint run

# クリーン
clean:
	rm -rf bin/
```

### 命名規則
| ターゲット | 用途 |
|-----------|------|
| `build` | バイナリビルド |
| `test` | テスト実行 |
| `lint` | 静的解析 |
| `fmt` | フォーマット |
| `clean` | 成果物削除 |
| `dev` | 開発サーバー起動 |
| `migrate` | DBマイグレーション |
| `generate` | コード生成 |

### ルール
- `.PHONY` を明示的に宣言
- ヘルプターゲットを提供
- 環境変数は `?=` でデフォルト値を設定

```makefile
PORT ?= 8080

dev:
	PORT=$(PORT) go run ./cmd/app
```

---

## 3. シェルスクリプト規約

### ヘッダー
```bash
#!/usr/bin/env bash
set -euo pipefail
```

| オプション | 効果 |
|-----------|------|
| `-e` | エラー時に即座に終了 |
| `-u` | 未定義変数をエラーとする |
| `-o pipefail` | パイプラインのエラーを検出 |

### 変数
```bash
# 定数は大文字
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ローカル変数は小文字
local file_path="${1:-}"
```

### 関数
```bash
# 関数名はsnake_case
setup_environment() {
    local env_file="${1:-.env}"
    if [[ -f "$env_file" ]]; then
        source "$env_file"
    fi
}
```

### エラーハンドリング
```bash
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# 使用例
[[ -f "$config_file" ]] || die "Config file not found: $config_file"
```

### 配置場所
- `scripts/` ディレクトリに配置
- 実行権限を付与: `chmod +x scripts/*.sh`

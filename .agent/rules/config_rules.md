# Configuration Rules

アプリケーションの設定管理は、以下のルールに従ってください。

## 1. Environment Variables

- **Source of Truth**: 設定値はすべて環境変数から読み込むこと（Twelve-Factor App）。
- **Library**: `github.com/caarlos0/env`（または互換性のあるライブラリ）を使用し、構造体タグでマッピングすること。
- **Dotenv**: 開発環境の利便性のため、`.env` ファイルの読み込み（`github.com/joho/godotenv`）をサポートすること。

## 2. Config Structure

- **Definition**: `internal/config/config.go` に設定構造体を定義すること。
- **Grouping**: 設定項目は機能ごと（例: `ServerConfig`, `DatabaseConfig`, `QueueConfig`）に構造体を分けて整理すること。
- **Tags**: `env` タグで環境変数名を明示し、`envDefault` タグで安全なデフォルト値を提供すること。

## 3. Usage

- **Injection**: 設定構造体（`*config.Config`）はDIコンテナを通じて必要なコンポーネントに注入すること。グローバル変数は避けること。
- **Validation**: 読み込み時に必須項目のチェックや値の検証を行うこと。

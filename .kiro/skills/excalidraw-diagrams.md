---
name: "excalidraw-diagrams"
description: "Excalidraw MCP を使って手書き風ダイアグラムを作成するスキル。アーキテクチャ図、シーケンス図、フローチャート等。"
keywords: ["excalidraw", "diagram", "draw", "architecture diagram", "sequence diagram", "flowchart", "図", "ダイアグラム", "描画"]
---

# Excalidraw Diagrams Skill

Excalidraw MCP サーバーを使って、チャット内にインタラクティブな手書き風ダイアグラムを描画する。

## 使用可能なツール

- `mcp_excalidraw_read_me` — 要素フォーマットのリファレンスを取得（会話で最初の1回のみ呼ぶ）
- `mcp_excalidraw_create_view` — Excalidraw 要素の JSON 配列を渡してダイアグラムを描画
- `mcp_excalidraw_export_to_excalidraw` — 描画したダイアグラムを excalidraw.com にアップロードして共有 URL を取得
- `mcp_excalidraw_save_checkpoint` / `mcp_excalidraw_read_checkpoint` — ダイアグラムの状態を保存・復元

## ワークフロー

1. 会話で初めて Excalidraw を使う場合、`mcp_excalidraw_read_me` を1回呼んで要素フォーマットを確認する
2. `mcp_excalidraw_create_view` に JSON 配列を渡してダイアグラムを描画する
3. 必要に応じて `mcp_excalidraw_export_to_excalidraw` で共有 URL を生成する

## 描画のルール

- 最初の要素は必ず `cameraUpdate`（ビューポート設定）にする
- カメラサイズは 4:3 比率のみ: 400x300, 600x450, 800x600, 1200x900, 1600x1200
- 要素は描画順に配列に並べる（背景 → 図形 → ラベル → 矢印 → 次の図形）
- フォントサイズ最小値: 本文 16、タイトル 20、注釈 14（14未満は禁止）
- 図形の最小サイズ: ラベル付き矩形は 120x60
- 要素間は最低 20-30px の間隔を空ける
- `cameraUpdate` を積極的に使ってセクションごとにフォーカスを移動する
- 絵文字はテキストに使わない（Excalidraw フォントでレンダリングされない）

## カラーパレット

### 図形の背景色（パステル）
| 色 | Hex | 用途 |
|----|-----|------|
| Light Blue | `#a5d8ff` | 入力、ソース、プライマリ |
| Light Green | `#b2f2bb` | 成功、出力、完了 |
| Light Orange | `#ffd8a8` | 警告、保留、外部 |
| Light Purple | `#d0bfff` | 処理、ミドルウェア |
| Light Red | `#ffc9c9` | エラー、クリティカル |
| Light Yellow | `#fff3bf` | ノート、判断 |
| Light Teal | `#c3fae8` | ストレージ、データ |

### ゾーン背景（opacity: 30 で使用）
| 色 | Hex | 用途 |
|----|-----|------|
| Blue zone | `#dbe4ff` | UI / フロントエンド層 |
| Purple zone | `#e5dbff` | ロジック / エージェント層 |
| Green zone | `#d3f9d8` | データ / ツール層 |

## 典型的な使用例

- 「アーキテクチャ図を描いて」→ システム構成図
- 「シーケンス図を描いて」→ UML シーケンス図
- 「フローチャートを描いて」→ 処理フロー図
- 「ER図を描いて」→ エンティティ関連図
- 「ネットワーク構成図を描いて」→ インフラ構成図

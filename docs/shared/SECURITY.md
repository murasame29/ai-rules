# SECURITY.md

セキュリティに関するガイドラインを定義します。

---

## 📚 目次

1. [認証・認可](#1-認証認可)
2. [シークレット管理](#2-シークレット管理)
3. [入力バリデーション](#3-入力バリデーション)
4. [通信セキュリティ](#4-通信セキュリティ)
5. [ログとモニタリング](#5-ログとモニタリング)

---

## 1. 認証・認可

### 認証 (Authentication)
- JWT (JSON Web Token) を推奨
- トークンの有効期限を適切に設定
- リフレッシュトークンは安全に保管

```go
type Claims struct {
    UserID string `json:"user_id"`
    Role   string `json:"role"`
    jwt.RegisteredClaims
}
```

### 認可 (Authorization)
- RBAC (Role-Based Access Control) を採用
- ミドルウェアで権限チェック
- 最小権限の原則を適用

```go
func RequireRole(roles ...string) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // 権限チェック
        })
    }
}
```

---

## 2. シークレット管理

### 禁止事項
- ❌ ソースコードにシークレットをハードコード
- ❌ シークレットをログに出力
- ❌ シークレットをGitにコミット

### 推奨事項
- ✅ 環境変数で管理
- ✅ シークレットマネージャーを使用 (AWS Secrets Manager, HashiCorp Vault)
- ✅ `.env` ファイルは `.gitignore` に追加

```bash
# .gitignore
.env
.env.local
*.pem
*.key
```

### ログマスキング
```go
// センシティブな情報はマスク
logger.Info("user login",
    slog.String("email", maskEmail(email)),
    slog.String("password", "***"),
)
```

---

## 3. 入力バリデーション

### 原則
- 全ての入力を信頼しない
- サーバーサイドで必ずバリデーション
- クライアントサイドのバリデーションは補助的

### SQLインジェクション対策
```go
// Good - プレースホルダを使用
query := "SELECT * FROM users WHERE id = $1"
row := db.QueryRow(ctx, query, userID)

// Bad - 文字列結合
query := "SELECT * FROM users WHERE id = '" + userID + "'"
```

### XSS対策
- HTMLエスケープを適用
- Content-Type を正しく設定
- CSP (Content Security Policy) を設定

---

## 4. 通信セキュリティ

### HTTPS
- 本番環境では必ずHTTPSを使用
- TLS 1.2以上を要求

### CORS
```go
func CORSMiddleware(allowedOrigins []string) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            origin := r.Header.Get("Origin")
            if isAllowed(origin, allowedOrigins) {
                w.Header().Set("Access-Control-Allow-Origin", origin)
            }
            // ...
        })
    }
}
```

### セキュリティヘッダー
```go
w.Header().Set("X-Content-Type-Options", "nosniff")
w.Header().Set("X-Frame-Options", "DENY")
w.Header().Set("X-XSS-Protection", "1; mode=block")
w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
```

---

## 5. ログとモニタリング

### セキュリティログ
記録すべきイベント:
- 認証の成功/失敗
- 認可の失敗
- 入力バリデーションエラー
- 異常なアクセスパターン

```go
logger.WarnContext(ctx, "authentication failed",
    slog.String("ip", clientIP),
    slog.String("user_agent", userAgent),
    slog.Int("attempt_count", attemptCount),
)
```

### アラート
- 連続した認証失敗
- 異常なリクエストレート
- 未知のエラーパターン

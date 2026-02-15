# Backend 仕様書

## 1. 概要

NestJS + TypeScript で構築された RESTful API サーバー。Auth0 による JWT 認証を備え、Docker コンテナとしてデプロイされる。

## 2. 技術スタック

| 項目 | 技術 / バージョン |
|------|------------------|
| フレームワーク | NestJS 11.0.1 |
| 言語 | TypeScript 5.7 |
| 実行環境 | Node.js 23 (Alpine) |
| HTTP アダプタ | Express (`@nestjs/platform-express` 11.1.6) |
| 認証 | Passport JWT + Auth0 JWKS |
| 設定管理 | `@nestjs/config` 4.0.2 |
| テスト | Jest 29.7.0 + Supertest 7.0.0 |
| パッケージマネージャ | Yarn |
| コンテナ | Docker (マルチステージビルド) |

## 3. ディレクトリ構成

```
backend/sandbox-backend/
├── src/
│   ├── main.ts                        # アプリケーション起動
│   ├── app.module.ts                  # ルートモジュール
│   ├── app.controller.ts             # API エンドポイント定義
│   ├── app.service.ts                # ビジネスロジック
│   ├── app.controller.spec.ts        # ユニットテスト
│   ├── auth/
│   │   ├── auth.module.ts            # 認証モジュール
│   │   ├── strategies/
│   │   │   └── jwt.strategy.ts       # Passport JWT ストラテジー
│   │   └── guards/
│   │       └── jwt-auth.guard.ts     # JWT 認証ガード
│   └── health/
│       ├── health.module.ts          # ヘルスチェックモジュール
│       ├── health.controller.ts      # ヘルスチェックエンドポイント
│       └── health.controller.spec.ts # ユニットテスト
├── test/
│   ├── jest-e2e.json                 # E2E テスト設定
│   └── app.e2e-spec.ts              # E2E テスト
├── Dockerfile                         # マルチステージ Docker ビルド
├── package.json
├── tsconfig.json
├── tsconfig.build.json
└── nest-cli.json
```

## 4. 環境変数

| 変数名 | 必須 | デフォルト | 説明 |
|--------|------|-----------|------|
| `PORT` | - | `3000` | サーバー待受ポート |
| `LOG_LEVEL` | - | `error` | ログレベル（`debug`, `log`, `warn`, `error`） |
| `AUTH0_DOMAIN` | Yes | - | Auth0 テナントドメイン（例: `xxx.auth0.com`） |
| `AUTH0_AUDIENCE` | Yes | - | Auth0 API の Audience（CDN ドメイン） |
| `CORS_ORIGIN` | - | - | 許可するオリジン（カンマ区切り） |
| `CORS_METHODS` | - | - | 許可する HTTP メソッド（カンマ区切り） |
| `NODE_ENV` | - | - | 実行環境（Docker 内では `production`） |

## 5. モジュール構成

### 5.1 AppModule（`app.module.ts`）

ルートモジュール。以下のモジュールをインポート:

| モジュール | 説明 |
|-----------|------|
| `HealthModule` | ヘルスチェック機能 |
| `ConfigModule.forRoot()` | `.env` ファイルからの環境変数読み込み |
| `AuthModule` | JWT 認証機能 |

### 5.2 AuthModule（`auth/auth.module.ts`）

認証機能を提供するモジュール。

| インポート | 説明 |
|-----------|------|
| `PassportModule` | Passport.js 統合 |
| `ConfigModule` | 環境変数参照用 |

| プロバイダ | 説明 |
|-----------|------|
| `JwtStrategy` | JWT トークン検証ストラテジー |

### 5.3 HealthModule（`health/health.module.ts`）

ヘルスチェック専用モジュール。`HealthController` を登録。

## 6. API エンドポイント仕様

### 6.1 ヘルスチェック

| 項目 | 値 |
|------|-----|
| メソッド | `GET` |
| パス | `/health` |
| 認証 | 不要 |
| レスポンス | `{ "status": "ok" }` |
| 用途 | ロードバランサーのヘルスチェック |

### 6.2 ルートエンドポイント

| 項目 | 値 |
|------|-----|
| メソッド | `GET` |
| パス | `/` |
| 認証 | 不要 |
| レスポンス | `Hello World!`（文字列） |
| 用途 | 動作確認 |

### 6.3 ゲスト接続テスト

| 項目 | 値 |
|------|-----|
| メソッド | `GET` |
| パス | `/api/guest/connect-test` |
| 認証 | 不要 |
| レスポンス | `{ "message": "GET api/guest/connect-test ok", "time": "<ISO 8601>" }` |
| 用途 | 認証なしでの API 疎通確認 |

### 6.4 認証済みリソース取得

| 項目 | 値 |
|------|-----|
| メソッド | `GET` |
| パス | `/api/protected` |
| 認証 | **必要**（JWT Bearer トークン） |
| ガード | `JwtAuthGuard` |
| レスポンス（成功） | `{ "message": "GET api/protected", "time": "<ISO 8601>" }` |
| レスポンス（未認証） | `401 Unauthorized` |
| 用途 | 認証付き API の動作確認 |

## 7. 認証仕様

### 7.1 JWT Strategy（`auth/strategies/jwt.strategy.ts`）

Auth0 が発行した JWT トークンを検証する Passport ストラテジー。

| 設定項目 | 値 |
|---------|-----|
| トークン取得方法 | `Authorization: Bearer <token>` ヘッダー |
| 公開鍵取得 | JWKS エンドポイント（`https://{AUTH0_DOMAIN}/.well-known/jwks.json`） |
| JWKS キャッシュ | 有効 |
| JWKS レートリミット | 有効 |
| アルゴリズム | RS256（非対称鍵） |
| Audience 検証 | `AUTH0_AUDIENCE` 環境変数と一致 |
| Issuer 検証 | `https://{AUTH0_DOMAIN}/` と一致 |

#### トークン検証後のペイロード

`validate()` メソッドで JWT ペイロード全体を `{ payload }` として `req.user` にセット。

### 7.2 JWT Auth Guard（`auth/guards/jwt-auth.guard.ts`）

`AuthGuard('jwt')` を拡張したカスタムガード。

- **OPTIONS メソッド**: CORS プリフライトリクエストを無条件で許可（`return true`）
- **その他のメソッド**: 親クラスの `canActivate()` で JWT 検証を実行

## 8. CORS 設定

`main.ts` で以下の条件に基づき CORS を設定:

- `CORS_ORIGIN` と `CORS_METHODS` の**両方**が環境変数に設定されている場合のみ有効化
- `origin`: カンマ区切りの文字列を配列に変換
- `methods`: カンマ区切りの文字列を配列に変換
- `credentials`: `true`（Cookie 送信許可）

## 9. ログ設定

- `LOG_LEVEL` 環境変数でログレベルを制御（デフォルト: `error`）
- `Logger.overrideLogger()` で NestJS のロガーを上書き

## 10. Docker 仕様

### 10.1 ビルド構成（マルチステージ）

#### ステージ 1: builder

| 項目 | 値 |
|------|-----|
| ベースイメージ | `node:23-alpine` |
| 作業ディレクトリ | `/usr/src/app` |
| 処理 | `yarn install` → ソースコピー → `yarn build` |

#### ステージ 2: runtime

| 項目 | 値 |
|------|-----|
| ベースイメージ | `node:23-alpine` |
| 実行ユーザー | `appuser`（非特権ユーザー） |
| コピー内容 | `package.json`, `yarn.lock`, `dist/` |
| 依存関係 | `yarn install --production`（本番依存のみ） |
| ポート | `3000` |
| 起動コマンド | `node dist/main` |

### 10.2 セキュリティ

- 非特権ユーザー（`appuser:appgroup`）でコンテナを実行
- `NODE_ENV=production` を設定
- 本番依存のみインストール（`--production`）

## 11. 開発コマンド

| コマンド | 説明 |
|---------|------|
| `yarn start` | NestJS サーバー起動 |
| `yarn start:dev` | 開発モード起動（ファイル監視 + 自動リロード） |
| `yarn start:debug` | デバッグモード起動 |
| `yarn start:prod` | 本番モード起動（`node dist/main`） |
| `yarn build` | NestJS ビルド |
| `yarn test` | Jest ユニットテスト実行 |
| `yarn test:watch` | テストのファイル監視モード |
| `yarn test:cov` | カバレッジ付きテスト |
| `yarn test:e2e` | E2E テスト実行 |
| `yarn lint` | ESLint 実行（自動修正付き） |
| `yarn format` | Prettier によるフォーマット |

## 12. デプロイ

### 12.1 AWS（CodePipeline + ECS Fargate）

- **トリガー**: `main` ブランチへの `backend/sandbox-backend/**` 配下の Push
- **ビルド**: CodeBuild で Docker イメージをビルド、ECR へ Push
- **デプロイ**: `imagedefinitions.json` により ECS サービスを更新

### 12.2 Azure（GitHub Actions + App Service）

- **トリガー**: 手動実行（`workflow_dispatch`）
- **認証**: OIDC（Azure サービスプリンシパル）
- **ビルド**: Docker イメージをビルド、ACR へ Push（コミット SHA + latest タグ）
- **デプロイ**: App Service のコンテナ設定を更新 → 再起動

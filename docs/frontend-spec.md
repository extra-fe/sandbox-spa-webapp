# Frontend 仕様書

## 1. 概要

React + TypeScript で構築されたシングルページアプリケーション（SPA）。Auth0 による認証機能を備え、Backend API との通信を行う。Vite をビルドツールとして使用。

## 2. 技術スタック

| 項目 | 技術 / バージョン |
|------|------------------|
| フレームワーク | React 19.1.1 |
| 言語 | TypeScript 5.8 |
| ビルドツール | Vite 7.1.2 |
| 認証 | Auth0 (`@auth0/auth0-react` 2.4.0) |
| HTTP クライアント | Axios 1.11.0 |
| パッケージマネージャ | Yarn |
| Lint | ESLint 9.33.0 |

## 3. ディレクトリ構成

```
frontend/sandbox-frontend/
├── public/                     # 静的アセット
├── src/
│   ├── main.tsx               # エントリポイント（Auth0Provider でラップ）
│   ├── App.tsx                # メインコンポーネント
│   ├── App.css                # App スタイル
│   ├── index.css              # グローバルスタイル
│   ├── vite-env.d.ts          # Vite 型定義
│   ├── hooks/
│   │   └── useApiCaller.ts    # API 通信用カスタムフック
│   └── assets/                # 画像等のアセット
├── index.html                 # HTML テンプレート
├── package.json
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── vite.config.ts
└── eslint.config.js
```

## 4. 環境変数

| 変数名 | 説明 | 例 |
|--------|------|-----|
| `VITE_AUTH0_DOMAIN` | Auth0 テナントのドメイン | `xxx.auth0.com` |
| `VITE_AUTH0_CLIENT_ID` | Auth0 アプリケーションの Client ID | - |
| `VITE_AUTH0_AUDIENCE` | Auth0 API の Audience（CDN ドメイン） | `https://xxx.cloudfront.net` |
| `VITE_API_BASE_URL` | Backend API のベース URL（CDN ドメイン） | `https://xxx.cloudfront.net` |

## 5. 認証フロー

### 5.1 Auth0Provider 設定（`main.tsx`）

- `Auth0Provider` でアプリケーション全体をラップ
- `domain` / `clientId` は環境変数から取得
- `authorizationParams.redirect_uri` は `window.location.origin`（現在のドメイン）
- `authorizationParams.audience` は環境変数から取得

### 5.2 認証状態の管理

`useAuth0` フックにより以下の状態・メソッドを利用:

| プロパティ / メソッド | 用途 |
|----------------------|------|
| `user` | ログイン中のユーザー情報 |
| `isAuthenticated` | 認証状態（`boolean`） |
| `isLoading` | 認証処理中フラグ |
| `loginWithRedirect()` | Auth0 ログイン画面へリダイレクト |
| `logout()` | ログアウト処理 |

## 6. コンポーネント仕様

### 6.1 App コンポーネント（`App.tsx`）

メインコンポーネント。以下の UI 要素を持つ:

| UI 要素 | 説明 |
|---------|------|
| Login / Logout ボタン | `isAuthenticated` に応じてテキストと動作を切り替え |
| ユーザー名表示 | ローディング中は `LoadingNow`、未認証時は `unauthorized`、認証後は `user.name` を表示 |
| Call Guest API ボタン | 認証不要の Guest API を呼び出す |
| Call Protected API ボタン | JWT 認証が必要な Protected API を呼び出す |
| API レスポンス表示 | `apiResponse` が存在する場合、JSON を `<pre>` タグで整形表示 |

## 7. カスタムフック仕様

### 7.1 `useApiCaller`（`hooks/useApiCaller.ts`）

Backend API 呼び出しを抽象化するカスタムフック。

#### インターフェース

```typescript
const { callApi } = useApiCaller();

callApi<T>(
  path: string,              // API パス（例: '/api/protected'）
  requiresAuth: boolean = true, // 認証要否（デフォルト: true）
  method: string = 'GET',    // HTTP メソッド（デフォルト: GET）
  body?: unknown             // リクエストボディ（任意）
): Promise<T>
```

#### 動作仕様

1. `VITE_API_BASE_URL` + `path` で完全な URL を構築
2. `Content-Type: application/json` ヘッダーを設定
3. `requiresAuth === true` かつ `isAuthenticated === true` の場合:
   - `getAccessTokenSilently()` で Auth0 アクセストークンを取得
   - `Authorization: Bearer <token>` ヘッダーを付与
4. `withCredentials: true` でリクエスト送信（Cookie 送信対応）
5. エラー時は HTTP ステータスコードを含むエラーメッセージを throw

## 8. ビルド・開発コマンド

| コマンド | 説明 |
|---------|------|
| `yarn dev` | 開発サーバー起動（Vite） |
| `yarn build` | TypeScript コンパイル + Vite ビルド |
| `yarn lint` | ESLint 実行 |
| `yarn preview` | ビルド結果のプレビューサーバー起動 |

## 9. ビルド設定

### 9.1 Vite（`vite.config.ts`）

- `@vitejs/plugin-react` プラグインを使用
- その他はデフォルト設定

### 9.2 TypeScript

- プロジェクト参照（Project References）を使用
  - `tsconfig.app.json`: アプリケーション用
  - `tsconfig.node.json`: Node.js 用（Vite 設定等）

## 10. デプロイ

### 10.1 AWS（CodePipeline）

- **トリガー**: `main` ブランチへの `frontend/sandbox-frontend/**` 配下の Push
- **ビルド**: CodeBuild で Node.js 23 + Yarn を使用
  - `.env` ファイルを動的生成（Auth0 認証情報、CDN ドメイン）
  - `yarn install` → `yarn build`
- **デプロイ**: ビルド成果物を S3 バケットへアップロード + CloudFront キャッシュ無効化

### 10.2 Azure（GitHub Actions）

- **トリガー**: 手動実行（`workflow_dispatch`）
- **認証**: OIDC（Azure サービスプリンシパル）
- **シークレット取得**: Azure Key Vault から環境変数を取得
- **ビルド**: Node.js 23 + Yarn
- **デプロイ**: Azure Blob Storage (`$web` コンテナ) へアップロード + Front Door キャッシュパージ

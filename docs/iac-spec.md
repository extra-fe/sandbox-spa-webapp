# IaC（Infrastructure as Code）仕様書

## 1. 概要

Terraform を使用して AWS および Azure の両クラウドプラットフォームにインフラストラクチャを構築する。フロントエンドは静的ファイルホスティング + CDN、バックエンドはコンテナベースのアプリケーション基盤を提供する。

| 項目 | 値 |
|------|-----|
| IaC ツール | Terraform 1.13.1 |
| 対応クラウド | AWS / Azure |
| 認証プロバイダ | Auth0（Terraform Auth0 Provider >= 1.0.0） |

---

## 2. AWS 構成

### 2.1 プロバイダ設定（`provider.tf`）

| プロバイダ | 設定 |
|-----------|------|
| AWS | リージョン: `ap-northeast-1`（東京） |
| Auth0 | `auth0_domain`, `auth0_client_id`, `auth0_client_secret` を変数から取得 |

### 2.2 アーキテクチャ概要

```
ユーザー
  │
  ▼
CloudFront（CDN）
  ├── /* ──────────► S3 バケット（フロントエンド静的ファイル）
  │                   └── OAC（Origin Access Control）で保護
  └── /api/* ──────► ALB（内部ロードバランサー）
                       └── VPC Origin 経由
                       └── ECS Fargate（バックエンドコンテナ）
```

### 2.3 ネットワーク構成（`vpc.tf`）

#### VPC

| 項目 | 値 |
|------|-----|
| CIDR | `172.16.0.0/16` |
| DNS ホスト名 | 有効 |
| DNS サポート | 有効 |

#### サブネット

| サブネット | AZ | CIDR | 用途 |
|-----------|-----|------|------|
| public-1a | ap-northeast-1a | `172.16.1.0/24` | NAT Gateway 配置 |
| private-1a | ap-northeast-1a | `172.16.2.0/24` | ALB / ECS 配置 |
| private-1c | ap-northeast-1c | `172.16.3.0/24` | ALB / ECS 配置 |

#### ルーティング

| ルートテーブル | 対象サブネット | デフォルトルート |
|--------------|--------------|----------------|
| public | public-1a | Internet Gateway |
| private（メイン） | private-1a, private-1c | NAT Gateway |

#### NAT Gateway

- パブリックサブネット（1a）に配置
- Elastic IP を関連付け
- プライベートサブネットからのインターネットアクセスを提供

### 2.4 セキュリティグループ（`security-group.tf`）

#### ALB セキュリティグループ

| 方向 | プロトコル | ポート | ソース | 説明 |
|------|----------|--------|--------|------|
| Ingress | ALL | 80 | CloudFront VPC Origin SG | CloudFront からの HTTP 通信 |
| Egress | ALL | 全ポート | `0.0.0.0/0` | 全アウトバウンド |

#### ECS サービスセキュリティグループ

| 方向 | プロトコル | ポート | ソース | 説明 |
|------|----------|--------|--------|------|
| Ingress | TCP | 3000 | ALB SG | ALB ターゲットグループからのトラフィック |
| Egress | ALL | 全ポート | `0.0.0.0/0` | 全アウトバウンド |

### 2.5 フロントエンドホスティング（`s3.tf`）

#### S3 バケット

| 項目 | 値 |
|------|-----|
| バケット名 | `{app-name}-{environment}-web-{random}` |
| パブリックアクセス | 全ブロック |
| バージョニング | 無効 |
| バケットポリシー | CloudFront OAC からの `s3:GetObject` のみ許可 |

### 2.6 CDN（`cloudfront.tf`）

#### CloudFront ディストリビューション

| 項目 | 値 |
|------|-----|
| HTTP バージョン | HTTP/2 |
| IPv6 | 有効 |
| 料金クラス | PriceClass_100 |
| SSL 証明書 | CloudFront デフォルト証明書 |

#### オリジン

| オリジン | タイプ | 設定 |
|---------|------|------|
| フロントエンド | S3 | OAC（Origin Access Control）で保護 |
| バックエンド | ALB | VPC Origin（HTTP Only） |

#### キャッシュビヘイビア

| パスパターン | オリジン | キャッシュポリシー | 備考 |
|-------------|---------|-----------------|------|
| `/*`（デフォルト） | S3 | Managed-CachingOptimized | GET/HEAD/OPTIONS, HTTPS リダイレクト |
| `/api/*` | ALB | Managed-CachingDisabled | 全 HTTP メソッド, AllViewer リクエストポリシー |

#### カスタムエラーレスポンス

| エラーコード | レスポンスコード | レスポンスパス | TTL | 用途 |
|------------|----------------|--------------|-----|------|
| 403 | 200 | `/index.html` | 10秒 | SPA ルーティング対応 |

### 2.7 コンテナ基盤（`ecr.tf`, `ecs.tf`）

#### ECR

| 項目 | 値 |
|------|-----|
| リポジトリ名 | `{environment}/{app-name}-backend` |
| タグ可変性 | MUTABLE |
| プッシュ時スキャン | 有効 |

#### ECS クラスター

| 項目 | 値 |
|------|-----|
| クラスター名 | `{app-name}-{environment}-cluster` |

#### ECS タスク定義

| 項目 | 値 |
|------|-----|
| ファミリー | `{app-name}-{environment}-def` |
| CPU | 256（0.25 vCPU） |
| メモリ | 512 MB |
| ネットワークモード | awsvpc |
| 互換性 | FARGATE |
| ログドライバ | awslogs（CloudWatch Logs） |
| ログ保持期間 | 7 日 |

#### コンテナ環境変数（タスク定義内）

| 変数名 | 値 |
|--------|-----|
| `PORT` | `3000` |
| `LOG_LEVEL` | `debug` |
| `AUTH0_DOMAIN` | `var.auth0_domain` |
| `AUTH0_AUDIENCE` | `https://{CloudFront ドメイン}` |
| `CORS_ORIGIN` | `https://{CloudFront ドメイン}` |
| `CORS_METHODS` | `GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS` |

#### ECS サービス

| 項目 | 値 |
|------|-----|
| サービス名 | `{app-name}-{environment}-service` |
| 起動タイプ | FARGATE |
| 希望タスク数 | 1 |
| 最大率 | 200% |
| 最小率 | 100% |
| パブリック IP | なし |
| サブネット | private-1a, private-1c |
| ロードバランサー | ALB ターゲットグループに登録 |

### 2.8 ロードバランサー（`alb.tf`）

#### ALB

| 項目 | 値 |
|------|-----|
| 名前 | `{app-name}-{environment}-alb` |
| タイプ | Application Load Balancer |
| スキーム | **内部**（Internet-facing ではない） |
| サブネット | private-1a, private-1c |
| HTTP/2 | 有効 |

#### ターゲットグループ

| 項目 | 値 |
|------|-----|
| プロトコル | HTTP |
| ポート | 3000 |
| ターゲットタイプ | ip |
| ヘルスチェックパス | `/health` |
| ヘルスチェック間隔 | 30 秒 |
| 正常しきい値 | 5 |
| 異常しきい値 | 2 |

#### リスナー

| リスナー | ポート | デフォルトアクション |
|---------|--------|-----------------|
| HTTP | 80 | 404 Fixed Response |

#### リスナールール

| 優先度 | 条件 | アクション |
|--------|------|----------|
| 1 | パスパターン: `/api/*` | ターゲットグループへフォワード |

### 2.9 CI/CD パイプライン

#### バックエンド（`code-pipeline-backend.tf`）

| ステージ | アクション | 説明 |
|---------|----------|------|
| Source | CodeStarSourceConnection | GitHub リポジトリからソース取得 |
| Build | CodeBuild | Docker イメージビルド → ECR へ Push |
| Deploy | ECS | `imagedefinitions.json` でサービス更新 |

**トリガー**: `main` ブランチの `backend/sandbox-backend/**` 配下へのプッシュ

**CodeBuild 仕様**:
1. ECR へログイン
2. `backend/sandbox-backend/` ディレクトリへ移動
3. Docker ビルド（latest + コミットハッシュタグ）
4. ECR へプッシュ
5. `imagedefinitions.json` を生成

#### フロントエンド（`code_pipeline_frontend.tf`）

| ステージ | アクション | 説明 |
|---------|----------|------|
| Source | CodeStarSourceConnection | GitHub リポジトリからソース取得 |
| Build | CodeBuild | フロントエンドビルド → S3 へアップロード |

**トリガー**: `main` ブランチの `frontend/sandbox-frontend/**` 配下へのプッシュ

**CodeBuild 仕様**:
1. Node.js 23 + Yarn インストール
2. `.env` ファイル動的生成（Auth0 認証情報、CloudFront ドメイン）
3. `yarn install` → `yarn build`
4. S3 へビルド成果物アップロード
5. CloudFront キャッシュ無効化

#### アーティファクトバケット

| 項目 | 値 |
|------|-----|
| バケット名 | `{app-name}-{environment}-artifact-{random}` |
| パブリックアクセス | 全ブロック |

### 2.10 IAM ロール構成

| ロール | 用途 |
|--------|------|
| `ecs-task-{app}-{env}-role` | ECS タスクロール |
| `ecs-task-execution-{app}-{env}-role` | ECS タスク実行ロール（ECR アクセス） |
| `{app}-{env}-backend-codepipeline` | バックエンド CodePipeline 実行ロール |
| `{app}-{env}-backend-codebuild-service-role` | バックエンド CodeBuild 実行ロール |
| `codepipeline-{app}-{env}-frontend-role` | フロントエンド CodePipeline 実行ロール |
| `codebuild-{app}-{env}-frontend-role` | フロントエンド CodeBuild 実行ロール |

### 2.11 変数一覧

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `auth0_domain` | （要指定） | Auth0 テナントドメイン |
| `auth0_client_id` | （要指定） | Auth0 Client ID |
| `auth0_client_secret` | （要指定） | Auth0 Client Secret |
| `github-repository-name` | （要指定） | GitHub リポジトリ名 |
| `codestar-connection-arn` | （要指定） | CodeStar 接続 ARN |
| `app-name` | `sandbox-aws` | アプリ名 |
| `environment` | `dev` | 環境名 |
| `frontend-src-root` | `frontend/sandbox-frontend` | フロントエンドソースパス |
| `backend-src-root` | `backend/sandbox-backend` | バックエンドソースパス |
| `target-branch` | `main` | パイプライントリガーブランチ |
| `vpc_cidr_block` | `172.16.0.0/16` | VPC CIDR |
| `subnet_public1a_cidr_block` | `172.16.1.0/24` | パブリックサブネット CIDR |
| `subnet_private1a_cidr_block` | `172.16.2.0/24` | プライベートサブネット 1a CIDR |
| `subnet_private1c_cidr_block` | `172.16.3.0/24` | プライベートサブネット 1c CIDR |
| `api-base-path` | `/api/*` | API ベースパス |
| `health-check-path` | `/health` | ヘルスチェックパス |
| `api-expose-port` | `3000` | コンテナ公開ポート |

---

## 3. Azure 構成

### 3.1 プロバイダ設定（`provider.tf`）

| プロバイダ | 設定 |
|-----------|------|
| AzureRM | `subscription_id` を変数から取得 |
| AzureAD | デフォルト設定 |
| Auth0 | `auth0_domain`, `auth0_client_id`, `auth0_client_secret` を変数から取得 |

### 3.2 アーキテクチャ概要

```
ユーザー
  │
  ▼
Azure Front Door（Standard）
  ├── /* ──────────► Storage Account（静的 Web サイトホスティング）
  └── /api/* ──────► App Service（Docker コンテナ）
                       └── ACR からイメージ Pull
                       └── IP 制限（Front Door のみ許可）
```

### 3.3 リソースグループ（`resource_group.tf`）

| 項目 | 値 |
|------|-----|
| 名前 | `rg-{app_name}-{environment}` |
| リージョン | `japaneast`（東日本） |

### 3.4 フロントエンドホスティング（`storage_account.tf`）

#### Storage Account

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}{environment}{random}web` |
| アカウント種類 | StorageV2 |
| SKU | Standard_LRS |
| アクセス層 | Hot |
| TLS バージョン | TLS 1.2 |
| パブリックネットワークアクセス | 有効（Front Door Standard 要件） |

#### 静的 Web サイト

| 項目 | 値 |
|------|-----|
| インデックスドキュメント | `index.html` |
| 404 ドキュメント | `index.html`（SPA ルーティング対応） |

#### データ保護

| 項目 | 値 |
|------|-----|
| BLOB バージョニング | 無効 |
| コンテナ削除保持 | 7 日 |
| BLOB 削除保持 | 7 日 |

### 3.5 CDN（`frontdoor_standard.tf`）

#### Front Door プロファイル

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}-{environment}-standard` |
| SKU | Standard_AzureFrontDoor |

#### エンドポイント

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}-{environment}-afd` |

#### オリジングループ・オリジン

| グループ | オリジン | ヘルスプローブ |
|---------|---------|--------------|
| Web グループ | Storage Account（`primary_web_host`） | HTTP HEAD `/` 100秒間隔 |
| API グループ | App Service（`default_hostname`） | HTTPS GET `/health` 100秒間隔 |

#### ルート

| ルート | パスパターン | オリジングループ | プロトコル |
|--------|------------|----------------|----------|
| Web ルート | `/*` | Web グループ | HTTPS |
| API ルート | `/api/*` | API グループ | HTTPS |

### 3.6 バックエンド基盤

#### Container Registry（`container_registry.tf`）

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}{environment}registry{random}` |
| SKU | Basic |
| 管理者アクセス | 無効 |

#### App Service Plan（`app_service.tf`）

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}-{environment}-linux-app-plan` |
| OS | Linux |
| SKU | B1 |

#### App Service（`app_service.tf`）

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}-{environment}-linux-app` |
| コンテナイメージ | `{app_name}-{environment}-backend:latest` |
| レジストリ | ACR（マネージド ID で認証） |
| Always On | 無効 |
| ID | SystemAssigned（マネージド ID） |

#### App Service 環境変数

| 変数名 | 値 |
|--------|-----|
| `WEBSITES_ENABLE_APP_SERVICE_STORAGE` | `false` |
| `PORT` | `3000` |
| `LOG_LEVEL` | `Debug` |
| `CORS_ORIGIN` | `https://{Front Door エンドポイント}` |
| `CORS_METHODS` | `GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS` |
| `AUTH0_DOMAIN` | `var.auth0_domain` |
| `AUTH0_AUDIENCE` | `https://{Front Door エンドポイント}` |

#### IP 制限

| 優先度 | ルール | アクション | 対象 |
|--------|--------|----------|------|
| 100 | AllowFrontDoor | Allow | `AzureFrontDoor.Backend` サービスタグ |
| 200 | DenyAllOthers | Deny | `0.0.0.0/0` |

#### ロール割り当て

| スコープ | ロール | プリンシパル |
|---------|--------|------------|
| ACR | AcrPull | App Service マネージド ID |

### 3.7 監視・ログ（`app_service.tf`）

#### Log Analytics Workspace

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}-{environment}-logws` |
| SKU | PerGB2018 |
| 保持期間 | 30 日 |

#### 診断設定

| カテゴリ | 種類 |
|---------|------|
| AppServiceConsoleLogs | ログ |
| AppServiceAppLogs | ログ |
| AppServiceHTTPLogs | ログ |
| AllMetrics | メトリック |

### 3.8 シークレット管理（`key_vault.tf`）

#### Key Vault

| 項目 | 値 |
|------|-----|
| 名前 | `{app_name}-{environment}-{random}-{target_branch}` |
| SKU | Standard |

#### 格納シークレット

| シークレット名 | 値 | 用途 |
|---------------|-----|------|
| `AUTH0-DOMAIN` | Auth0 ドメイン | フロントエンド / バックエンド |
| `AUTH0-CLIENT-ID` | Auth0 Client ID | フロントエンド |
| `AUTH0-AUDIENCE` | Front Door エンドポイント URL | フロントエンド / バックエンド |
| `API-BASE-URL` | Front Door エンドポイント URL | フロントエンド |
| `FRONTEND-WORKING-DIRECTORY` | フロントエンドソースパス | CI/CD |
| `FRONTEND-STORAGE-ACCOUNT-NAME` | Storage Account 名 | CI/CD |
| `RESOURCE-GROUP-NAME` | リソースグループ名 | CI/CD |
| `FRONTDOOR-PROFILE-NAME` | Front Door プロファイル名 | CI/CD |
| `FRONTDOOR-ENDPOINRT-NAME` | Front Door エンドポイント名 | CI/CD |
| `ACR-NAME` | ACR 名 | CI/CD |
| `IMAGE-NAME` | Docker イメージ名 | CI/CD |
| `BACKEND-WORKING-DIRECTORY` | バックエンドソースパス | CI/CD |
| `BACKEND-APP-SERVICE-NAME` | App Service 名 | CI/CD |
| `github-AZURE-CLIENT-ID` | サービスプリンシパル Client ID | GitHub Actions |
| `github-AZURE-SUBSCRIPTION-ID` | サブスクリプション ID | GitHub Actions |
| `github-AZURE-TENANT-ID` | テナント ID | GitHub Actions |

#### アクセスポリシー

| プリンシパル | Key | Secret | Certificate |
|------------|-----|--------|-------------|
| Terraform 実行ユーザー | Get, List, Delete, Purge | Get, List, Set, Delete, Purge | Get, List, Delete, Purge |
| GitHub Actions SP | Get, List | Get, List | - |

### 3.9 サービスプリンシパル（`service_principal.tf`）

#### アプリケーション登録

| 項目 | 値 |
|------|-----|
| 表示名 | `{app_name}-{environment}-github-actions-{target_branch}` |
| サインイン対象 | AzureADMyOrg |

#### フェデレーション ID 資格情報（OIDC）

| 項目 | 値 |
|------|-----|
| 発行者 | `https://token.actions.githubusercontent.com` |
| サブジェクト | `repo:{github_repository_name}:ref:refs/heads/{target_branch}` |
| 対象者 | `api://AzureADTokenExchange` |

#### ロール割り当て

| スコープ | ロール | 用途 |
|---------|--------|------|
| Storage Account | Storage Blob Data Contributor | フロントエンドデプロイ |
| Key Vault | Key Vault Reader | シークレット一覧取得 |
| Key Vault | Key Vault Secrets User | シークレット値取得 |
| Front Door Profile | Contributor | キャッシュパージ |
| ACR | AcrPush | Docker イメージプッシュ |
| ACR | AcrPull | Docker イメージプル |
| App Service | Contributor | コンテナ設定変更 |

### 3.10 CI/CD（GitHub Actions）

#### フロントエンドデプロイ（`deploy-frontend.yml`）

| 項目 | 値 |
|------|-----|
| トリガー | 手動実行（`workflow_dispatch`） |
| 実行環境 | `ubuntu-latest` |
| 認証方式 | OIDC（サービスプリンシパル） |

**処理フロー**:
1. チェックアウト
2. Azure Login（OIDC）
3. Key Vault からシークレット取得 → 環境変数セット
4. Node.js 23 セットアップ
5. `yarn install` → `yarn build`
6. Azure Blob Storage へアップロード（`$web` コンテナ）
7. Front Door キャッシュパージ

#### バックエンドデプロイ（`deploy-backend.yml`）

| 項目 | 値 |
|------|-----|
| トリガー | 手動実行（`workflow_dispatch`） |
| 実行環境 | `ubuntu-latest` |
| 認証方式 | OIDC（サービスプリンシパル） |

**処理フロー**:
1. チェックアウト
2. Azure Login（OIDC）
3. Key Vault からシークレット取得 → 環境変数セット
4. ACR ログイン
5. Docker イメージビルド（コミット SHA タグ + latest タグ）
6. ACR へプッシュ
7. App Service コンテナ設定更新
8. App Service 再起動

### 3.11 変数一覧

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `auth0_domain` | （要指定） | Auth0 テナントドメイン |
| `auth0_client_id` | （要指定） | Auth0 Client ID |
| `auth0_client_secret` | （要指定） | Auth0 Client Secret |
| `github_repository_name` | （要指定） | GitHub リポジトリ名 |
| `azure_subscription_id` | （要指定） | Azure サブスクリプション ID |
| `location` | `japaneast` | Azure リージョン |
| `app_name` | `sandbox` | アプリ名 |
| `environment` | `dev` | 環境名 |
| `frontend_src_root` | `frontend/sandbox-frontend` | フロントエンドソースパス |
| `backend-src-root` | `backend/sandbox-backend` | バックエンドソースパス |
| `target_branch` | `main` | 対象ブランチ |
| `api-base-path` | `/api/*` | API ベースパス |
| `health-check-path` | `/health` | ヘルスチェックパス |
| `api-expose-port` | `3000` | コンテナ公開ポート |

---

## 4. AWS / Azure 対応表

| 機能 | AWS | Azure |
|------|-----|-------|
| フロントエンドホスティング | S3 + CloudFront OAC | Storage Account 静的 Web サイト |
| CDN / ルーティング | CloudFront | Azure Front Door Standard |
| コンテナレジストリ | ECR | ACR (Basic) |
| コンテナ実行基盤 | ECS Fargate | App Service (Linux, B1) |
| ロードバランサー | ALB（内部） | Front Door → App Service 直接 |
| ネットワーク | VPC + サブネット + NAT GW | App Service IP 制限 |
| シークレット管理 | Terraform 変数 + CodeBuild 内生成 | Key Vault |
| CI/CD | CodePipeline + CodeBuild | GitHub Actions |
| CI/CD トリガー | Git Push（自動） | 手動実行（workflow_dispatch） |
| CI/CD 認証 | CodeStar Connection | OIDC（サービスプリンシパル） |
| ログ | CloudWatch Logs（7日保持） | Log Analytics Workspace（30日保持） |
| セキュリティ | VPC + SG | IP 制限（Front Door のみ許可） |

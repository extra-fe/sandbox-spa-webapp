# sandbox-spa-webapp

本リポジトリは、書籍「**実践React＆Nest.js Webアプリケーション開発 Auth0認証とAWS/Azureへのデプロイ完全ガイド**」（技術の泉シリーズ／インプレス NextPublishing）のサンプルコードです。

- 著者：吉倉 英貴
- 出版社：インプレス NextPublishing
- ISBN：978-4-295-60426-6（9784295604266）
- 発売日：2026年1月30日

## 書籍の概要

React・Nest.js・Auth0・Docker・Terraform を使った Web アプリケーション開発の実践ガイドです。ローカル環境の構築から AWS / Azure へのデプロイ、CI/CD パイプラインの構築まで、具体的な手順とコード例で解説しています。

## 対応する章とディレクトリ

| 章 | タイトル | 対応ディレクトリ |
|----|---------|----------------|
| 第1章 | ローカル環境（フロントエンド＋認証） | `frontend/` |
| 第2章 | AWSリソース構築（フロントエンド＋認証） | `iac/aws/` |
| 第3章 | Azureリソース構築（フロントエンド＋認証） | `iac/azure/` |
| 第4章 | ローカル環境（バックエンド（RESTful API）） | `backend/` |
| 第5章 | AWSリソース構築（RESTful API） | `iac/aws/` |
| 第6章 | Azureリソース構築（RESTful API） | `iac/azure/` |

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フロントエンド | React 19 / TypeScript / Vite |
| バックエンド | NestJS 11 / TypeScript / Node.js 23 |
| 認証 | Auth0 |
| コンテナ | Docker |
| IaC | Terraform 1.13.1 |
| クラウド (AWS) | CloudFront / S3 / ECS Fargate / ALB / ECR / CodePipeline |
| クラウド (Azure) | Front Door / Storage Account / App Service / ACR / Key Vault |
| CI/CD | AWS CodePipeline / GitHub Actions |

## リポジトリ構成

```
sandbox-spa-webapp/
├── frontend/                   # フロントエンド (React + TypeScript + Vite)
│   └── sandbox-frontend/
│       ├── src/
│       │   ├── main.tsx       # エントリポイント（Auth0Provider）
│       │   ├── App.tsx        # メインコンポーネント
│       │   └── hooks/
│       │       └── useApiCaller.ts  # API通信フック
│       ├── package.json
│       └── vite.config.ts
├── backend/                    # バックエンド (NestJS + TypeScript)
│   └── sandbox-backend/
│       ├── src/
│       │   ├── main.ts        # アプリケーション起動
│       │   ├── app.controller.ts   # APIエンドポイント
│       │   ├── auth/          # JWT認証モジュール
│       │   └── health/        # ヘルスチェックモジュール
│       ├── Dockerfile
│       └── package.json
├── iac/                        # Infrastructure as Code (Terraform)
│   ├── aws/                   # AWS構成
│   │   ├── provider.tf
│   │   ├── vpc.tf             # VPC / サブネット / NAT Gateway
│   │   ├── ecs.tf             # ECS Fargate クラスター
│   │   ├── alb.tf             # Application Load Balancer
│   │   ├── cloudfront.tf      # CloudFront ディストリビューション
│   │   ├── s3.tf              # S3 バケット（フロントエンド）
│   │   ├── ecr.tf             # ECR リポジトリ
│   │   ├── security-group.tf  # セキュリティグループ
│   │   ├── code-pipeline-backend.tf   # バックエンドCI/CD
│   │   ├── code_pipeline_frontend.tf  # フロントエンドCI/CD
│   │   └── variables.tf
│   └── azure/                 # Azure構成
│       ├── provider.tf
│       ├── resource_group.tf  # リソースグループ
│       ├── app_service.tf     # App Service（バックエンド）
│       ├── frontdoor_standard.tf  # Azure Front Door
│       ├── storage_account.tf # Storage Account（フロントエンド）
│       ├── container_registry.tf  # ACR
│       ├── key_vault.tf       # Key Vault（シークレット管理）
│       ├── service_principal.tf   # GitHub Actions用サービスプリンシパル
│       └── variables.tf
├── .github/
│   └── workflows/
│       ├── deploy-frontend.yml  # フロントエンドデプロイ (Azure)
│       └── deploy-backend.yml   # バックエンドデプロイ (Azure)
└── docs/                       # 仕様書
    ├── frontend-spec.md
    ├── backend-spec.md
    └── iac-spec.md
```

## 前提条件

- Node.js 23
- Yarn
- Docker
- Terraform 1.13.1
- Auth0 アカウント
- AWS アカウント（第2章・第5章）
- Azure アカウント（第3章・第6章）

## ローカル環境でのセットアップ

### フロントエンド

```bash
cd frontend/sandbox-frontend
yarn install
```

環境変数ファイル（`.env`）を作成:

```
VITE_AUTH0_DOMAIN=<Auth0のドメイン>
VITE_AUTH0_CLIENT_ID=<Auth0のClient ID>
VITE_AUTH0_AUDIENCE=<Auth0のAudience>
VITE_API_BASE_URL=http://localhost:3000
```

開発サーバーを起動:

```bash
yarn dev
```

### バックエンド

```bash
cd backend/sandbox-backend
yarn install
```

環境変数ファイル（`.env`）を作成:

```
PORT=3000
LOG_LEVEL=debug
AUTH0_DOMAIN=<Auth0のドメイン>
AUTH0_AUDIENCE=<Auth0のAudience>
CORS_ORIGIN=http://localhost:5173
CORS_METHODS=GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS
```

開発サーバーを起動:

```bash
yarn start:dev
```

## クラウドへのデプロイ

### AWS（Terraform + CodePipeline）

```bash
cd iac/aws
```

`terraform.tfvars` を作成し、必要な変数を設定した上で:

```bash
terraform init
terraform plan
terraform apply
```

詳細は書籍の第2章・第5章を参照してください。

### Azure（Terraform + GitHub Actions）

```bash
cd iac/azure
```

`terraform.tfvars` を作成し、必要な変数を設定した上で:

```bash
terraform init
terraform plan
terraform apply
```

GitHub Actions のワークフローは手動実行（`workflow_dispatch`）で起動します。詳細は書籍の第3章・第6章を参照してください。

## ライセンス

本リポジトリのコードは書籍の学習目的で提供されています。

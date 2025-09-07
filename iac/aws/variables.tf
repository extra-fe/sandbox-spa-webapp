## 環境変数で指定する。terraform.tfvars に記載
variable "auth0_domain" {
  description = "【環境変数で指定】認証用アプリケーションのDomain"
}
variable "auth0_client_id" {
  description = "【環境変数で指定】認証用アプリケーションのClient ID"
}
variable "auth0_client_secret" {
  description = "【環境変数で指定】認証用アプリケーションのClient Secrets"
}

variable "github-repository-name" {
  description = "【環境変数で指定】GitHubリポジトリ名"
}
variable "codestar-connection-arn" {
  description = "【環境変数で指定】接続のarn"
}

## AWSアカウントIDとリージョンの変数
data "aws_caller_identity" "self" {}
data "aws_region" "current" {}

## アプリ名と環境
variable "app-name" {
  default     = "sandbox-aws"
  description = "アプリ名"
}

variable "environment" {
  default     = "dev"
  description = "環境名"
}

variable "frontend-src-root" {
  default     = "frontend/sandbox-frontend"
  description = "frontendのルートパス"
}

variable "target-branch" {
  default     = "main"
  description = "このブランチにPushされたときにCodePipelineをトリガー"
}

## S3のバケット名をユニークにするための乱数
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}

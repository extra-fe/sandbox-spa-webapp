provider "aws" {
  region = "ap-northeast-1"
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}
terraform {
  required_version = "1.13.1"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = ">= 1.0.0"
    }
  }
}

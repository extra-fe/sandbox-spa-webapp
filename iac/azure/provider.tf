provider "azurerm" {
  subscription_id = var.azure_subscription_id
  features {}
}
provider "azuread" {}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

terraform {
  required_version = "= 1.13.1"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = ">= 1.0.0"
    }
  }
}

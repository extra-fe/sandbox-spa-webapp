resource "azurerm_key_vault" "vault" {
  name                = "${var.app_name}-${var.environment}-${random_string.random.result}-${var.target_branch}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_key_vault_secret" "auth0_domain" {
  name         = "AUTH0-DOMAIN"
  value        = var.auth0_domain
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "auth0_client_id" {
  name         = "AUTH0-CLIENT-ID"
  value        = auth0_client.app.client_id
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "frontend_working_directory" {
  name         = "FRONTEND-WORKING-DIRECTORY"
  value        = "/${var.frontend_src_root}"
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "frontend_deploy_storage_account_name" {
  name         = "FRONTEND-STORAGE-ACCOUNT-NAME"
  value        = azurerm_storage_account.web.name
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "frontend_deploy_resource_group_name" {
  name         = "RESOURCE-GROUP-NAME"
  value        = azurerm_resource_group.rg.name
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "frontend_deploy_frontdoor_profile_name" {
  name         = "FRONTDOOR-PROFILE-NAME"
  value        = azurerm_cdn_frontdoor_profile.cdn.name
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "frontend_deploy_frontdoor_endpoint_name" {
  name         = "FRONTDOOR-ENDPOINRT-NAME"
  value        = azurerm_cdn_frontdoor_endpoint.cdn.name
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "github_azure_client_id" {
  name         = "github-AZURE-CLIENT-ID"
  value        = azuread_application_registration.github_actions.client_id
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "github_azure_subscription_id" {
  name         = "github-AZURE-SUBSCRIPTION-ID"
  value        = data.azurerm_client_config.current.subscription_id
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "github_azure_tenant_id" {
  name         = "github-AZURE-TENANT-ID"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_access_policy" "terraform_user" {
  key_vault_id = azurerm_key_vault.vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get",
    "List",
    "Delete",
    "Purge",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Delete",
    "Purge",
  ]
  depends_on = [
    azurerm_key_vault.vault
  ]
}

resource "azurerm_key_vault_access_policy" "github_actions" {
  key_vault_id = azurerm_key_vault.vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.github_actions.object_id

  key_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]
  depends_on = [
    azurerm_key_vault.vault,
    azurerm_key_vault_access_policy.terraform_user
  ]
}


resource "azurerm_key_vault_secret" "auth0_audience" {
  name         = "AUTH0-AUDIENCE"
  value        = "https://${azurerm_cdn_frontdoor_endpoint.cdn.host_name}"
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "api_base_url" {
  name         = "API-BASE-URL"
  value        = "https://${azurerm_cdn_frontdoor_endpoint.cdn.host_name}"
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}


resource "azurerm_key_vault_secret" "acr_name" {
  name         = "ACR-NAME"
  value        = azurerm_container_registry.acr.name
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "image_name" {
  name         = "IMAGE-NAME"
  value        = "${var.app_name}-${var.environment}-backend"
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azurerm_key_vault_secret" "backend_working_directory" {
  name         = "BACKEND-WORKING-DIRECTORY"
  value        = "/${var.backend-src-root}"
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}


resource "azurerm_key_vault_secret" "backend_app_service_name" {
  name         = "BACKEND-APP-SERVICE-NAME"
  value        = azurerm_linux_web_app.app.name
  key_vault_id = azurerm_key_vault.vault.id
  depends_on = [
    azurerm_key_vault_access_policy.terraform_user
  ]
}

resource "azuread_application_registration" "github_actions" {
  display_name     = "${var.app_name}-${var.environment}-github-actions-${var.target_branch}"
  description      = "for GitHub Actions"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application_registration.github_actions.client_id
}

resource "azurerm_role_assignment" "github_actions_blob_contributor" {
  scope                = azurerm_storage_account.web.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_key_vault_reader" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azuread_service_principal.github_actions.object_id
}


resource "azurerm_role_assignment" "github_actions_key_vault_secrets_user" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.github_actions.object_id
}


resource "azurerm_role_assignment" "github_actions_cdn_profile_contributor" {
  scope                = azurerm_cdn_frontdoor_profile.cdn.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}


resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = azuread_application_registration.github_actions.id
  display_name   = "${var.app_name}-${var.environment}-github-actions-${var.target_branch}"
  description    = "Deployments for ${var.github_repository_name} ${var.target_branch}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository_name}:ref:refs/heads/${var.target_branch}"
}


resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_app_service_set_container" {
  scope                = azurerm_linux_web_app.app.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

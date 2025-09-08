resource "azurerm_container_registry" "acr" {
  name                = "${var.app_name}${var.environment}registry${random_string.random.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

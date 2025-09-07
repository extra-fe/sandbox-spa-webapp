resource "azurerm_storage_account" "web" {
  access_tier                     = "Hot"
  account_kind                    = "StorageV2"
  account_replication_type        = "LRS"
  account_tier                    = "Standard"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  location                        = azurerm_resource_group.rg.location
  min_tls_version                 = "TLS1_2"
  name                            = "${var.app_name}${var.environment}${random_string.random.result}web"
  public_network_access_enabled   = true # standardの時はtrue
  resource_group_name             = azurerm_resource_group.rg.name
  tags                            = {}

  blob_properties {
    versioning_enabled = false

    container_delete_retention_policy {
      days = 7
    }

    delete_retention_policy {
      days                     = 7
      permanent_delete_enabled = false
    }
  }
}

resource "azurerm_storage_account_static_website" "web" {
  storage_account_id = azurerm_storage_account.web.id
  error_404_document = "index.html"
  index_document     = "index.html"
}

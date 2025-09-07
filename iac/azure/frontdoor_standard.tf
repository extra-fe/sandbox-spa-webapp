resource "azurerm_cdn_frontdoor_profile" "cdn" {
  name                = "${var.app_name}-${var.environment}-standard"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "cdn" {
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.cdn.id
  enabled                  = true
  name                     = "${var.app_name}-${var.environment}-afd"
  tags                     = {}
}

resource "azurerm_cdn_frontdoor_origin_group" "web" {
  cdn_frontdoor_profile_id                                  = azurerm_cdn_frontdoor_profile.cdn.id
  name                                                      = "${var.app_name}-${var.environment}-web-group"
  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 0
  session_affinity_enabled                                  = false

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "web" {
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  certificate_name_check_enabled = true
  enabled                        = true
  host_name                      = azurerm_storage_account.web.primary_web_host
  http_port                      = 80
  https_port                     = 443
  name                           = "${var.app_name}-${var.environment}-web"
  origin_host_header             = azurerm_storage_account.web.primary_web_host
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_route" "web" {
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.cdn.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  cdn_frontdoor_origin_path     = "/"
  cdn_frontdoor_origin_ids = [
    azurerm_cdn_frontdoor_origin.web.id
  ]
  enabled                = true
  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = false
  name                   = "${var.app_name}-${var.environment}-route"
  patterns_to_match = [
    "/*",
  ]
  supported_protocols = [
    "Https",
  ]
}

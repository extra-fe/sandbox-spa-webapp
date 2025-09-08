resource "azurerm_service_plan" "plan" {
  name                = "${var.app_name}-${var.environment}-linux-app-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "${var.app_name}-${var.environment}-linux-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    container_registry_use_managed_identity = true
    application_stack {
      docker_image_name   = "${var.app_name}-${var.environment}-backend:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
    always_on = false
    ip_restriction {
      name        = "AllowFrontDoor"
      priority    = 100
      action      = "Allow"
      service_tag = "AzureFrontDoor.Backend"
    }

    ip_restriction {
      name       = "DenyAllOthers"
      priority   = 200
      action     = "Deny"
      ip_address = "0.0.0.0/0"
    }
  }
  identity {
    type = "SystemAssigned"
  }
  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    PORT                                = tostring(var.api-expose-port)
    LOG_LEVEL                           = "Debug"
    CORS_ORIGIN                         = "https://${azurerm_cdn_frontdoor_endpoint.cdn.host_name}"
    CORS_METHODS                        = "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS"
    AUTH0_DOMAIN                        = var.auth0_domain
    AUTH0_AUDIENCE                      = "https://${azurerm_cdn_frontdoor_endpoint.cdn.host_name}"
  }
  lifecycle {
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name
    ]
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
  depends_on = [
    azurerm_linux_web_app.app
  ]
}

resource "azurerm_log_analytics_workspace" "app_logs" {
  name                = "${var.app_name}-${var.environment}-logws"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "app_logs" {
  name                       = "${var.app_name}-${var.environment}-diagnostic"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app_logs.id

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_linux_web_app.app]
}

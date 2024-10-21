provider "azurerm" {
  features {}
  subscription_id = "30a83aff-7a8b-4ca3-aa48-ab93268b5a8b"
}

data "azurerm_resource_group" "imported_rg" {
  name = "internalContainerAppsTF"
}

data "azurerm_container_app_environment" "container_app_environment" {
  name = "test-env"
  resource_group_name = "internalContainerAppsTF"
}

data "azurerm_private_dns_zone" "private_dns_zone" {
  name                = "vnet.internal"
  resource_group_name = "internalContainerAppsTF"
}

data "azurerm_api_management" "apim" {
  name                = "test-002-apim"
  resource_group_name = "internalContainerAppsTF" 
}

data "azurerm_container_registry" "acr" {
  name                = "internalcontainerappsacr"
  resource_group_name = "internalContainerAppsTF"
}

resource "azurerm_user_assigned_identity" "containerapp" {
  location            = data.azurerm_resource_group.imported_rg.location
  name                = "containerappmi"
  resource_group_name = data.azurerm_resource_group.imported_rg.name
}
 
resource "azurerm_role_assignment" "containerapp" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "acrpull"
  principal_id         = azurerm_user_assigned_identity.containerapp.principal_id
  depends_on = [
    azurerm_user_assigned_identity.containerapp
  ]
}

resource "azurerm_container_app_environment_custom_domain" "env_custom_domain" {
  container_app_environment_id = data.azurerm_container_app_environment.container_app_environment.id
  certificate_blob_base64      = filebase64("../../bash/certs/vnet-internal-cert.pfx")
  certificate_password         = "s5p2rm1n"
  dns_suffix                   = "vnet.internal"
}

resource "azurerm_container_app" "minimal_Api" {
  name = "testing-app"
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  container_app_environment_id = data.azurerm_container_app_environment.container_app_environment.id
  ingress {
    external_enabled = true
    target_port = 8080
    traffic_weight {
      latest_revision = true
      percentage = 100
    }
  }
  template {
    container {
      name   = "testing-app"
      image  = "${data.azurerm_container_registry.acr.login_server}/testing-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
  revision_mode = "Single"

  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.principal_id
  }
}

resource "azurerm_private_dns_a_record" "a_record" {
  name                = "masfactura-api"
  zone_name           = data.azurerm_private_dns_zone.private_dns_zone.name
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  ttl                 = 60
  records             = [data.azurerm_container_app_environment.container_app_environment.static_ip_address]
}

resource "azurerm_api_management_api" "apim_api_registration" {
  name = "testing-app"
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  api_management_name = data.azurerm_api_management.apim.name
  display_name = "testing-app"
  revision            = "1"
  api_type = "http"
  path = "testing-app"
  protocols = ["https"]
  service_url = "http://testing-app.${azurerm_container_app_environment_custom_domain.env_custom_domain.dns_suffix}"
  import {
    content_format = "openapi-link"
    content_value = "http://testing-app.${azurerm_container_app_environment_custom_domain.env_custom_domain.dns_suffix}/swagger/v1/swagger.json"
  }
  subscription_required = false
}

resource "azurerm_api_management_api_policy" "apim_api_policy" {
  api_name = azurerm_api_management_api.apim_api_registration.name
  api_management_name = data.azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.imported_rg.name

  xml_content = <<XML
    <policies>
        <inbound>
            <base />
        </inbound>
        <backend>
            <forward-request timeout="10" follow-redirects="true" />
        </backend>
        <outbound>
            <base />
        </outbound>
        <on-error>
            <base />
        </on-error>
    </policies>
  XML
}
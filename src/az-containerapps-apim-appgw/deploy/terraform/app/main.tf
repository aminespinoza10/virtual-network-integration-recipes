provider "azurerm" {
  features {}
  subscription_id = "30a83aff-7a8b-4ca3-aa48-ab93268b5a8b"
}

data "azurerm_resource_group" "imported_rg" {
  name = "masFactura"
}

data "azurerm_container_app_environment" "container_app_environment" {
  name = "test-env"
  resource_group_name = "masFactura"
}

data "azurerm_private_dns_zone" "private_dns_zone" {
  name                = "vnet.internal"
  resource_group_name = "masFactura"
}

data "azurerm_api_management" "apim" {
  name                = "test-002-apim"
  resource_group_name = "masFactura" 
}

resource "azurerm_container_app_environment_custom_domain" "env_custom_domain" {
  container_app_environment_id = data.azurerm_container_app_environment.container_app_environment.id
  certificate_blob_base64      = filebase64("../../cert/vnet-internal-cert.pfx")
  certificate_password         = "masfactura"
  dns_suffix                   = "vnet.internal"
}

resource "azurerm_container_app" "minimal_Api" {
  name = "masfactura-api"
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
      name = "masfactura-api"
      image = "docker.io/aminespinoza/minimalapi:latest"
      cpu = 0.25
      memory = "0.5Gi"
    }
  }
  revision_mode = "Single"
}

resource "azurerm_private_dns_a_record" "a_record" {
  name                = "masfactura-api"
  zone_name           = data.azurerm_private_dns_zone.private_dns_zone.name
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  ttl                 = 60
  records             = [data.azurerm_container_app_environment.container_app_environment.static_ip_address]
}

resource "azurerm_api_management_api" "apim_api_registration" {
  name = "masfactura-api"
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  api_management_name = data.azurerm_api_management.apim.name
  display_name = "masfactura-api"
  revision            = "1"
  api_type = "http"
  path = "masfactura-api"
  protocols = ["https"]
  service_url = "http://masfactura-api.${azurerm_container_app_environment_custom_domain.env_custom_domain.dns_suffix}"
  import {
    content_format = "openapi-link"
    content_value = "http://masfactura-api.${azurerm_container_app_environment_custom_domain.env_custom_domain.dns_suffix}/swagger/v1/swagger.json"
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
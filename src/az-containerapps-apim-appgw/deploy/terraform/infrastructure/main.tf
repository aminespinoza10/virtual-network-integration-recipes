provider "azurerm" {
  features {}
  subscription_id = "30a83aff-7a8b-4ca3-aa48-ab93268b5a8b"
}

data "azurerm_resource_group" "imported_rg" {
  name = "masFactura"
}

data "azurerm_key_vault" "imported_kv" {
  name                = "test-001-kv"
  resource_group_name = "masFactura"
}

data "azurerm_key_vault_certificate" "vnet_internal_cert" {
  name         = "vnet-internal-cert"
  key_vault_id = data.azurerm_key_vault.imported_kv.id
}

data "azurerm_key_vault_certificate" "root_cert" {
  name         = "root-cert"
  key_vault_id = data.azurerm_key_vault.imported_kv.id
}

data "azurerm_key_vault_secret" "root_secret" {
  name         = "root-cert"
  key_vault_id = data.azurerm_key_vault.imported_kv.id
}

data "azurerm_key_vault_secret" "vnet_internal_secret" {
  name         = "vnet-internal-cert"
  key_vault_id = data.azurerm_key_vault.imported_kv.id
}

data "azurerm_log_analytics_workspace" "imported_law" {
  name                = "test-logs"
  resource_group_name = "masFactura"
}

data "azurerm_user_assigned_identity" "imported_uai" {
  name                = "test-mi"
  resource_group_name = "masFactura"
}

resource "azurerm_key_vault_access_policy" "kv-apim-access-policy" {
  key_vault_id = data.azurerm_key_vault.imported_kv.id
  tenant_id    = azurerm_api_management.api_management.identity[0].tenant_id
  object_id    = azurerm_api_management.api_management.identity[0].principal_id

  secret_permissions = [
    "Get",
  ]

  certificate_permissions = [
    "Get",
  ]
}

resource "azurerm_virtual_network" "vnet" {
  name                = "test-vnet"
  location            = data.azurerm_resource_group.imported_rg.location
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = data.azurerm_resource_group.imported_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet" "apim_subnet" {
  name                 = "apim-subnet"
  resource_group_name  = data.azurerm_resource_group.imported_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.EventHub"]
}

resource "azurerm_subnet_network_security_group_association" "apim_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.apim_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet" "api_subnet" {
  name                 = "api-subnet"
  resource_group_name  = data.azurerm_resource_group.imported_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "appsvc-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "cont_apps_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.api_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "test-nsg"
  location            = data.azurerm_resource_group.imported_rg.location
  resource_group_name = data.azurerm_resource_group.imported_rg.name

  dynamic "security_rule" {
    for_each = [
      {
        name                       = "appgw-to-apim"
        priority                   = 170
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.0.0.0/24"
        destination_address_prefix = "10.0.1.0/24"
      },
      {
        name                       = "container-to-appsvc"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.0.1.0/24"
        destination_address_prefix = "10.0.2.0/23"
        access                     = "Allow"
        priority                   = 190
        direction                  = "Inbound"
      },
      {
        name                       = "allow-internet-traffic"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.0.0/24"
        access                     = "Allow"
        priority                   = 200
        direction                  = "Inbound"
      },
      {
        name                       = "allowCommunicationBetweenInfrastructuresubnet"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.0.2.0/23"
        destination_address_prefix = "10.0.2.0/23"
        access                     = "Allow"
        priority                   = 210
        direction                  = "Inbound"
      },
      {
        name                       = "allowAzureLoadBalancerCommunication"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 220
        direction                  = "Inbound"
      },
      {
        name                       = "allowAKSSecureConnectionInternalNodeControlPlaneUDP"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "1194"
        source_address_prefix      = "AzureCloud.eastus2"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 230
        direction                  = "Inbound"
      },
      {
        name                       = "allowAKSSecureConnectionInternalNodeControlPlaneTCP"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9000"
        source_address_prefix      = "AzureCloud.eastus2"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 240
        direction                  = "Inbound"
      },
      {
        name                       = "appGwInfraCommunication"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "65200-65535"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 250
        direction                  = "Inbound"
      },
      {
        name                       = "allowOutboundCallstoAzureMonitor"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "AzureMonitor"
        access                     = "Allow"
        priority                   = 250
        direction                  = "Outbound"
      },
      {
        name                       = "allowAllOutboundOnPort443"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 260
        direction                  = "Outbound"
      },
      {
        name                       = "allowNTPServer"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "123"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 270
        direction                  = "Outbound"
      },
      {
        name                       = "allowContainerAppsControlPlaneTCP"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "5671"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 280
        direction                  = "Outbound"
      },
      {
        name                       = "allowContainerAppsControlPlaneTCP2"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "5672"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        access                     = "Allow"
        priority                   = 290
        direction                  = "Outbound"
      },
      {
        name                       = "allowCommsBetweenSubnet"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.0.2.0/23"
        destination_address_prefix = "10.0.2.0/23"
        access                     = "Allow"
        priority                   = 300
        direction                  = "Outbound"
      },
      {
        name                       = "deny-apim-from-others"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "10.0.1.0/24"
        access                     = "Allow"
        priority                   = 310
        direction                  = "Inbound"
      },
      {
        name                       = "deny-appsvc-from-others"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "10.0.2.0/23"
        access                     = "Deny"
        priority                   = 320
        direction                  = "Inbound"
      }
    ]

    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_container_app_environment" "container_app_environment" {
  name                       = "test-env"
  location                   = data.azurerm_resource_group.imported_rg.location
  resource_group_name        = data.azurerm_resource_group.imported_rg.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.imported_law.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  internal_load_balancer_enabled = true
  infrastructure_subnet_id       = azurerm_subnet.api_subnet.id
  zone_redundancy_enabled        = false
}

//esto va para la sección de App
resource "azurerm_container_app_environment_custom_domain" "env_custom_domain" {
  container_app_environment_id = azurerm_container_app_environment.container_app_environment.id
  certificate_blob_base64      = filebase64("../../cert/vnet-internal-cert.pfx")
  certificate_password         = "masfactura"
  dns_suffix                   = "vnet.internal"
}

resource "azurerm_api_management" "api_management" {
  name                       = "test-002-apim"
  location                   = data.azurerm_resource_group.imported_rg.location
  resource_group_name        = data.azurerm_resource_group.imported_rg.name
  publisher_name             = "masFactura"
  publisher_email            = "admin@masfactura.com"
  sku_name                   = "Developer_1"
  client_certificate_enabled = false
  virtual_network_type       = "Internal"

  identity {
    type         = "SystemAssigned"
  }

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_subnet.id
  }

  certificate {
    store_name          = "Root"
    encoded_certificate = data.azurerm_key_vault_certificate.root_cert.certificate_data_base64
  }
  hostname_configuration {
    proxy {
      host_name           = "apim.vnet.internal"
      key_vault_id = data.azurerm_key_vault_certificate.vnet_internal_cert.versionless_secret_id
      default_ssl_binding = true
    }
  }
}

resource "azurerm_private_dns_zone" "private_dns_zone" {
  name                = "vnet.internal"
  resource_group_name = data.azurerm_resource_group.imported_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network_link" {
  name                  = "test-vnet-vnet.internal-link"
  resource_group_name   = data.azurerm_resource_group.imported_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "a_record" {
  name                = "apim"
  zone_name           = azurerm_private_dns_zone.private_dns_zone.name
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  ttl                 = 60
  records             = [azurerm_api_management.api_management.private_ip_addresses[0]]
}

resource "azurerm_public_ip" "gateway_ip" {
  name                = "test-appgw-public-ip"
  resource_group_name = data.azurerm_resource_group.imported_rg.name
  location            = data.azurerm_resource_group.imported_rg.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_application_gateway" "network" {
    name                = "test-appgw"
    location            = data.azurerm_resource_group.imported_rg.location
    resource_group_name = data.azurerm_resource_group.imported_rg.name

    identity {
      type         = "UserAssigned"
      identity_ids = [data.azurerm_user_assigned_identity.imported_uai.id]
    }

    sku {
        name           = "WAF_v2"
        tier           = "WAF_v2"
        capacity       = 2
    }

    enable_http2 = true

    waf_configuration {
      enabled          = true
      firewall_mode    = "Detection"
      rule_set_type    = "OWASP"
      rule_set_version = "3.1"
      request_body_check = false
      disabled_rule_group {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules           = ["920320"]
      }
    }

    trusted_root_certificate {
      name                = "root_cert_internaldomain"
      key_vault_secret_id = data.azurerm_key_vault_secret.root_secret.id
    }

    probe {
      name                                      = "apimgw-probe"
      pick_host_name_from_backend_http_settings = true
      timeout                                   = 30
      interval                                  = 30
      unhealthy_threshold                       = 3
      path                                      = "/status-0123456789abcdef"
      protocol                                  = "Https"
      match {
        status_code = ["200", "399"]
      }
    }

    gateway_ip_configuration {
      name      = "appgw-ip-config"
      subnet_id = azurerm_subnet.appgw_subnet.id
    }

    frontend_ip_configuration {
      name                 = "appgw-public-frontend-ip"
      public_ip_address_id = azurerm_public_ip.gateway_ip.id
    }

    frontend_port {
      name         = "port_80"
      port         = 80
    }

    backend_address_pool {
      name = "backend-apigw" 
      fqdns = ["apim.vnet.internal"]
    }

    backend_http_settings {
      name                  = "apim_gw_httpssettings"
      cookie_based_affinity = "Disabled"
      port                  = 443
      protocol              = "Https"
      request_timeout        = 120
      connection_draining {
        enabled           = true
        drain_timeout_sec = 20
      }
      pick_host_name_from_backend_address = true
      trusted_root_certificate_names = [ "root_cert_internaldomain" ]
      probe_name = "apimgw-probe"
    }

    http_listener {
      name                           = "apigw-http-listener"
      frontend_ip_configuration_name = "appgw-public-frontend-ip"
      frontend_port_name             = "port_80"
      protocol                       = "Http"
    }

    ssl_policy {
      policy_type = "Predefined"
      policy_name = "AppGwSslPolicy20170401S"
    }

    request_routing_rule {
      name                       = "routing-apigw"
      rule_type                  = "Basic"
      http_listener_name         = "apigw-http-listener"
      backend_address_pool_name  = "backend-apigw"
      backend_http_settings_name = "apim_gw_httpssettings"
      priority                   = 1
      rewrite_rule_set_name    = "default-rewrite-rules"
    }

    rewrite_rule_set {
      name = "default-rewrite-rules"
      rewrite_rule {
        rule_sequence = 1000
        name          = "HSTS header injection"
        response_header_configuration {
          header_name  = "Strict-Transport-Security"
          header_value = "max-age=31536000; includeSubDomains"
        }
      }
    }
}


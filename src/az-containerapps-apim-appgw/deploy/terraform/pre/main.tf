provider "azurerm" {
  features {}
  subscription_id = "30a83aff-7a8b-4ca3-aa48-ab93268b5a8b"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "internalContainerAppsTF"
  location = "East Us 2"
}

resource "azurerm_container_registry" "acr" {
  name                = "internalcontainerappsacr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
}

resource "azurerm_user_assigned_identity" "managed_identity" {
  location            = azurerm_resource_group.rg.location
  name                = "test-mi"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_key_vault" "key_vault" {
  name                        = "testingInternal-001-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_access_policy" "owner_access_policy" {
  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Purge"
    ]
  key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
}

resource "azurerm_key_vault_access_policy" "kv-appgw-access-policy" {
  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id    = azurerm_user_assigned_identity.managed_identity.tenant_id
  object_id    = azurerm_user_assigned_identity.managed_identity.principal_id

  secret_permissions = [
    "Get",
  ]

  certificate_permissions = [
    "Get",
  ]
}

resource "azurerm_key_vault_certificate" "root_certificate" {
  name         = "root-cert"
  key_vault_id = azurerm_key_vault.key_vault.id
  certificate {
    contents = filebase64("../../bash/certs/root-cert.pfx")
    password = "s5p2rm1n"
  }

  depends_on = [ azurerm_key_vault_access_policy.owner_access_policy ]
}

resource "azurerm_key_vault_certificate" "vnet_internal_certificate" {
  name         = "vnet-internal-cert"
  key_vault_id = azurerm_key_vault.key_vault.id
  certificate {
    contents = filebase64("../../bash/certs/vnet-internal-cert.pfx")
    password = "s5p2rm1n"
  }

  depends_on = [ azurerm_key_vault_access_policy.owner_access_policy ]
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = "test-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
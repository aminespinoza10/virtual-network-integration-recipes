param location string = resourceGroup().location
param environmentName string = 'test'
param keyVaultName string = '${environmentName}-internal-001-kv'
param miName string = '${environmentName}-mi'
param logAnalyticsWorkspaceName string = '${environmentName}-logs'
var acrName = '${environmentName}internalapps0acr'

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

// azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

//managed identities
resource user_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: miName
  location: location
}

resource kv_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: user_identity.name
}

// key vault
resource kv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: kv_identity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}



//log analytics workspace
resource logAnalyticsWorkspace'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

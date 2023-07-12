param environmentName string
param location string
param workspaceName string
param storageAccountName string
param fileShareName string
param includeStorage bool
param subnetId string
param internal bool
param configureVnet bool = false

resource environment 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference('Microsoft.OperationalInsights/workspaces/${workspaceName}', '2020-08-01').customerId
        sharedKey: listKeys('Microsoft.OperationalInsights/workspaces/${workspaceName}', '2020-08-01').primarySharedKey
      }
    }
    vnetConfiguration: configureVnet ? {
      internal: internal
      infrastructureSubnetId: subnetId
    } : null
  }
}

resource storage 'Microsoft.App/managedEnvironments/storages@2022-11-01-preview' = if (includeStorage) {
  name: fileShareName
  parent: environment
  properties: {
    azureFile: {
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys('2022-09-01').keys[0].value
      accountName: storageAccountName
      shareName: fileShareName
    }
  }
}

// bring keys from existing storage account resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

output id string = environment.id
output staticIp string = environment.properties.staticIp
output domainName string = environment.properties.defaultDomain

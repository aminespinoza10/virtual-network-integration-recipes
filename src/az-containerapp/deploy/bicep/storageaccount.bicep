param storageAccountName string
param storageAccountSku string
param fileShareName string
param location string
param createFileShare bool = false


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource filesService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = if (createFileShare) {
  name: 'default'
  parent: storageAccount
  properties: {}
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: fileShareName
  parent: filesService
  properties: {}
}

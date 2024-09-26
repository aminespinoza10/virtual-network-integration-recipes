param location string = resourceGroup().location
param environmentName string = 'test'
param keyVaultName string = '${environmentName}-001-kv'
param miName string = '${environmentName}-mi'
param logAnalyticsWorkspaceName string = '${environmentName}-logs'
var acrName = '${environmentName}0apps0acr'

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

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

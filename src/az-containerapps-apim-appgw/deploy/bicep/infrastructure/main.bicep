param location string = resourceGroup().location
param environmentName string = 'test'
param appgwSubnetName string = 'appgw-subnet'
param apimSubnetName string = 'apim-subnet'
param appsvcSubnetName string = 'appsvc-subnet'
param keyVaultName string = '${environmentName}-001-kv'
param miName string = '${environmentName}-mi'
param logAnalyticsWorkspaceName string = '${environmentName}-logs'

var virtualNetworkName = '${environmentName}-vnet'
var apimName = '${environmentName}-001-apim'
var dnsName = 'vnet.internal'
var appGwName = '${environmentName}-appGw'
var deployApim = true
var deployAppEnv = true
var deployAppGw= true

resource logAnalyticsWorkspace'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' existing = {
  name: logAnalyticsWorkspaceName
}

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
}

module vnetModule 'vnet.bicep' = {
  name: 'vnetDeploy'
  params: {
    virtualNetworkName: virtualNetworkName
    appgwSubnetName: appgwSubnetName
    apimSubnetName: apimSubnetName
    appsvcSubnetName: appsvcSubnetName
    location: location
  }
}

module appEnvModule 'appsenv.bicep' = {
  name: 'appEnvDeploy'
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: appsvcSubnetName
    environmentName: environmentName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    dnsName: dnsName
    wildcardCertificateBase64: kv.getSecret('vnet-internal-cert')
    deployAppEnv: deployAppEnv
  }
  dependsOn: [vnetModule]
}

module apimModule 'apim.bicep' = {
  name: 'apimDeploy'
  params: {
    location: location
    apimName: apimName
    virtualNetworkName: virtualNetworkName
    subnetName: apimSubnetName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    dnsName: dnsName
    keyVaultName: keyVaultName
    identityName: miName
    rootCertificateBase64: kv.getSecret('root-cert')
    deployApim: deployApim
  }
  dependsOn: [vnetModule]
}

module dnsModule 'dns.bicep' = {
  name: 'dnsDeploy'
  params: {
    dnsName: dnsName
    virtualNetworkName: virtualNetworkName
    apimPrivateIp: apimModule.outputs.apimPrivateIp
  }
  dependsOn: [appEnvModule, apimModule]
}

module appGwModule 'appgw.bicep' = {
  name: 'appGwDeploy'
  params: {
    location: location
    environmentName: environmentName
    appGatewayName: appGwName
    virtualNetworkName: virtualNetworkName
    subnetName: appgwSubnetName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    dnsName: dnsName
    identityName: miName
    keyVaultName: keyVaultName
    deployAppGw: deployAppGw
  }
  dependsOn: [apimModule]
}

output apimUrl string = 'https://${apimModule.outputs.apimHost}'
output appGwUrl string = appGwModule.outputs.appGwUrl

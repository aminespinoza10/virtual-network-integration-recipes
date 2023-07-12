// scope
targetScope = 'subscription'

// parameters
param function string
param env string = 'dev'
param location string = 'australiaeast'
param vnetAddressSpace array = [
  '172.16.48.0/21'
]
param subnetAddressSpaces array = [
  {
    name: 'default'
    subnetPrefix: '172.16.48.0/23'
  }
]
// param dtlVnetName string = 'vnet-dtl-ci01'
// param dtlVnetResourceGroup string = 'rsg-dtl-ci01'

// variables
var resGroupName = 'rsg-${function}-${env}'
var networkName = 'nw-${function}-${env}'
var managedEnvironmentName = 'me-${function}-${env}'
var dnsZoneName = 'dnz${function}${env}'
var vnetLinkName = '${function}${env}'
var monitoringName = 'logs-${function}-${env}'
var storageAccountName = 'sa${function}${env}'
var fileShareName = 'fs${function}${env}'
var artefactRegistryName = 'acr${function}${env}'
var containerAppName = 'ca${function}${env}'
var identityName = 'id${function}${env}'


// resource group
resource resGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resGroupName
  location: location
  tags: {
    name: 'az-containerapp'
    purpose: 'private-containerapp'
  }
}

module network 'network.bicep' = {
  scope: resGroup
  name: networkName
  params: {
    vnetName: networkName
    vnetAddressSpace: vnetAddressSpace
    subnetAddressSpaces: subnetAddressSpaces
    vnExists: false
    location: location
  }
}

module managedEnvironment 'managedenvironment.bicep' = {
  scope: resGroup
  name: managedEnvironmentName
  params: {
    location: location
    environmentName: managedEnvironmentName
    workspaceName: monitoring.outputs.logWorkspaceName
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    includeStorage: true
    configureVnet: true
    subnetId: network.outputs.subnetId
    internal: true
  }
  dependsOn: [
    monitoring
    storageAccount
  ]
}

module privateDnsZone 'dnszone.bicep' = {
  scope: resGroup
  name: dnsZoneName
  params: {
    vnetLinkName: vnetLinkName
    vNetId: network.outputs.vnetId
    zoneName: managedEnvironment.outputs.domainName
    registrationEnabled: false
    environmentStaticIP: managedEnvironment.outputs.staticIp
    // peernetworkId: dtlVnet.id
  }
}

module monitoring 'monitoring.bicep' = {
  scope: resGroup
  name: 'monitors'
  params: {
    monitoringName: monitoringName
    location: location
  }
}

module storageAccount 'storageaccount.bicep' = {
  scope: resGroup
  name: storageAccountName
  params: {
    location: location
    storageAccountName: storageAccountName
    storageAccountSku: 'Standard_LRS'
    fileShareName: fileShareName
    createFileShare: true
  }
}

module artefactRegistry 'artefactregistry.bicep' = {
  scope: resGroup
  name: artefactRegistryName
  params: {
    name: artefactRegistryName
    location: location
    workspaceId: monitoring.outputs.logWorkspaceId
  }
}

module app 'containerapp.bicep' = {
  scope: resGroup
  name: 'app'
  params: {
    location: location
    containerAppName: containerAppName
    environmentId: managedEnvironment.outputs.id
    volumename: fileShareName
    containerRegistryName: artefactRegistry.outputs.name
    identityName: identityName
  }
  dependsOn: [
    privateDnsZone
  ]
}

// outputs
output vnetId string = network.outputs.vnetId
output managed_environment_domainName string = managedEnvironment.outputs.domainName
output azure_artefact_registry_name string = artefactRegistry.outputs.name
output azure_artefact_registry_endpoint string = artefactRegistry.outputs.loginServer
output service_api_identity_principal_id string = app.outputs.apiFqdn
output principal_app_client_id string = app.outputs.apiIdentityClientId
output resource_group_name string = resGroup.name
output container_app_name string = app.outputs.apiContainerAppName

param apimName string
param location string
param virtualNetworkName string
param subnetName string
param logAnalyticsWorkspaceId string
param dnsName string
param identityName string
param keyVaultName string
@secure()
param rootCertificateBase64 string
param deployApim bool

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: '${virtualNetworkName}/${subnetName}'
}

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: identityName
}

resource apim 'Microsoft.ApiManagement/service@2022-04-01-preview' = if (deployApim) {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}' : {}   
    }
  }
  properties: {
    publisherEmail: 'adipa@example.com'
    publisherName: 'adipa'
    virtualNetworkConfiguration: {
      subnetResourceId: subnet.id     
    }
    certificates: [
      {
        storeName: 'Root'
        encodedCertificate: rootCertificateBase64
        certificatePassword: ''
      }
    ]
    hostnameConfigurations: [
      {
        type:'Proxy'
        hostName: 'apim.${dnsName}'
        keyVaultId: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/vnet-internal-cert'
        certificatePassword: ''
        identityClientId : mi.properties.clientId
        negotiateClientCertificate:false
        defaultSslBinding: true 
      }
    ]
    //customProperties:{
      //'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
     //}
    virtualNetworkType: 'Internal'
  }
}

resource diagSettings 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'writeToLogAnalytics'
  scope: apim
  properties:{
   logAnalyticsDestinationType: 'Dedicated'
   workspaceId : logAnalyticsWorkspaceId
    logs:[
      {
        category: 'GatewayLogs'
        enabled:true
        retentionPolicy:{
          enabled:false
          days: 0
        }
      }         
    ]
    metrics:[
      {
        category: 'AllMetrics'
        enabled:true
        timeGrain: 'PT1M'
        retentionPolicy:{
         enabled:false
         days: 0
       }
      }
    ]
  }
 }

var apimUrl = apim.properties.gatewayUrl
output apimHost string = replace(replace(apimUrl, 'https://', ''), 'http://', '')

output apimPrivateIp string = apim.properties.privateIPAddresses[0]

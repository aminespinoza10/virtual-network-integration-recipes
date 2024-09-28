param environmentName string
param location string 
param virtualNetworkName string
param subnetName string
param logAnalyticsWorkspaceId string
param dnsName string
@secure()
param wildcardCertificateBase64 string
param deployAppEnv bool

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: '${virtualNetworkName}/${subnetName}'
}

resource appEnvironment 'Microsoft.App/managedEnvironments@2022-06-01-preview' = if (deployAppEnv) {
  name: '${environmentName}-env'
  location: location
  sku: {
    name: 'Consumption'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2020-03-01-preview').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2020-03-01-preview').primarySharedKey
      }
    }
    customDomainConfiguration: {
      dnsSuffix: dnsName
      certificateValue: wildcardCertificateBase64
      certificatePassword: ''
    }
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: subnet.id
      dockerBridgeCidr: '10.0.4.0/24'
      platformReservedCidr: '10.0.5.0/24'
      platformReservedDnsIP: '10.0.5.2'
    }
    zoneRedundant: false
  }
}

var defaultDomain = appEnvironment.properties.defaultDomain
var staticIp = appEnvironment.properties.staticIp
output defaultDomain string = defaultDomain
output staticIp string = staticIp

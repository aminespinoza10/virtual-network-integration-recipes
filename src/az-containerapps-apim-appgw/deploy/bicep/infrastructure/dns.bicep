param virtualNetworkName string
param apimPrivateIp string
param dnsName string

resource vnet 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: virtualNetworkName
}

resource appEnvDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsName
  location:'global'
  properties: {}
}

resource appEnvDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${virtualNetworkName}-${dnsName}-link'
  location:'global'
  parent: appEnvDnsZone
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: true
  }
}

resource apimARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: 'apim'
  parent: appEnvDnsZone
  properties: {
    ttl: 60
    aRecords: [
      {
        ipv4Address: apimPrivateIp
      }
    ]
  }
}

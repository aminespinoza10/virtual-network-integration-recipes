param vnetLinkName string
param vNetId string
param zoneName string
param registrationEnabled bool = true
param environmentStaticIP string = ''
// param peerNetworkId string = ''

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zoneName
  location: 'global'
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: vnetLinkName
  location: 'global'
  parent: privateDNSZone
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: vNetId
    }
  }
}

// resource vnetLink2 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (peerNetworkId != '') {
//   name: '${function}${env}2'
//   location: 'global'
//   parent: privateDNSZone
//   properties: {
//     registrationEnabled: true
//     virtualNetwork: {
//       id: peerNetworkId
//     }
//   }
// }

resource privateDnsZone_A 'Microsoft.Network/privateDnsZones/A@2020-06-01' = if (environmentStaticIP != '') {
  name: '*'
  parent: privateDNSZone
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: environmentStaticIP
      }
    ]
  }
}

output privateDNSZoneName string = privateDNSZone.name

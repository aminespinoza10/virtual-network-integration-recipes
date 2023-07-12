param vnetName string
param location string = resourceGroup().location

param vnetAddressSpace array
param subnetAddressSpaces array

param vnExists bool = false

resource vn 'Microsoft.Network/virtualNetworks@2022-07-01' existing = if (vnExists) {
  name: vnetName
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = if (!vnExists) {
  location: location
  name: vnetName

  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressSpace
    }

    subnets: [for sn in subnetAddressSpaces: {
      name: sn.name
      properties: {
        addressPrefix: sn.subnetPrefix
      }
    }]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = [for sn in subnetAddressSpaces: if (vnExists) {
  parent: vn
  name: sn.name
  properties: {
    addressPrefix: sn.subnetPrefix
  }
}]

output vnetName string = (vnExists ? vn.name : vnet.name)
output vnetId string = (vnExists? vn.id : vnet.id)
output subnetId string = subnet[0].id

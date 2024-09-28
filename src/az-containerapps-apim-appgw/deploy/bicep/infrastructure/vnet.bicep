param location string
param virtualNetworkName string
param appgwSubnetName string
param apimSubnetName string
param appsvcSubnetName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: '${virtualNetworkName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'appgw-to-apim'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.0.0/24'
          destinationAddressPrefix: '10.0.1.0/24'
          access: 'Allow'
          priority: 170
          direction: 'Inbound'
        }
      }
      {
        name: 'apim-to-appsvc'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/23'
          access: 'Allow'
          priority: 180
          direction: 'Inbound'
        }
      }
      {
        name: 'container-to-appsvc'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/23'
          access: 'Allow'
          priority: 190
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-internet-traffic'
        properties:{
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '10.0.0.0/24'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        } 
      }
      {
        name: 'allowCommunicationBetweenInfrastructuresubnet'
        properties: {
          priority: 210
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.2.0/23'
          destinationAddressPrefix: '10.0.2.0/23'
        }
      }
      {
        name: 'allowAzureLoadBalancerCommunication'
        properties: {
          priority: 220
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowAKSSecureConnectionInternalNodeControlPlaneUDP'
        properties: {
          priority: 230
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '1194'
          sourceAddressPrefix: 'AzureCloud.${location}'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowAKSSecureConnectionInternalNodeControlPlaneTCP'
        properties: {
          priority: 240
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9000'
          sourceAddressPrefix: 'AzureCloud.${location}'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'appGwInfraCommunication'
        properties: {
          priority: 250
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowOutboundCallstoAzureMonitor'
        properties: {
          priority: 250
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureMonitor'
        }
      }
      {
        name: 'allowAllOutboundOnPort443'
        properties: {
          priority: 260
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowNTPServer'
        properties: {
          priority: 270
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '123'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowContainerAppsControlPlaneTCP'
        properties: {
          priority: 280
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5671'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowContainerAppsControlPlaneTCP2'
        properties: {
          priority: 290
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5672'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allowCommsBetweenSubnet'
        properties: {
          priority: 300
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.2.0/23'
          destinationAddressPrefix: '10.0.2.0/23'
        }
      }
      {
        name: 'deny-apim-from-others'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '10.0.1.0/24'
          access: 'Allow' //change to deny later
          priority: 310
          direction: 'Inbound'
        }
      }
      {
        name: 'deny-appsvc-from-others'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '10.0.2.0/23'
          access: 'Deny'
          priority: 320
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: appgwSubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: apimSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Sql'
            }
            {
              service: 'Microsoft.EventHub'
            }
          ]
        }
      }
      {
        name: appsvcSubnetName
        properties: {
          addressPrefix: '10.0.2.0/23'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

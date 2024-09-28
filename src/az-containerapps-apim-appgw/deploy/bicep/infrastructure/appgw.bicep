param environmentName string
param appGatewayName string
param location string
param virtualNetworkName string
param subnetName string
param logAnalyticsWorkspaceId string
param dnsName string
param identityName string
param keyVaultName string
param deployAppGw bool

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: identityName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: '${virtualNetworkName}/${subnetName}'
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${environmentName}-appgw-public-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod:'Static'
  }
}

var appGwId = resourceId('Microsoft.Network/applicationGateways', appGatewayName)

resource appgw 'Microsoft.Network/applicationGateways@2022-07-01' = if (deployAppGw) {
  name: appGatewayName
  location: location
  identity:{
    type:'UserAssigned'
    userAssignedIdentities:{
      '${mi.id}' : {}
    }
  }
  properties:{
    sku:{
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    enableHttp2:true
    sslPolicy:{
      policyType:'Predefined'
      policyName:'AppGwSslPolicy20170401S'
    }
    autoscaleConfiguration:{
      minCapacity: 1
      maxCapacity: 2
    }
    webApplicationFirewallConfiguration:{
      enabled:true
      firewallMode:'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.1'
      disabledRuleGroups:[
        {
          ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
          rules:[
            920320
          ]
        }
      ]
      exclusions:[
        
      ]
      requestBodyCheck:false
    }
    trustedRootCertificates:[{
      name: 'root_cert_internaldomain'
      properties: {
        keyVaultSecretId: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/root-cert'
      }
    }
    ]
    probes:[
      {
        name: 'apimgw-probe'
        properties:{
          pickHostNameFromBackendHttpSettings:true
          interval:30
          timeout:30
          path: '/status-0123456789abcdef'
          protocol:'Https'
          unhealthyThreshold:3
          match:{
            statusCodes:[
              '200-399'
            ]
          }
        }
      }            
    ]
    gatewayIPConfigurations:[
      {
        name: 'appgw-ip-config'
        properties:{
          subnet:{
            id: subnet.id
          }
        }
      }
    ]
    frontendIPConfigurations:[
      { 
        name:'appgw-public-frontend-ip'
        properties:{
          publicIPAddress:{
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts:[
      {
        name: 'port_80'
        properties:{
          port: 80
        }
      }
    ]
    backendAddressPools:[
      { 
        name: 'backend-apigw'
        properties:{
          backendAddresses:[
            {
              fqdn: 'apim.${dnsName}'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection:[
     {
       name: 'apim_gw_httpssetting'
       properties:{
         port: 443
         protocol:'Https'
         cookieBasedAffinity:'Disabled'
         requestTimeout: 120
         connectionDraining:{
           enabled:true
           drainTimeoutInSec: 20
         }
         pickHostNameFromBackendAddress:true
         probe: {id : '${appGwId}/probes/apimgw-probe'}
         trustedRootCertificates:[
          {id :'${appGwId}/trustedRootCertificates/root_cert_internaldomain'}
         ]
       }
     } 
    ]
    httpListeners:[
      {
        name: 'apigw-http-listener'
        properties:{
          protocol:'Http'
          frontendIPConfiguration:  {id :'${appGwId}/frontendIPConfigurations/appgw-public-frontend-ip'}
          frontendPort:  {id :'${appGwId}/frontendPorts/port_80'}
        }
      }          
    ]
    rewriteRuleSets:[
      {
        name: 'default-rewrite-rules'
        properties:{
          rewriteRules:[
            {
              ruleSequence : 1000
              conditions:[
              ]
              name: 'HSTS header injection'
              actionSet:{
                requestHeaderConfigurations:[
                  
                ]
                responseHeaderConfigurations:[
                  {
                    headerName: 'Strict-Transport-Security'
                    headerValue: 'max-age=31536000; includeSubDomains'
                  }
                ]
              }
            }
          ]
        }
      }
    ]
    requestRoutingRules:[
      {
        name: 'routing-apigw'
        properties:{
          priority: 1
          ruleType:'Basic'
          httpListener:  {id :'${appGwId}/httpListeners/apigw-http-listener'}
          backendAddressPool:  {id :'${appGwId}/backendAddressPools/backend-apigw'}
          backendHttpSettings:  {id :'${appGwId}/backendHttpSettingsCollection/apim_gw_httpssetting'}
          rewriteRuleSet:  {id :'${appGwId}/rewriteRuleSets/default-rewrite-rules'}
        }
      }
    ]
  }
}

resource diagSettings 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
 name: 'writeToLogAnalytics'
 scope: appgw
 properties:{
  workspaceId : logAnalyticsWorkspaceId
   metrics:[
     {
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

output appGwUrl string = 'http://${publicIp.properties.ipAddress}'

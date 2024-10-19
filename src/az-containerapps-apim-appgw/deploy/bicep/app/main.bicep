param location string = resourceGroup().location
param environmentName string = 'test'
param dnsName string = 'vnet.internal'

var apimName = '${environmentName}-001-apim'
var apiName = 'ping-app'
var acrName = '${environmentName}internalapps0acr'

resource environment 'Microsoft.App/managedEnvironments@2022-06-01-preview' existing = {
  name: '${environmentName}-env'
}

resource apim 'Microsoft.ApiManagement/service@2022-04-01-preview' existing = {
  name: apimName
}

resource appEnvDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing= {
  name: dnsName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
}

resource minimalApiApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: apiName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        transport: 'auto'
        external: true
        targetPort: 8080
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [{
        server: acr.properties.loginServer
        username: acr.name
        passwordSecretRef: 'acr-password'
      }]
      secrets: [{
        name: 'acr-password'
        value: acr.listCredentials().passwords[0].value
      }]
    }
    template: {
      containers: [
        {
          image: 'docker.io/aminespinoza/minimalapi:latest'
          name: apiName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource appARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: apiName
  parent: appEnvDnsZone
  properties: {
    ttl: 60
    aRecords: [
      {
        ipv4Address: environment.properties.staticIp
      }
    ]
  }
}

var hostName = environment.properties.customDomainConfiguration.dnsSuffix

resource apimReg 'Microsoft.ApiManagement/service/apis@2022-04-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    displayName: apiName
    apiType: 'http'
    path: apiName
    protocols: ['https']
    format: 'openapi-link'
    serviceUrl: 'http://ping-app.${hostName}'
    value: 'http://ping-app.${hostName}/swagger/v1/swagger.json'
    subscriptionRequired: false
    isCurrent: true
  }
  dependsOn: [minimalApiApp]
}

resource apimPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-04-01-preview' = {
  parent: apimReg
  name: 'policy'
  properties: {
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n  </inbound>\r\n  <backend>\r\n    <forward-request timeout="10" follow-redirects="true" />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
  dependsOn: [minimalApiApp]
}

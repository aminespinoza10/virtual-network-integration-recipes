param location string
param containerAppName string
param environmentId string
param imageName string = ''
param volumename string
param containerRegistryName string
param identityName string


resource apiIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module containerRegistryAccess 'registry-access.bicep' = {
  name: '${deployment().name}-registry-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: apiIdentity.properties.principalId
  }
}


resource simpleFastAPI 'Microsoft.App/containerApps@2022-10-01' = {
  name: '${containerAppName}aca'
  location: location
  dependsOn: [ containerRegistryAccess ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${apiIdentity.id}': {} }
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        allowInsecure: true
        external: true
        targetPort: 3100
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          identity: apiIdentity.id
        }
      ]
    }
    managedEnvironmentId: environmentId
    template: {
      containers: [
        {
          args: []
          command: []
          env: [
            {
              name: 'REDIS_PASSWORD'
              value: 'samplevalue'
            }
          ]
          image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'simplefastapi'
          probes: []
          resources: {
            cpu: json('2.0')
            memory: '4.0Gi'
          }
          volumeMounts: [
            {
              mountPath: '/home'
              volumeName: volumename
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
      volumes:[
        {
          name: volumename
          storageName: volumename
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

output apiFqdn string = simpleFastAPI.properties.configuration.ingress.fqdn
output apiIdentityPrincipalId string = apiIdentity.properties.principalId
output apiIdentityClientId string = apiIdentity.properties.clientId
output apiIdentityTenantId string = apiIdentity.properties.tenantId
output apiIdentityId string = apiIdentity.id
output apiContainerAppName string = simpleFastAPI.name
// output redisFqdn string = (redisDeploymentOption == 'container') ? redisContainer.properties.configuration.ingress.fqdn : ''
// output webLatestRevisionName string = wordpressApp.properties.latestRevisionName
// output envSuffix string = environment.outputs.envSuffix
// output loadBalancerIP string = environment.outputs.loadBalancerIP

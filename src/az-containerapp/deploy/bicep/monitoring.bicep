param monitoringName string
param location string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: monitoringName
  location: location
}

output logWorkspaceId string = logWorkspace.id
output logWorkspaceName string = logWorkspace.name

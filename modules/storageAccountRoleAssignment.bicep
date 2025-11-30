// modules/storageAccountRoleAssignment.bicep
targetScope = 'resourceGroup'

@description('Principal ID of the VM managed identity')
param principalId string

// Storage account already exists in THIS resource group (the module scope)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: 'sthaproxyshared'
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    )
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

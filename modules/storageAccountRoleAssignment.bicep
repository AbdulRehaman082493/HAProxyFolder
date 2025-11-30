// modules/storageAccountRoleAssignment.bicep
targetScope = 'resourceGroup'

@description('Principal ID of the VM managed identity')
param principalId string

@description('Name of the existing storage account')
param storageAccountName string

// Storage account already exists in THIS resource group (module scope)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// Storage Blob Data Contributor role definition
resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  // ID for "Storage Blob Data Contributor"
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageBlobDataContributor.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributor.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

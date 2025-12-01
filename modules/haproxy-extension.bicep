// modules/haproxy-extension.bicep
targetScope = 'resourceGroup'

@description('Location of the VM / resource group')
param location string

@description('Name of the HAProxy VM in this resource group')
param vmName string

@description('Name of existing storage account that holds haproxy files')
param storageAccountName string

@description('Resource group of the storage account (in Azure subscription 1)')
param storageResourceGroup string

@description('Subscription ID of the storage account (Azure subscription 1)')
param storageSubscriptionId string

@description('Config filename in the haproxy container, e.g. haproxy.cfg.dev')
param configFileName string

@description('Script filename in the haproxy container, e.g. install_haproxy.sh')
param scriptFileName string = 'install_haproxy.sh'

@description('Blob container name (same for all envs)')
param containerName string = 'haproxy'

@description('Bump this value to force re-run of the extension')
param extensionRunVersion string = 'v1'

// Storage account exists in OTHER subscription
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  scope: resourceGroup(storageSubscriptionId, storageResourceGroup)
  name: storageAccountName
}

// Build blob URLs in a cloud-agnostic way
var blobBaseUrl = 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
var scriptUrl   = '${blobBaseUrl}/${containerName}/${scriptFileName}'
var configUrl   = '${blobBaseUrl}/${containerName}/${configFileName}'

// NOTE: we do NOT declare the VM as "existing" here.
// Instead, we use the full name "vmName/extensionName",
// and ARM infers the dependency on the VM.
resource haproxyInstallExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: '${vmName}/install-haproxy-from-blob'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    forceUpdateTag: extensionRunVersion

    settings: {
      fileUris: [
        scriptUrl
        configUrl
      ]
    }

    protectedSettings: {
      // Use the VM's system-assigned managed identity
      managedIdentity: {}
      commandToExecute: 'bash ${scriptFileName} ${configFileName}'
    }
  }
}

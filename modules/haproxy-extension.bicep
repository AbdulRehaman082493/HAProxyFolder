targetScope = 'resourceGroup'

@description('Name of the existing HAProxy VM in this resource group (Subscription Work)')
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

// VM exists in CURRENT subscription+RG
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

// Storage account exists in OTHER subscription
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  scope: resourceGroup(storageSubscriptionId, storageResourceGroup)
  name: storageAccountName
}

var blobBaseUrl = 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
var scriptUrl   = '${blobBaseUrl}/${containerName}/${scriptFileName}'
var configUrl   = '${blobBaseUrl}/${containerName}/${configFileName}'

resource haproxyInstallExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: 'install-haproxy-from-blob'
  parent: vm
  location: vm.location
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
      managedIdentity: {}
      commandToExecute: 'bash ${scriptFileName} ${configFileName}'
    }
  }
}

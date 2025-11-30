param vmName string
param location string = resourceGroup().location
param storageAccountName string
param configFileName string   // e.g. 'haproxy.cfg.dev'
param scriptFileName string = 'install_haproxy.sh'
param containerName string = 'haproxy'
param extensionRunVersion string = 'v1'  // bump to force rerun

// Existing VM (with system-assigned identity already enabled)
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

// Existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var scriptUrl = 'https://${storageAccountName}.blob.core.windows.net/${containerName}/${scriptFileName}'
var configUrl = 'https://${storageAccountName}.blob.core.windows.net/${containerName}/${configFileName}'

resource haproxyInstallExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: 'install-haproxy-from-blob'
  parent: vm
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

    // Use system-assigned managed identity to access private blobs
    protectedSettings: {
      managedIdentity: {}
      commandToExecute: 'bash ${scriptFileName} ${configFileName}'
    }
  }
}

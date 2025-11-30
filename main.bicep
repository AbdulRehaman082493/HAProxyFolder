@description('Environment name')
@allowed([
  'dev'
  'test'
  'stage'
  'prod'
])
param environment string

@description('Azure region')
param location string

@description('Linux VM name')
param vmName string

@description('VM size')
param vmSize string = 'Standard_B2ms'

@description('Admin username for the VM')
param adminUsername string

@description('Admin password for the VM')
@secure()
param adminPassword string

@description('Existing subnet resource ID')
param subnetId string

@description('Name of the storage account hosting HAProxy files')
param storageAccountName string

@description('Name of the container hosting HAProxy files')
param containerName string = 'haproxy'

@description('Environment config blob name, e.g. haproxy.cfg.dev')
param haproxyConfigBlob string

@description('Deploy script blob name, e.g. deploy-haproxy.sh')
param deployScriptBlob string

@description('OS disk size in GB')
param osDiskSizeGb int = 64

@description('Tag owner')
param owner string = 'haproxy'

var nicName = '${vmName}-nic'

//
// ---------------------------
// Network Interface
// ---------------------------
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
  tags: {
    environment: environment
    owner: owner
    workload: 'haproxy'
  }
}

//
// ---------------------------
// Virtual Machine
// ---------------------------
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }

    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }

    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGb
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }

  tags: {
    environment: environment
    owner: owner
    workload: 'haproxy'
  }
}

//
// ---------------------------
// Cross-subscription Storage Role Assignment (Module)
// ---------------------------
module storageAccountRoleAssignment 'modules/storageAccountRoleAssignment.bicep' = {
  name: 'storageAccountRoleAssignment'
  scope: resourceGroup('06aa5329-5b5a-4789-bfe4-f8c2bfd81041', 'rg-haproxy')
  params: {
    principalId: vm.identity.principalId
  }
}

//
// ---------------------------
// Custom Script Extension
// ---------------------------
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  name: 'haproxy-customscript'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true

    // ✅ Public settings: only non-sensitive config
    settings: {
      fileUris: [
        // blob URLs WITHOUT SAS, private container
        'https://${storageAccountName}.blob.core.windows.net/${containerName}/${haproxyConfigBlob}'
        'https://${storageAccountName}.blob.core.windows.net/${containerName}/${deployScriptBlob}'
      ]
      commandToExecute: 'bash deploy-haproxy.sh'
    }

    // ✅ Protected settings: tell the extension to use the VM's system-assigned identity
    protectedSettings: {
      managedIdentity: {} // empty object = use parent VM system-assigned identity
    }
  }
}

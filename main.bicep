targetScope = 'resourceGroup'

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

@description('OS disk size in GB')
param osDiskSizeGb int = 64

@description('Tag owner')
param owner string = 'haproxy'

// Storage information (other subscription)
@description('Storage account subscription id (Azure subscription 1)')
param storageSubscriptionId string

@description('Storage account resource group (Azure subscription 1)')
param storageResourceGroup string

@description('Storage account name (Azure subscription 1)')
param storageAccountName string

// Networking
var nicName = '${vmName}-nic'

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

// (Optional) role assignment module – if you use it
// (Optional) role assignment module – if you use it
module storageAccountRoleAssignment 'modules/storageAccountRoleAssignment.bicep' = {
  name: 'storageAccountRoleAssignment'
  scope: resourceGroup(storageSubscriptionId, storageResourceGroup)
  params: {
    principalId: vm.identity.principalId
    storageAccountName: storageAccountName
  }
}


// AAD login extension (as you had)
resource vmName_AADSSHLoginForLinux 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'AADSSHLogin'
  location: location
  parent: vm
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADSSHLoginForLinux'
    typeHandlerVersion: '1.0'
  }
}

module haproxyExt 'modules/haproxy-extension.bicep' = {
  name: 'dev-haproxy-extension'
  params: {
    location: location                 // same param you use for the VM
    vmName: vmName                     // same VM name
    storageAccountName: storageAccountName
    storageResourceGroup: storageResourceGroup
    storageSubscriptionId: storageSubscriptionId
    containerName: 'haproxy'
    configFileName: 'haproxy.cfg.dev'
    scriptFileName: 'install_haproxy.sh'
    extensionRunVersion: 'dev-v1'
  }
}



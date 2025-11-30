using '../main.bicep'

param environment = 'dev'
param location    = 'northcentralus'
param vmName      = 'vm-haproxy-dev'
param vmSize      = 'Standard_B2ms'
param adminUsername = 'rehu493'
param adminPassword = '11NE1A0493sk@'  // ⚠️ demo only – don’t commit real password

param subnetId = '/subscriptions/1ad372fa-1532-4709-9b46-17de54fa0b71/resourceGroups/rg-haproxy-vm/providers/Microsoft.Network/virtualNetworks/vnet-haproxy-vm/subnets/default'

param osDiskSizeGb = 64
param owner        = 'haproxy'

// Storage info (other subscription)
param storageSubscriptionId = '06aa5329-5b5a-4789-bfe4-f8c2bfd81041'
param storageResourceGroup  = 'rg-haproxy'
param storageAccountName    = 'sthaproxyshared'

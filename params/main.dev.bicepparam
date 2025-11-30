using '../main.bicep'

param environment = 'dev'

param location = 'northcentralus'

param vmName = 'vm-haproxy-dev'

param vmSize = 'Standard_B2ms'

param adminUsername = 'rehu493'

@secure()
param adminPassword = '11NE1A0493sk@'

param subnetId = '/subscriptions/1ad372fa-1532-4709-9b46-17de54fa0b71/resourceGroups/rg-haproxy-vm/providers/Microsoft.Network/virtualNetworks/vnet-haproxy-vm/subnets/default'

param storageAccountName = 'sthaproxyshared'

param containerName = 'haproxy'

param haproxyConfigBlob = 'haproxy.cfg.dev'

param deployScriptBlob = 'deploy-haproxy.sh'

param osDiskSizeGb = 64

param owner = 'haproxy'

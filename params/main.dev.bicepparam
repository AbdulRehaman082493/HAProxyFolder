using '../main.bicep'

param environment = 'dev'

param location = 'northcentralus'

param vmName = 'vm-haproxy-dev'

param vmSize = 'Standard_B2ms'

param adminUsername = 'rehu493'

// No @secure() here – only value
param adminPassword = '11NE1A0493sk@'

param subnetId = '/subscriptions/1ad372fa-1532-4709-9b46-17de54fa0b71/resourceGroups/rg-haproxy-vm/providers/Microsoft.Network/virtualNetworks/vnet-haproxy-vm/subnets/default'

/*
param storageAccountName = 'sthaproxyshared'


param haproxyConfigBlob = 'haproxy.cfg.dev'

param deployScriptBlob = 'deploy-haproxy.sh'

*/
param osDiskSizeGb = 64

param owner = 'haproxy'

/*
param commandsArray = [
  '[ -f ./haproxy.cfg.dev ] || sudo cp ./haproxy.cfg.dev /opt/haproxy.cfg'
  '[ -f ./deploy-haproxy.sh ] || sudo cp ./deploy-haproxy.sh /opt/deploy-haproxy.sh'
  '[ -f ./server_config.json ] || sudo cp ./server_config.json /opt/server_config.json'
]

param scriptLocation = [
  'https://sthaproxyshared.blob.core.windows.net/haproxy/haproxy.cfg.dev'
  'https://sthaproxyshared.blob.core.windows.net/haproxy/deploy-haproxy.sh'
  'https://sthaproxyshared.blob.core.windows.net/haproxy/server_config.json'
]
*/

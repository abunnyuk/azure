// File: vault.bicep
// Author: Bunny Davies
// Version: 0.1

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// bastion params
param bastionName_p string = 'bh-${uniqueString(resourceGroup().id)}'
param disableCopyPaste_p bool = true
param enableFileCopy_p bool = false
param enableIpConnect_p bool = false
param enableShareableLink_p bool = false

param vnetName_p string = 'vnet-${uniqueString(resourceGroup().id)}'
param subnetName_p string = 'AzureBastionSubnet'

@description('Allow native client support.')
param enableTunneling_p bool = false
param scaleUnits_p int = 2

@allowed([
  'Basic'
  'Standard'
])
param skuName_p string = 'Basic'
param pipName_p string = 'pip-${uniqueString(resourceGroup().id)}'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// existing resources
resource subnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vnetName_p}/${subnetName_p}'
}

// resources
module pip_m 'publicIp.bicep' = {
  name: pipName_p
  params:{
    eventHubAuthId_p: eventHubAuthId_p
    eventHubName_p: eventHubName_p
    location_p: location_p
    pipName_p: pipName_p
    pipSkuName_p: 'Standard'
    resourceTags_p: resourceTags_p
  }
}

resource bastion_r 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
  }
  properties: {
    disableCopyPaste: disableCopyPaste_p
    enableFileCopy: enableFileCopy_p
    enableIpConnect: enableIpConnect_p
    enableShareableLink: enableShareableLink_p
    enableTunneling: enableTunneling_p
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnet_r.id
          }
          publicIPAddress: {
            id: pip_m.outputs.id
          }
        }
      }
    ]
    dnsName: '${bastionName_p}.bastion.azure.com'
    scaleUnits: scaleUnits_p
  }
}

resource bastionDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: bastion_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ouputs
output dnsName string = bastion_r.properties.dnsName

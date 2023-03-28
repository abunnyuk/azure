// File: virtualNetwork.bicep
// Author: Bunny Davies
// 
// Change log:
// - Initial release
// - Added default address
// - Added example usage
// 
// Creates a Virtual Network
// 
// module vnet_m 'modules/modular/vnet.bicep' = if (env_p.recreateVnet == 'True') {
//   scope: group_r
//   name: 'vnet_m'
//   params: {
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     resourceTags_p: resourceTags_p
//     vnetAddressPrefix_p: vnetAddressPrefix_v
//     vnetName_p: vnetName_v
//   }
// }

// global params/vars
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params/vars
param vnetName_p string = 'vnet-${uniqueString(resourceGroup().id)}'
param vnetAddressPrefix_p string = '10.99.0.0/24'

// resources
resource vnet_r 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix_p
      ]
    }
  }
}

resource vnetDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: vnet_r
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

// outputs
output api string = vnet_r.apiVersion
output id string = vnet_r.id
output name string = vnet_r.name
output type string = vnet_r.type

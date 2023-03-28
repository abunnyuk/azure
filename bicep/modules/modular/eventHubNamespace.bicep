// File: eventHubNamespace.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
// - Added example usage
// 
// Creates an Event Hub Namspace
//
// module eventHubNamespace_m 'modules/modular/eventHubNamespace.bicep' = {
//   scope: group_r
//   name: 'eventHubNamespace_m'
//   params: {
//     eventHubName_p: eventHubName_v
//     location_p: location_p
//     namespaceName_p: namespaceName_v
//     resourceTags_p: resourceTags_p
//     skuName_p: namespaceSku_v
//   }
// }

// global params
@description('Resource group location used if not defined')
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
@description('Resource name')
param namespaceName_p string = 'ehns-${uniqueString(resourceGroup().id)}'

@description('EventHub Namespace SKU')
@allowed([
  'Basic'
  'Premium'
  'Standard'
])
param skuName_p string = 'Standard'
param zoneRedundant_p bool = true

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

resource namespace_r 'Microsoft.EventHub/namespaces@2021-06-01-preview' = {
  name: namespaceName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
    capacity: 1
  }
  properties: {
    zoneRedundant: zoneRedundant_p
  }
}

resource namespaceDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: namespace_r
  name: 'default'
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthId_p
    eventHubName: eventHubName_p
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
output api string = namespace_r.apiVersion
output id string = namespace_r.id
output name string = namespace_r.name
output type string = namespace_r.type

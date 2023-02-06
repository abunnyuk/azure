// File: publicIp.bicep
//
// Change log:
// - Initial release
// - Added example usage
// 
// Creates a Public IP
// 
// module pip_m 'modules/modular/publicIp.bicep' = {
//   scope: group_r
//   name: 'pip_m'
//   params: {
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     pipMethod_p: 'Static'
//     pipName_p: pipName_v
//     pipSkuName_p: 'Standard'
//     resourceTags_p: resourceTags_p
//   }
// }

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// public ip params
param pipName_p string = 'pip-${uniqueString(resourceGroup().id)}'

@allowed([
  'Global'
  'Regional'
])
param pipSkuTier_p string = 'Regional'

@allowed([
  'Basic'
  'Standard'
])
param pipSkuName_p string = 'Basic'

@allowed([
  'IPv4'
  'IPv6'
])
param pipVersion_p string = 'IPv4'

@allowed([
  'Dynamic'
  'Static'
])
param pipMethod_p string = 'Dynamic'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// resources
resource pip_r 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: pipName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: pipSkuName_p
    tier: pipSkuTier_p
  }
  properties: {
    publicIPAddressVersion: pipVersion_p
    publicIPAllocationMethod: ((pipSkuName_p == 'Standard') ? 'Static' : pipMethod_p)
  }
}

resource pipDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: pip_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
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
output api string = pip_r.apiVersion
output id string = pip_r.id
output name string = pip_r.name

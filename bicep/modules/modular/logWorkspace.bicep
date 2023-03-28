// File: logWorkspace.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
// - Added example usage
// 
// Creates a Log Workspace
//
// module log_m 'modules/modular/logWorkspace.bicep' = {
//   scope: group_r
//   name: 'log_m'
//   params: {
//     location_p: location_p
//     resourceTags_p: resourceTags_p
//     skuName_p: 'PerGB2018'
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     workspaceName_p: logWorkspace_v
//   }
// }

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
param workspaceName_p string = 'log-${uniqueString(resourceGroup().id)}'

@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param skuName_p string = 'Standard'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

resource workspace_r 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    sku: {
      name: skuName_p
    }
  }
}

resource workspaceDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: workspace_r
  name: 'default'
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthId_p
    eventHubName: eventHubName_p
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
output api string = workspace_r.apiVersion
output id string = workspace_r.id
output name string = workspace_r.name

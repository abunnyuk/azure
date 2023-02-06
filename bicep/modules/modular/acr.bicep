// File: acr.bicep
// 0.1 - initial release
// 0.2 - added ZRS and geo-replication

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource specific params
param acrName_p string = 'acr${uniqueString(resourceGroup().id)}'
param adminEnabled_p bool = false

@allowed([
  'Basic'
  'Classic'
  'Premium'
  'Standard'
])
param skuName_p string = 'Basic'
param replicaLocation_p string = ''

// diags params
param eventHubAuthId_p string
param eventHubName_p string

resource acr_r 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
  }
  properties: {
    adminUserEnabled: adminEnabled_p
    zoneRedundancy: (skuName_p == 'Premium' ? 'Enabled' : 'Disabled')
  }

  resource replica_r 'replications' = if (!empty(replicaLocation_p) && skuName_p == 'Premium') {
    name: replicaLocation_p
    location: replicaLocation_p
    properties: {
      zoneRedundancy: 'Enabled'
    }
  }
}

resource acrDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: acr_r
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
output api string = acr_r.apiVersion
output id string = acr_r.id
output name string = acr_r.name
output url string = acr_r.properties.loginServer

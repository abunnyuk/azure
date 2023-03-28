// File: serviceBus.bicep
// Author: Bunny Davies
// Version: 0.1

// all resource params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// service bus params
@allowed([
  'Basic'
  'Premium'
  'Standard'
])
param skuName_p string = 'Standard'
param serviceBusName_p string = 'sb-${uniqueString(resourceGroup().id)}'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// resources
resource serviceBus_r 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: serviceBusName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
  }
  properties: {
    zoneRedundant: (skuName_p == 'Premium' ? true : false)
  }
}

resource busDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: serviceBus_r
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
        category: 'allMetrics'
        enabled: true
      }
    ]
  }
}

// ouputs
output api string = serviceBus_r.apiVersion
output id string = serviceBus_r.id
output name string = serviceBus_r.name
output type string = serviceBus_r.type

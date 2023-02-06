// File: appPlan.bicep
// 0.1 - initial release

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource specific params
@allowed([
  'functionapp'
  'linux'
  'windows'
])
param kind_p string = 'linux'
param planName_p string = 'plan-${uniqueString(resourceGroup().id)}'
param reserved_p bool = kind_p == 'linux' ? true : false

@allowed([
  'B1'
  'B2'
  'B3'
  'D1'
  'F1'
  'FREE'
  'I1'
  'I1v2'
  'I2'
  'I2v2'
  'I3'
  'I3v2'
  'P1V2'
  'P1V3'
  'P2V2'
  'P2V3'
  'P3V2'
  'P3V3'
  'PC2'
  'PC3'
  'PC4'
  'S1'
  'S2'
  'S3'
  'SHARED'
  'Y1'
])
param skuName_p string = 'B1'
param zoneRedundant_p bool = startsWith(skuName_p,'P1') || startsWith(skuName_p,'P2') ? true : false

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

resource plan_r 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: planName_p
  location: location_p
  tags: resourceTags_p
  kind: kind_p
  sku: {
    name: skuName_p
  }
  properties: {
    reserved: reserved_p
    zoneRedundant: zoneRedundant_p
  }
}

resource planDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: plan_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ouputs
output api string = plan_r.apiVersion
output id string = plan_r.id
output name string = plan_r.name

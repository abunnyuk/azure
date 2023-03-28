// File: sqlElasticPool.bicep
// Author: Bunny Davies
// 
// Change log:
// - Initial release
// - Added example usage
// 
// Creates an Elastic Pool on an existing SQL Server
// 
// var pools_v = [
//   {
//     id: 0
//     capacity: 50
//     tier: 'Standard'
//   }
//   {
//     id: 1
//     capacity: 100
//     tier: 'Premium'
//   }
// ]

// @batchSize(1)
// module sqlElasticPools_m 'modules/modular/sqlElasticPool.bicep' = [for pool in pools_v: {
//   name: 'sqlElasticPool_m-${pool.id}'
//   params: {
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     poolName_p: 'pool-${pool.id}'
//     resourceTags_p: resourceTags_p
//     skuCapacity_p: pool.capacity
//     sqlServerName_p: sqlServerName_v
//     tier_p: pool.tier
//   }
// }]

// global params/vars
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params/vars
@allowed([
  'BasePrice'
  'LicenseIncluded'
])
param licenseType_p string = 'LicenseIncluded'
param poolName_p string = 'pool-${uniqueString(resourceGroup().id)}'
param sqlServerName_p string

@allowed([
  'Basic'
  'Business'
  'General'
  'Premium'
  'Standard'
])
param tier_p string = 'Basic'
param skuCapacity_p int = tier_p == 'Business' || tier_p == 'General' ? 2 : 50
param zoneRedundant_p bool = false

var nameTier_v = {
  Basic: {
    skuName: 'BasicPool'
    skuTier: 'Basic'
  }
  Business: {
    skuName: 'BC_Gen5'
    skuTier: 'BusinessCritical'
  }
  General: {
    skuName: 'GP_Gen5'
    skuTier: 'GeneralPurpose'
  }
  Premium: {
    skuName: 'PremiumPool'
    skuTier: 'Premium'
  }
  Standard: {
    skuName: 'StandardPool'
    skuTier: 'Standard'
  }
}

// resources
resource sqlServer_r 'Microsoft.Sql/servers@2021-11-01-preview' existing = {
  name: sqlServerName_p
}

resource sqlElasticPool_r 'Microsoft.Sql/servers/elasticPools@2021-11-01-preview' = {
  name: poolName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    capacity: skuCapacity_p
    name: nameTier_v[tier_p].skuName
    tier: nameTier_v[tier_p].skuTier
  }
  parent: sqlServer_r
  properties: {
    licenseType: licenseType_p
    zoneRedundant: zoneRedundant_p
  }
}

resource sqlElasticPoolDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: sqlElasticPool_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
      }
    ]
  }
}

// outputs
output api string = sqlElasticPool_r.apiVersion
output id string = sqlElasticPool_r.id
output name string = sqlElasticPool_r.name
output type string = sqlElasticPool_r.type

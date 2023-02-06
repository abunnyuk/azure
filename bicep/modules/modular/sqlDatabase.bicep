// File: sqlDatabase.bicep

// all resource params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// module resource params
param collation_p string = 'SQL_Latin1_General_CP1_CI_AS'
param databaseName_p string = 'sqldb-${uniqueString(resourceGroup().id)}'
param poolName_p string = ''
param serverName_p string = 'sql-${uniqueString(resourceGroup().id)}'

@allowed([
  'Basic'
  'BusinessCritical'
  'Free'
  'GeneralPurpose'
  'Hyperscale'
  'Premium'
  'Provisioned'
  'Serverless'
  'Standard'
  'Stretch'
])
param skuTier_p string = 'Standard'
param skuName_p string = !empty(poolName_p) ? 'ElasticPool' : 'S0'
param zoneRedundant_p bool = false

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// resources

resource sql_r 'Microsoft.Sql/servers@2021-05-01-preview' existing = {
  name: serverName_p
}

resource elasticPool_r 'Microsoft.Sql/servers/elasticPools@2021-11-01-preview' existing = if (skuName_p == 'ElasticPool') {
  parent: sql_r
  name: poolName_p
}

resource database_r 'Microsoft.Sql/servers/databases@2021-05-01-preview' = {
  parent: sql_r
  name: databaseName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
    tier: skuName_p == 'ElasticPool' ? null : skuTier_p
  }
  properties: {
    elasticPoolId: skuName_p == 'ElasticPool' ? elasticPool_r.id : null
    collation: collation_p
    zoneRedundant: zoneRedundant_p
  }

  resource auditingSettings_r 'auditingSettings' = {
    name: 'default'
    properties: {
      state: 'Enabled'
      isAzureMonitorTargetEnabled: true
      auditActionsAndGroups: [
        'BATCH_COMPLETED_GROUP'
        'FAILED_DATABASE_AUTHENTICATION_GROUP'
        'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      ]
      storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
    }
  }
}

resource databaseDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: database_r
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
        category: 'Basic'
        enabled: true
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
      }
      {
        category: 'WorkloadManagement'
        enabled: true
      }
    ]
  }
}

// outputs
output api string = database_r.apiVersion
output id string = database_r.id
output name string = database_r.name

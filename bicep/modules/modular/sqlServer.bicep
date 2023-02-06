// File: sqlServer.bicep
// 
// Change log:
// - Initial release
// - Added example usage
// - Added support for elastic pools
// - Removed private endpoint resources
// 
// Creates a SQL Server
//
// param adAdminLogin_p string

// @secure()
// param adAdminSid_p string

// @secure()
// param localAdminPass_p string
// param localAdminUser_p string = 'sqldba'

// var sqlServers_v = [
//   0
//   1
// ]

// module sqlServers_m 'modules/modular/sqlServer.bicep' = [for server in sqlServers_v: {
//   scope: group_r
//   name: 'sqlServer_m-${server}'
//   params: {
//     adAdminLogin_p: adAdminLogin_p
//     adAdminSid_p: adAdminSid_p
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     localAdminPass_p: localAdminPass_p
//     localAdminUser_p: localAdminUser_p
//     resourceTags_p: resourceTags_p
//     serverName_p: 'sql-ops-data-${server}-dev'
//   }
// }]

// global params/vars
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
@description('Allow connections from IP addresses allocated to any Azure service or asset, including connections from the subscriptions of other customers.')
param allowAzureAccess_p bool = false

@description('''
Array of allowed IP addresses.
```
{
  name:
  startIp:
  endIp:
}
```
''')
param allowedIpAddresses_p array = []

@allowed([
  'None'
  'SystemAssigned'
  'UserAssigned'
])
param identity_p string = 'SystemAssigned'
param serverName_p string = 'sql-${uniqueString(resourceGroup().id)}'

// local admin (optional)
param localAdminUser_p string = 'sqldba'
@secure()
param localAdminPass_p string = ''

// ad admin (required)
param adAdminLogin_p string
@secure()
param adAdminSid_p string
param adAdminTenantId_p string = subscription().tenantId

// resources
resource sql_r 'Microsoft.Sql/servers@2021-05-01-preview' = {
  name: serverName_p
  location: location_p
  tags: resourceTags_p
  identity: {
    type: identity_p
  }
  properties: {
    administratorLogin: ((!empty(localAdminUser_p) && !empty(localAdminPass_p)) ? localAdminUser_p : null)
    administratorLoginPassword: ((!empty(localAdminPass_p)) ? localAdminPass_p : null)
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: adAdminLogin_p
      sid: adAdminSid_p
      tenantId: adAdminTenantId_p
    }
  }

  resource addAzureFirewallRule_r 'firewallRules' = if (allowAzureAccess_p) {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
}

resource addIPFirewallRule_r 'Microsoft.Sql/servers/firewallRules@2021-11-01-preview' = [for rule in allowedIpAddresses_p: {
  parent: sql_r
  name: '${rule.name}'
  properties: {
    endIpAddress: rule.startIp
    startIpAddress: rule.endIp
  }
}]

resource master_r 'Microsoft.Sql/servers/databases@2021-05-01-preview' existing = {
  parent: sql_r
  name: 'master'
}

resource sqlDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: master_r
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

resource auditingSettings_r 'Microsoft.Sql/servers/auditingSettings@2021-05-01-preview' = {
  parent: sql_r
  dependsOn: [
    sqlDiags_r
  ]
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

resource devOpsAuditingSettings_r 'Microsoft.Sql/servers/devOpsAuditingSettings@2021-05-01-preview' = {
  parent: sql_r
  dependsOn: [
    sqlDiags_r
  ]
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

// outputs
output api string = sql_r.apiVersion
output id string = sql_r.id
output name string = sql_r.name
output type string = sql_r.type

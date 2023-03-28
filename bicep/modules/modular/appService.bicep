// File: appService.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
// - Added identity support that defaults to none - previously hardcoded as SystemAssigned
// - Added health check with default of site root

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
@description('''
Array containing access restritions.

```
{
  vnetSubnetResourceId: subnet.id
  action: 'Allow'
  priority: 100
  name: 'allow-${subnet.name}'
}
```
''')
param accessRestrictions_v array = []

param alwaysOn_p bool = true
param appName_p string = 'app-${uniqueString(resourceGroup().id)}'

@description('''
Key pair application settings.

`FOO: bar`
''')
param appSettingsObject_p object = {}

@description('''
Object containing multiple connection strings in a specific JSON format.

```
{
  "ConnectionName": {
      "type": "SQLAzure",
      "value": "ConnectionString"
    },
```
''')
param connectionStringsJson_p object = {}

@description('Resource ID of the associated App Service plan.')
param farmId_p string = ''

@allowed([
  'AllAllowed'
  'Disabled'
  'FtpsOnly'
])
param ftpsState_v string = 'Disabled'

@description('Relative path of the health check probe. A valid path starts with "/".')
param healthCheckPath_par string = '/'

param httpLoggingEnabled_p bool = true

@description('HttpsOnly: configures a web site to accept only https requests. Issues redirect for http requests.')
param httpsOnly_p bool = true

@allowed([
  'linux'
  'windows'
])
param kind_p string = 'linux'

@allowed([
  'None'
  'System'
  'SystemUser'
  'User'
])
@description('Type of managed service identity.')
param identity_p string = 'None'

@description('Linux App Framework and version.')
param linuxFxVersion_p string = ''

param reserved_p bool = contains(kind_p, 'linux') ? true : false

@description('Azure Resource Manager ID of the Virtual network and subnet to be joined by Regional VNET Integration.')
param subnetId_p string = ''

@description('Virtual Network Route All enabled. This causes all outbound traffic to have Virtual Network Security Groups and User Defined Routes applied.')
param vnetRouteAllEnabled_p bool = !empty(subnetId_p) ? true : false

@description('Resource Id of the log analytics workspace which the data will be ingested to.')
param workspaceId_p string = ''

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param logRetention_p int = 30

@allowed([
  'true'
  'false'
])
param insights_p string = 'false'

@description('User identity ID.')
param userIdentityId_p string = ''

// vars
var appInsightsName_v = replace(appName_p, split(appName_p, '-')[0], 'appi')
var identity_v = {
  None: {
    type: 'None'
  }
  System: {
    type: 'SystemAssigned'
  }
  SytemUser: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userIdentityId_p}': {}
    }
  }
  User: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityId_p}': {}
    }
  }
}

var appSettingInsights_v = insights_p == 'true' ? {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsights_r.properties.InstrumentationKey
} : {}

// join application settings objects together
var unionAppSettings_v = union(appSettingsObject_p, appSettingInsights_v, {
    WEBSITE_HTTPLOGGING_RETENTION_DAYS: logRetention_p
  })

// deploy app insights
resource appInsights_r 'Microsoft.Insights/components@2020-02-02' = if (insights_p == 'true' && !empty(workspaceId_p)) {
  name: appInsightsName_v
  location: location_p
  tags: resourceTags_p
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: workspaceId_p
  }
}

// deploy app service
resource app_r 'Microsoft.Web/sites@2021-02-01' = {
  name: appName_p
  location: location_p
  tags: resourceTags_p
  kind: kind_p
  identity: identity_v[identity_p]
  properties: {
    httpsOnly: httpsOnly_p
    reserved: reserved_p
    serverFarmId: farmId_p ?? null
    siteConfig: {
      alwaysOn: alwaysOn_p
      ftpsState: ftpsState_v
      httpLoggingEnabled: httpLoggingEnabled_p
      vnetRouteAllEnabled: vnetRouteAllEnabled_p
    }
    virtualNetworkSubnetId: subnetId_p ?? null
  }

  resource web_r 'config' = {
    name: 'web'
    properties: {
      acrUseManagedIdentityCreds: ((contains(linuxFxVersion_p, environment().suffixes.acrLoginServer)) ? true : false)
      healthCheckPath: healthCheckPath_par
      ipSecurityRestrictions: accessRestrictions_v
      linuxFxVersion: ((contains(kind_p, 'linux') && !empty(linuxFxVersion_p)) ? linuxFxVersion_p : null)
    }
  }
}

// configure app service application settings
resource appsettings_r 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: app_r
  name: 'appsettings'
  properties: unionAppSettings_v
}

// configure app service connection strings
resource sqlConnections_r 'Microsoft.Web/sites/config@2021-02-01' = if (!(empty(connectionStringsJson_p))) {
  parent: app_r
  name: 'connectionstrings'
  properties: connectionStringsJson_p
}

// configure app service diags
resource appDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: app_r
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
        category: 'allMetrics'
        enabled: true
      }
    ]
  }
}

// ouputs
output api string = app_r.apiVersion
output id string = app_r.id
output name string = app_r.name
output principalId string = app_r.identity.principalId
output url string = app_r.properties.hostNames[0]

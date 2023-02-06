// File: functionApp.bicep
// 
// Creates a Function App
// 
// module functionApp_m 'modules/modular/functionApp.bicep' = {
//   scope: resourceGroup(appGroupName_v)
//   name: 'functionApp_m'
//   params: {
//     accessRestrictions_v: shr_v.env.envShort == 'dev' ? [] : accessRestrictions_v[shr_v.app.subnet]
//     funcName_p: funcName_v
//     appSettingsObject_p: appSettingsUnion_v
//     connectionStringsJson_p: connectionStrings_m.outputs.conStringsJson ?? {}
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     farmId_p: serverFarm_r.id
//     identity_p: 'System'
//     insights_p: 'false'
//     location_p: location_p
//     resourceTags_p: resourceTags_v
//     storageContent_p: {
//       api: storage_m.outputs.api
//       id: storage_m.outputs.id
//     }
//     subnetId_p: snetApp_r.id
//     workspaceId_p: logEndpoints_m.outputs.workspaceId
//   }
// }

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
param accessRestrictions_v array = []
param alwaysOn_p bool = contains(kind_p,'linux') ? true : false
param funcName_p string = 'func-${uniqueString(resourceGroup().id)}'
@secure()
param appSettingsObject_p object = {}
param connectionStringsJson_p object = {}
param farmId_p string = ''

@allowed([
  'None'
  'System'
  'SystemUser'
  'User'
])
@description('Type of managed service identity.')
param identity_p string = 'None'

@allowed([
  'AllAllowed'
  'Disabled'
  'FtpsOnly'
])
param ftpsState_v string = 'Disabled'
param httpLoggingEnabled_p bool = true
param httpsOnly_p bool = true

@allowed([
  'functionapp,linux'
  'functionapp'
])
param kind_p string = 'functionapp,linux'
param linuxFxVersion_p string = 'DOTNET|6.0'
param reserved_p bool = contains(kind_p, 'linux') ? true : false

@description('''
Object containing content share Storage Account details.
Will also be used for jobs storage if `storageJobs_p` is not defined.

```
{
  api: '2022-05-01'
  id:  '123'
}
''')
param storageContent_p object = {}

@description('''
Object containing jobs Storage Account details.
If undefined then the value of `storageContent_p` will be used.

```
{
  api: '2022-05-01'
  id:  '123'
}
''')
param storageJobs_p object = storageContent_p
param subnetId_p string = ''

@description('User identity ID.')
param userIdentityId_p string = ''
param vnetRouteAllEnabled_p bool = empty(subnetId_p) ? false : true
param workspaceId_p string = ''

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param logRetention_p int = 30

@allowed([
  'true'
  'false'
])
param insights_p string = 'false' //? may need to be a bool depending on where this value is retrieved from in your main template

// vars
var appInsightsName_v = replace(funcName_p, split(funcName_p, '-')[0], 'appi')
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

// content share storage account variables
var storageNameContent_v = contains(storageContent_p, 'id') ? last(split(storageContent_p.id, '/')) : ''
var storageStringContent_v = empty(storageNameContent_v) ? '' : 'DefaultEndpointsProtocol=https;AccountName=${storageNameContent_v};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageContent_p.id, storageContent_p.api).keys[0].value}'

var appSettingStorageContent_v = !empty(storageStringContent_v) ? {
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: storageStringContent_v
  WEBSITE_CONTENTSHARE: funcName_p
  WEBSITE_RUN_FROM_PACKAGE: 1 // TODO: not supported for linux consumption plans
} : {}

// jobs storage account variables
var storageNameJobs_v = contains(storageJobs_p, 'id') ? last(split(storageJobs_p.id, '/')) : ''
var storageStringJobs_v = empty(storageNameJobs_v) ? '' : 'DefaultEndpointsProtocol=https;AccountName=${storageNameJobs_v};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageJobs_p.id, storageJobs_p.api).keys[0].value}'

var appSettingStorageJobs_v = !empty(storageStringJobs_v) ? {
  AzureWebJobsStorage: storageStringJobs_v
} : {}

// app insights variables
var appSettingInsights_v = insights_p == 'true' ? {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsights_r.properties.InstrumentationKey
} : {}

// join application settings objects together
var appSettingsUnion_v = union(appSettingsObject_p, appSettingInsights_v, appSettingStorageContent_v, appSettingStorageJobs_v, {
    WEBSITE_HTTPLOGGING_RETENTION_DAYS: logRetention_p
  })

// existing resources

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

// deploy function app
resource func_r 'Microsoft.Web/sites@2021-02-01' = {
  name: funcName_p
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

  resource appsettings_r 'config' = {
    name: 'appsettings'
    properties: appSettingsUnion_v
  }

  resource connectionStrings_r 'config' = if (!(empty(connectionStringsJson_p))) {
    name: 'connectionstrings'
    properties: connectionStringsJson_p
  }

  resource web_r 'config' = {
    name: 'web'
    properties: {
      linuxFxVersion: ((contains(kind_p, 'linux') && !empty(linuxFxVersion_p)) ? linuxFxVersion_p : null)
      ipSecurityRestrictions: accessRestrictions_v
    }
  }
}

// configure app service diags
resource funcDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: func_r
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
output api string = func_r.apiVersion
output id string = func_r.id
output name string = func_r.name
output principalId string = func_r.identity.principalId
output type string = func_r.type
output url string = func_r.properties.hostNames[0]

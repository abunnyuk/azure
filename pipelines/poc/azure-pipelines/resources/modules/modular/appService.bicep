// File: appService.bicep

// global params
param location_par string = resourceGroup().location
param resourceTags_par object = {}

// resource params
param accessRestrictions_var array = []
param alwaysOn_par bool = true
param appName_par string = 'app-${uniqueString(resourceGroup().id)}'
param appSettingsObject_par object = {}
param connectionStringsJson_par object = {}
param farmId_par string = ''

@allowed([
  'AllAllowed'
  'Disabled'
  'FtpsOnly'
])
param ftpsState_var string = 'Disabled'
param httpLoggingEnabled_par bool = true
param httpsOnly_par bool = true

@allowed([
  'linux'
  'windows'
])
param kind_par string = 'linux'
param linuxFxVersion_par string = ''
param reserved_par bool = contains(kind_par, 'linux') ? true : false
param subnetId_par string = ''
param vnetRouteAllEnabled_par bool = !empty(subnetId_par) ? true : false
param workspaceId_par string = ''

// diags params
param eventHubAuthId_par string = ''
param eventHubName_par string = ''
param logRetention_par int = 30

@allowed([
  'true'
  'false'
])
param insights_par string = 'false'

// vars
var appInsightsName_var = replace(appName_par, split(appName_par, '-')[0], 'appi')
var unionAppSettings_var = union(appSettingsObject_par, {
  APPINSIGHTS_INSTRUMENTATIONKEY: ((insights_par == 'true') ? appInsights_res.properties.InstrumentationKey : null)
  WEBSITE_HTTPLOGGING_RETENTION_DAYS: logRetention_par
})

// deploy app insights
resource appInsights_res 'Microsoft.Insights/components@2020-02-02' = if (insights_par == 'true' && !empty(workspaceId_par)) {
  name: appInsightsName_var
  location: location_par
  tags: resourceTags_par
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: workspaceId_par
  }
}

// deploy app service
resource app_res 'Microsoft.Web/sites@2021-02-01' = {
  name: appName_par
  location: location_par
  tags: resourceTags_par
  kind: kind_par
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: httpsOnly_par
    reserved: reserved_par
    serverFarmId: farmId_par ?? null
    siteConfig: {
      alwaysOn: alwaysOn_par
      ftpsState: ftpsState_var
      httpLoggingEnabled: httpLoggingEnabled_par
      vnetRouteAllEnabled: vnetRouteAllEnabled_par
    }
    virtualNetworkSubnetId: subnetId_par ?? null
  }

  // resource logs_res 'config' = {
  //   name: 'logs'
  //   properties: {
  //     httpLogs: {
  //       fileSystem: {
  //         retentionInMb: 35
  //         enabled: true
  //       }
  //     }
  //   }
  // }

  resource web_res 'config' = {
    name: 'web'
    properties: {
      acrUseManagedIdentityCreds: ((contains(linuxFxVersion_par, environment().suffixes.acrLoginServer)) ? true : false)
      linuxFxVersion: ((contains(kind_par, 'linux') && !empty(linuxFxVersion_par)) ? linuxFxVersion_par : null)
      ipSecurityRestrictions: accessRestrictions_var
    }
  }
}

// configure app service application settings
resource appsettings_res 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: app_res
  name: 'appsettings'
  properties: unionAppSettings_var
}

// configure app service connection strings
resource sqlConnections_res 'Microsoft.Web/sites/config@2021-02-01' = if (!(empty(connectionStringsJson_par))) {
  parent: app_res
  name: 'connectionstrings'
  properties: connectionStringsJson_par
}

// configure app service diags
resource appDiags_res 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_par) && !empty(eventHubAuthId_par)) {
  scope: app_res
  name: 'default'
  properties: {
    eventHubName: eventHubName_par
    eventHubAuthorizationRuleId: eventHubAuthId_par
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
output api string = app_res.apiVersion
output id string = app_res.id
output name string = app_res.name
output principalId string = app_res.identity.principalId
output url string = app_res.properties.hostNames[0]

// testing
output conStrings object = connectionStringsJson_par

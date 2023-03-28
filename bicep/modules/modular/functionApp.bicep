// File: functionApp.bicep
// Author: Bunny Davies
// 
// Change log:
// - Initial release
// - Updated to use ~4 runtime
// - Use Application Insights instrumenation key instead of connection string
// - Required use of Storage Account connection string from a Key Vault secret
// - Added runtime application settings
// - Added example usage
// 
// Examples:
// 
// module functionApp_m 'modules/modular/functionApp.bicep' = {
//   scope: group_r
//   name: 'functionApp_m'
//   params: {
//     accessRestrictions_v: [
//       {
//         vnetSubnetResourceId: snetGwAgw_r.id // application gateway subnet id
//         action: 'Allow'
//         priority: 200
//         name: 'allow-${subnetNameGwAgw_v}' // rule name contains application gateway subnet name
//       }
//     ]
//     appSettingsObject_p: {
//       FOO: 'bar'
//     }
//     connectionStrings_p: {
//       DatabaseConnection: {
//         type: 'SQLAzure'
//         value: 'Server=tcp:asqlserver${environment().suffixes.sqlServerHostname};Database=Worker;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=Active Directory Managed Identity;'
//       }
//     }
//     eventHubAuthId_p: logEndpoints_m.outputs.eventHubAuthIdId
//     eventHubName_p: logEndpoints_m.outputs.eventHubName
//     farmId_p: serverFarm_r.id
//     funcName_p: funcName_v
//     identity_p: 'System'
//     location_p: location_p
//     resourceTags_p: resourceTags_v
//     storageNameJobs_p: storageName_v
//     subnetId_p: snetApp_r.id
//     vaultName_p: vaultName_v
//   }
// }

// params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

@description('Array of access restrictions to apply to the site.')
param accessRestrictions_p array = []

@description('Enable Always On.')
param alwaysOn_p bool = contains(kind_p, 'linux') ? true : false

@description('Name of the Function App.')
param funcName_p string = 'func-${uniqueString(resourceGroup().id)}'
@secure()

@description('Application Settings in the format of `key: value`.')
param appSettingsObject_p object = {}
param connectionStrings_p object = {}

@description('Resource ID of the associated App Service plan')
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

@description('Enable HTTP logging')
param httpLoggingEnabled_p bool = true

@description('Configures a web site to accept only https requests. Issues redirect for http requests')
param httpsOnly_p bool = true

@allowed([
  'functionapp,linux'
  'functionapp'
])
param kind_p string = 'functionapp,linux'
param linuxFxVersion_p string = 'DOTNET|6.0'
param reserved_p bool = contains(kind_p, 'linux') ? true : false

@allowed([
  '~4'
  '~1'
])
@description('Runtime version.')
param runtimeVersion_p string = '~4'

@allowed([
  'dotnet'
  'dotnet-isolated'
  'java'
  'node'
  'powershell'
  'python'
])
@description('Runtime version.')
param runtimeWorker_p string

@description('''
Name of the Key Vault secret that contains the content share Storage Account connection string secret.
Defaults to the same value as `storageNameContent_p`.
''')
param secretNameContent_p string = storageNameContent_p

@description('''
Name of the Key Vault secret that contains the Storage Account connection string secret.
Defaults to the same value as `storageNameJobs_p`.
''')
param secretNameJobs_p string = storageNameJobs_p

@description('''
Name of the Storage Account where the web jobs will be stored.
Defaults to the same value as `storageNameJobs_p`.
''')
param storageNameContent_p string = storageNameJobs_p

@description('Name of the Storage Account where the web jobs will be stored.')
param storageNameJobs_p string = ''

@description('Resource ID of the subnet to be used for VNET Integration.')
param subnetId_p string = ''

@description('Store the functions within a content share in a Storage Account')
param useContentShare_p bool = false

@description('User identity ID.')
param userIdentityId_p string = ''

@description('''
Name of the Key Vault that contains the Storage Account connection string secret.

Storage Account connection strings should never be bare and always stored as a Key Vault secret.
''')
param vaultName_p string = ''

@description('This causes all outbound traffic to have Virtual Network Security Groups and User Defined Routes applied.')
param vnetRouteAllEnabled_p bool = empty(subnetId_p) ? false : true

@description('Resource ID of the Log Workspace used for storing Application Insights data.')
param workspaceId_p string = ''

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param logRetention_p int = 30

@allowed([
  'true'
  'false'
])
@description('Enable and deploy Application Insights.')
param insights_p string = 'false'

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

// vars - application settings
var appSettingInsights_v = insights_p == 'true' && !empty(workspaceId_p) ? {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsights_r.properties.InstrumentationKey
} : {}

var appSettingStorageJobs_v = !empty(storageNameJobs_p) ? {
  AzureWebJobsStorage: '@Microsoft.KeyVault(VaultName=${vaultName_p};SecretName=${secretNameJobs_p})'
} : {}

var appSettingStorageContent_v = useContentShare_p ? {
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${vaultName_p};SecretName=${secretNameContent_p})'
  WEBSITE_CONTENTOVERVNET: empty(subnetId_p) ? 0 : 1
  WEBSITE_CONTENTSHARE: funcName_p
  WEBSITES_ENABLE_APP_SERVICE_STORAGE: true
  WEBSITE_RUN_FROM_PACKAGE: 1 // TODO: not supported for linux consumption plans
} : {}

// join application settings objects together and add final settings
var appSettingsUnion_v = union(appSettingsObject_p, appSettingInsights_v, appSettingStorageContent_v, appSettingStorageJobs_v, {
    FUNCTIONS_EXTENSION_VERSION: runtimeVersion_p
    FUNCTIONS_WORKER_RUNTIME: runtimeWorker_p
    WEBSITE_HTTPLOGGING_RETENTION_DAYS: logRetention_p
  })

// resources

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

module fileShare_m 'storageFileShare.bicep' = if (useContentShare_p) {
  name: 'fileShare_m'
  params: {
    fileShareName_p: funcName_p
    storageAccountName_p: storageNameContent_p
  }
}

// deploy function app
resource func_r 'Microsoft.Web/sites@2022-03-01' = {
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
      ipSecurityRestrictions: accessRestrictions_p
      linuxFxVersion: ((contains(kind_p, 'linux') && !empty(linuxFxVersion_p)) ? linuxFxVersion_p : null)
      vnetRouteAllEnabled: vnetRouteAllEnabled_p
    }
    virtualNetworkSubnetId: subnetId_p ?? null
  }
}

module assignRoles_m 'vaultSecrets.bicep' = if (!empty(vaultName_p)) {
  name: 'assignRoles_m'
  params: {
    principalId_p: func_r.identity.principalId
    roleDefinitionIds_p: [
      '4633458b-17de-408a-b874-0445c86b69e6'
    ]
    vaultName_p: vaultName_p
  }
}

resource siteConfig_appsettings_r 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: func_r
  name: 'appsettings'
  dependsOn: [
    assignRoles_m
  ]
  properties: appSettingsUnion_v
}

resource siteConfig_connectionstrings_r 'Microsoft.Web/sites/config@2022-03-01' = if (!empty(connectionStrings_p)) {
  parent: func_r
  name: 'connectionstrings'
  dependsOn: [
    assignRoles_m
  ]
  properties: connectionStrings_p
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

// modules

// ouputs
output api string = func_r.apiVersion
output id string = func_r.id
output name string = func_r.name
output principalId string = func_r.identity.principalId
output type string = func_r.type
output url string = func_r.properties.hostNames[0]

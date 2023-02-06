// File: datadogModules.bicep
// 0.1 - initial release, uses other modules

// DataDog module parameters
param appName_p string = 'func-datadog-${uniqueString(resourceGroup().id)}'
param namespaceName_p string
param planName_p string = 'plan-datadog-${uniqueString(resourceGroup().id)}'
param resourceTags_p object = {}
param storageName_p string

/*
Pass datadog function from grabbing the function code:
$DDUri = 'https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/master/azure/activity_logs_monitoring/index.js'
$Code = (New-Object System.Net.WebClient).DownloadString($DDUri)
*/

@description('DataDog function code')
param functionCode_p string = ''

@description('DataDog API key')
@secure()
param apiKey_p string = ''

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = 'evh-${uniqueString(resourceGroup().id)}'
param workspaceId_p string = 'log-${uniqueString(resourceGroup().id)}'

var storageConnecstringString_v = 'DefaultEndpointsProtocol=https;AccountName=${storage_r.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage_r.id, storage_r.apiVersion).keys[0].value}'
var namespaceConnectionString_v = listkeys(eventHubAuthId_p, namespace_r.apiVersion).primaryConnectionString

var appSettings_v = {
  AzureWebJobsStorage: storageConnecstringString_v
  DD_API_KEY: apiKey_p
  DD_SITE: 'datadoghq.eu'
  FUNCTIONS_WORKER_RUNTIME: 'node'
  NAMESPACE_CONNECTIONSTRING: namespaceConnectionString_v
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: storageConnecstringString_v
  WEBSITE_CONTENTSHARE: appName_p
  WEBSITE_NODE_DEFAULT_VERSION: '~12'
}

// existing resources
resource namespace_r 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: namespaceName_p
}

resource storage_r 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageName_p
}

// creat the event hub
resource eventHub_r 'Microsoft.EventHub/namespaces/eventhubs@2021-06-01-preview' = if (!empty(eventHubName_p)) {
  parent: namespace_r
  name: eventHubName_p
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
    status: 'Active'
  }
}

// now that the event hub has been created, configure diags for the namespace
resource namespaceDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: namespace_r
  dependsOn:[
    eventHub_r
  ]
  name: 'default'
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthId_p
    eventHubName: eventHubName_p
    logs: [
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

module plan_m 'appPlan.bicep' = {
  name: planName_p
  params: {
    eventHubAuthId_p: eventHubAuthId_p
    eventHubName_p: eventHubName_p
    kind_p: 'functionapp'
    planName_p: planName_p
    resourceTags_p: resourceTags_p
    skuName_p: 'Y1'
  }
}

module functionApp_m 'appService.bicep' = {
  name: appName_p
  params: {
    appName_p: appName_p
    appSettingsObject_p: appSettings_v
    eventHubAuthId_p: eventHubAuthId_p
    eventHubName_p: eventHubName_p
    farmId_p: plan_m.outputs.id
    kind_p: 'functionapp'
    resourceTags_p: resourceTags_p
    workspaceId_p: workspaceId_p
  }
}

resource functionDeploy_r 'Microsoft.Web/sites/functions@2021-02-01' = {
  dependsOn: [
    functionApp_m
  ]
  name: '${appName_p}/eventHubMessages'
  properties: {
    config: {
      bindings: [
        {
          cardinality: 'many'
          connection: 'NAMESPACE_CONNECTIONSTRING'
          consumerGroup: '$Default'
          dataType: ''
          direction: 'in'
          eventHubName: eventHubName_p
          name: 'eventHubMessages'
          type: 'eventHubTrigger'
        }
      ]
      disabled: false
    }
    files: {
      'index.js': functionCode_p
    }
  }
}

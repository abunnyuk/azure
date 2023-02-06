// DataDog module parameters
param defaultTags_p object
param eventHubNamespaceName_p string
param eventHubName_p string
param dataDogAppServicePlanName_p string
param dataDogFunctionAppName_p string
param dataDogEventHubFunctionName_p string
param dataDogFunctionStorageName_p string
/*
Pass datadog function from grabbing the function code:
$DDUri = https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/master/azure/activity_logs_monitoring/index.js
$Code = (New-Object System.Net.WebClient).DownloadString($DDUri)
*/
@description('DataDog function code')
param dataDogFunctionCode_p string
@description('DataDog API key')
@secure()
param dataDogApiKey_p string

var eventHubConnectionString_v = listkeys(dataDogEventHubAuthorization_r.id, dataDogEventHubAuthorization_r.apiVersion).primaryConnectionString
var functionStorageConnnectionString_v = 'DefaultEndpointsProtocol=https;AccountName=${dataDogFunctionStorage_r.name};AccountKey=${listkeys(dataDogFunctionStorage_r.id, '2018-11-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage};'
var dataDogAppSettings_v = [
    {
      name: 'FUNCTIONS_EXTENSION_VERSION'
      value: '~3'
    }
    {
      name: 'DD_API_KEY'
      value: dataDogApiKey_p
    }
    {
      name: 'DD_SITE'
      value: 'datadoghq.eu'
    }
    {
      name: 'AzureWebJobsStorage'
      value: functionStorageConnnectionString_v
    }
    {
      name: 'FUNCTIONS_WORKER_RUNTIME'
      value: 'node'
    }
    {
      name: 'Datadog-${eventHubNamespaceName_p}-AccessKey'
      value: eventHubConnectionString_v
    }
    {
      name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
      value: functionStorageConnnectionString_v
    }
    {
      name: 'WEBSITE_CONTENTSHARE'
      value: dataDogFunctionAppName_p
    }
    {
      name: 'WEBSITE_NODE_DEFAULT_VERSION'
      value: '~12'
    }
]
resource dataDogEventHubNamespace_r 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName_p
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
}

resource dataDogEventHubAuthorization_r 'Microsoft.EventHub/namespaces/AuthorizationRules@2015-08-01' = {
  parent: dataDogEventHubNamespace_r
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

resource dataDogEventHub_r 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: dataDogEventHubNamespace_r
  name: eventHubName_p
}

resource dataDogAppServicePlan_r 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: dataDogAppServicePlanName_p
  location: resourceGroup().location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
}

resource dataDogFunctionApp_r 'Microsoft.Web/sites@2021-02-01' = {
  name: dataDogFunctionAppName_p
  location: resourceGroup().location
  tags: defaultTags_p
  kind: 'functionapp'
  properties: {
    serverFarmId: dataDogAppServicePlan_r.id
    siteConfig: {
      appSettings: dataDogAppSettings_v
    }
  }
}

resource dataDogFunctionStorage_r 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: dataDogFunctionStorageName_p
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource dataDogFunctionDeploy_r 'Microsoft.Web/sites/functions@2021-02-01' = {
  parent: dataDogFunctionApp_r
  name: dataDogEventHubFunctionName_p
  properties: {
    config: {
      bindings: [
        {
          name: 'eventHubMessages'
          type: 'eventHubTrigger'
          direction: 'in'
          eventHubName: dataDogEventHub_r.name
          connection: eventHubConnectionString_v
          cardinality: 'many'
          dataType: ''
          consumerGroup: '$Default'
        }
      ]
      disabled: false
    }
    files: {
      'index.js': dataDogFunctionCode_p
    }
  }
}

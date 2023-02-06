// File: storage.bicep
// 0.1 - initial release

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// storage params
param accountName_p string = 'store${uniqueString(resourceGroup().id)}'
param tableName_p string = ''

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// existing resources
resource storageAccount_r 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: accountName_p
}

// deploy storage account tables
resource tableService_r 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageAccount_r
  name: 'default'

  resource table_r 'tables' = {
    name: tableName_p
  }
}

resource tableDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: tableService_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// outputs
output api string = storageAccount_r.apiVersion
output id string = storageAccount_r.id
output name string = storageAccount_r.name
output url string = '${storageAccount_r.name}${environment().suffixes.storage}'

// File: storageBlob.bicep

// storage params
param blobName_p string = 'blob${uniqueString(resourceGroup().id)}'

@description('Name of the existing storage account.')
param storageAccountName_p string = 'store${uniqueString(resourceGroup().id)}'

@allowed([
  'Blob'
  'Container'
  'None'
])
@description('Specifies whether data in the container may be accessed publicly and the level of access.')
param publicAccess_p string = 'None'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// deploy blob services
resource blobService_r 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name: '${storageAccountName_p}/default'
}

resource blobContainer_r 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: blobService_r
  name: blobName_p
  properties: {
    publicAccess: publicAccess_p
  }
}

resource blobDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: blobService_r
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
output api string = blobContainer_r.apiVersion
output id string = blobContainer_r.id
output name string = blobContainer_r.name
output type string = blobContainer_r.type
output url string = '${storageAccountName_p}${environment().suffixes.storage}'

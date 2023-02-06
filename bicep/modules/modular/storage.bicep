// File: storage.bicep
// 0.1 - initial release

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// storage params
param accountName_p string = 'store${uniqueString(resourceGroup().id)}'

@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
param kind_p string = 'StorageV2'

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param skuName_p string = 'Standard_ZRS'
param virtualNetworkRules_v array = []

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// deploy storage account
resource storageAccount_r 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: accountName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
  }
  kind: kind_p
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: ((!empty(virtualNetworkRules_v)) ? 'Deny' : 'Allow')
      bypass: 'AzureServices'
      virtualNetworkRules: virtualNetworkRules_v
    }
    supportsHttpsTrafficOnly: true
  }
}

// configure storage account diags
resource appServiceAppDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: storageAccount_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
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

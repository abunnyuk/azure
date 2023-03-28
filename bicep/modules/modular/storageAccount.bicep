// File: storage.bicep
// Author: Bunny Davies
// 
// Change log:
// - Initial release
// - Added default address
// - Added example usage
// - Added endpoint outputs as per https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview#standard-endpoints
// - Added option to save connection string as a key vault secret
// 
// Creates a Storage Account
// 
// module storage_m 'modules/modular/storageAccount.bicep' = {
//   scope: group_r
//   name: 'storage_m'accountName_p
//   params: {
//     accountName_p: storageName_v
//     allowedIpAddresses_p: [
//       '99.99.99.99'
//     ]
//     allowedSubnets_p: [
//       vnetSubnet_m.outputs.id
//     ]
//     eventHubAuthId_p: eventHubAuthIdId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     resourceTags_p: resourceTags_v
//   }
// }

// params - global
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// params
param accountName_p string = 'store${uniqueString(resourceGroup().id)}'

@description('Allow or disallow public access to all blobs or containers in the storage account.')
param allowBlobPublicAccess bool = false

param allowedIpAddresses_p array = []
param allowedSubnets_p array = []

@allowed([
  'AzureServices'
  'Logging'
  'Metrics'
  'None'
])
@description('Specifies whether traffic is bypassed for Logging/Metrics/AzureServices.')
param bypass_p string = 'None'

@allowed([
  'Allow'
  'Deny'
])
@description('Specifies the default action of allow or deny when no other rules match.')
param defaultAction_p string = 'Deny'

@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
param kind_p string = 'StorageV2'

@description('''
Name of the Key Vault secret that will contain the Storage Account connection string
Default value set to `accountName_p`.
''')
param secretName_p string = accountName_p

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

@description('Name of the Key Vault where the connection string should be stored as a secret')
param vaultName_p string = ''

// vars
var allowedIpsArray_v = [for ip in allowedIpAddresses_p: {
  value: ip
  action: 'Allow'
}]

var allowedSubnetsArray_v = [for subnet in allowedSubnets_p: {
  id: subnet
  action: 'Allow'
}]

var storageConnecstringString_v = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount_r.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount_r.listKeys().keys[0].value}'

// resources
resource storageAccount_r 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: accountName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: skuName_p
  }
  kind: kind_p
  properties: {
    allowBlobPublicAccess: allowBlobPublicAccess
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: defaultAction_p
      bypass: bypass_p
      ipRules: allowedIpsArray_v
      virtualNetworkRules: allowedSubnetsArray_v
    }
    supportsHttpsTrafficOnly: true
  }
}

resource storageAccountDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
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

resource secret_r 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = if (!empty(vaultName_p)) {
  name: '${vaultName_p}/${secretName_p}'
  properties: {
    value: storageConnecstringString_v
  }
}

// outputs
output api string = storageAccount_r.apiVersion
output id string = storageAccount_r.id
output name string = storageAccount_r.name
output type string = storageAccount_r.type

output endpointBlob string = 'https://${storageAccount_r.name}.blob.${environment().suffixes.storage}'
output endpointDataLake string = 'https://${storageAccount_r.name}.dfs.${environment().suffixes.storage}'
output endpointFile string = 'https://${storageAccount_r.name}.file.${environment().suffixes.storage}'
output endpointQueue string = 'https://${storageAccount_r.name}.queue.${environment().suffixes.storage}'
output endpointTable string = 'https://${storageAccount_r.name}.table.${environment().suffixes.storage}'
output endpointWeb string = 'https://${storageAccount_r.name}.web.core.${environment().suffixes.storage}'

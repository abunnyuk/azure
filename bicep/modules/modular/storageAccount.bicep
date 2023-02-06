// File: storage.bicep
// 
// Change log:
// - Initial release
// - Added default address
// - Added example usage
// - Removed unnecessary url output
// - Added endpoint outputs as per https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview#standard-endpoints
// 
// Creates a Storage Account
// 
// module storage_m 'modules/modular/storageAccount.bicep' = {
//   scope: group_r
//   name: 'storage_m'
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

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// storage params
@allowed([
  'Cool'
  'Hot'
])
@description('Required for storage accounts where kind = BlobStorage. The access tier used for billing.')
param accessTier_p string = 'Hot'

@description('The resource name')
param accountName_p string = 'store${uniqueString(resourceGroup().id)}'

@description('Allow or disallow public access to all blobs or containers in the storage account.')
param allowBlobPublicAccess bool = false

@description('Sets the IP ACL rules')
param allowedIpAddresses_p array = []

@description('''
Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key.
If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD).
''')
param allowSharedKeyAccess_p bool = true

@description('Sets the virtual network rules')
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

@allowed([
  'Disabled'
  'Enabled'
])
@description('Network rule set')
param publicNetworkAccess_p string = 'Disabled'

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

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

var allowedIpsArray_v = [for ip in allowedIpAddresses_p: {
  value: ip
  action: 'Allow'
}]

var allowedSubnetsArray_v = [for subnet in allowedSubnets_p: {
  id: subnet
  action: 'Allow'
}]

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
    accessTier: accessTier_p
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess_p
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: publicNetworkAccess_p
    networkAcls: {
      defaultAction: defaultAction_p
      bypass: bypass_p
      ipRules: allowedIpsArray_v
      virtualNetworkRules: allowedSubnetsArray_v
    }
    supportsHttpsTrafficOnly: true
  }
}

// configure storage account diags
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

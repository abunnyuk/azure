// File: storageFileShare.bicep
// 0.1 - initial release

// params
@allowed([
  'Cool'
  'Hot'
  'Premium'
  'TransactionOptimized'
])
param accessTier_p string = 'TransactionOptimized'

@allowed([
  'NFS'
  'SMB'
])
param enabledProtocols_p string = 'SMB'

@description('Name of the existing storage account.')
param storageAccountName_p string = 'store${uniqueString(resourceGroup().id)}'

@description('Name of the file share.')
param fileShareName_p string

@allowed([
  'AllSquash'
  'NoRootSquash'
  'RootSquash'
])
param rootSquash_p string = 'NoRootSquash'

// create the file service
resource fileService_r 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' = {
  name: '${storageAccountName_p}/default'
}

// create the file share
resource fileShare_r 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: fileShareName_p
  parent: fileService_r
  properties: {
    accessTier: accessTier_p
    enabledProtocols: enabledProtocols_p
    rootSquash: enabledProtocols_p == 'NFS' ? rootSquash_p : null
  }
}

// outputs
output api string = fileShare_r.apiVersion
output id string = fileShare_r.id
output name string = fileShare_r.name
output type string = fileShare_r.type

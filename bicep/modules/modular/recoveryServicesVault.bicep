// File: recoveryServicesVault.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
//
// Creates a Recovery Services Vault
//
// Note that environment suffixes have inconsistent leading periods
// https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-deployment#example-1
//
// var privateDnsZones_v = [
//   'privatelink.file.${environment().suffixes.storage}'
//   'privatelink${environment().suffixes.sqlServerHostname}'
// ]
//
// module privateDnsZones_m 'modules/modular/privateDnsZone.bicep' = [for zone in privateDnsZones_v: {
//   scope: group_r
//   name: zone
//   params: {
//     location_p: 'global'
//     resourceTags_p: resourceTags_p
//     vnetIdDeployed_p: vnetId_p
//     zoneName_p: zone
//   }
// }]

// global params/vars
param eventHubAuthId_p string = ''
param eventHubName_p string = ''
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params/vars
@description('The Recovery Services Vault name.')
param vaultName_p string = 'rsv-${uniqueString(resourceGroup().id)}'

// resources
resource recoveryVault_r 'Microsoft.RecoveryServices/vaults@2022-04-01' = {
  name: vaultName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties:{
    
  }
}

resource recoveryVaultDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: recoveryVault_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Health'
        enabled: true
      }
    ]
  }
}

// outputs
output api string = recoveryVault_r.apiVersion
output id string = recoveryVault_r.id
output name string = recoveryVault_r.name
output type string = recoveryVault_r.type

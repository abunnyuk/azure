// File: vault.bicep
// Author: Bunny Davies
// 
// Change log:
// - Initial release
// - Added example usage
// - Added option for creating private endpoint
// 
// Creates a Key Vault with optional Private Endpoint
// 
// @secure()
// param vaultAdminId_p string

// module vault_m 'modules/modular/vault.bicep' = {
//   name: 'vault_m'
//   params: {
//     adminId_p: vaultAdminId_p
//     dnsZoneId_p: privateDnsZoneVault_m.outputs.id
//     enabledForTemplateDeployment_p: true
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     resourceTags_p: resourceTags_p
//     subnetId_p: subnets_m[0].outputs.id
//     vaultName_p: vaultName_v
//   }
// }

// global params/vars
@description('The resource Id for the event hub authorization rule.')
param eventHubAuthId_p string = ''

@description('The name of the event hub.')
param eventHubName_p string = ''

@description('The supported Azure location where the resources should be created.')
param location_p string = resourceGroup().location

@description('The tags that will be assigned to the resources.')
param resourceTags_p object = {}

// resource params/vars
param accessPolicies_p array = []

@secure()
param adminId_p string = ''

@description('''
The list of IP address rules.
```
[
  1.1.1.1
  2.2.2.2
]
```
''')
param allowedIpAddresses_p array = []

@description('''
The list allowed subnets IDs.
```
[
  id1
  id2
]
```
''')
param allowedSubnets_p array = []

@allowed([
  'AzureServices'
  'None'
])
@description('Tells what traffic can bypass network rules.')
param bypass_p string = (enabledForDeployment_p || enabledForTemplateDeployment_p) ? 'AzureServices' : 'None'

@allowed([
  'Allow'
  'Deny'
])
@description('The default action when no rule from ipRules and from virtualNetworkRules match. This is only used after the bypass property has been evaluated.')
param defaultAction_p string = 'Deny'

@description('The resource id of the private dns zone.')
param dnsZoneId_p string = ''

@description('Property to specify whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
param enabledForDeployment_p bool = false

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment_p bool = false

// @description('''
// Property specifying whether protection against purge is enabled for this vault. Setting this property to true activates protection against purge for this vault and its content - only the Key Vault service may initiate a hard, irrecoverable deletion.

// The setting is effective only if soft delete is also enabled. Enabling this functionality is irreversible - that is, the property does not accept false as its value.
// ''')
// param enablePurgeProtection_p bool = enabledForDeployment_p  //TODO: refactor purge protection as false value is not accepted

@description('''
Property that controls how data actions are authorized. When true, the key vault will use Role Based Access Control (RBAC) for authorization of data actions, and the access policies specified in vault properties will be ignored.

When false, the key vault will use the access policies specified in vault properties, and any policy stored on Azure Resource Manager will be ignored.

If null or not specified, the vault is created with the default value of false. Note that management actions are always authorized with RBAC.
''')
param enableRbacAuthorization_p bool = empty(adminId_p) ? true : false

@description('''

''')
param enableSoftDelete_p bool = softDeleteRetentionInDays_p > 0 ? true : false

@allowed([
  'premium'
  'standard'
])
@description('SKU name to specify whether the key vault is a standard vault or a premium vault.')
param skuName_p string = 'standard'

@description('softDelete data retention days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays_p int = 90

@description('The ID of the existing subnet from which the private IP will be allocated.')
param subnetId_p string = ''

@description('The resource name')
param vaultName_p string = 'kv-${uniqueString(resourceGroup().id)}'

var allowedIpsArray_v = [for ip in allowedIpAddresses_p: {
  value: ip
}]

var allowedSubnetsArray_v = [for subnet in allowedSubnets_p: {
  id: subnet
}]

// resources
resource vault_r 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: vaultName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    accessPolicies: accessPolicies_p
    enabledForDeployment: enabledForDeployment_p
    enabledForTemplateDeployment: enabledForTemplateDeployment_p
    // enablePurgeProtection: enablePurgeProtection_p   //TODO: refactor purge protection as false value is not accepted
    enableRbacAuthorization: enableRbacAuthorization_p
    enableSoftDelete: enableSoftDelete_p
    networkAcls: {
      bypass: bypass_p
      defaultAction: defaultAction_p
      ipRules: allowedIpsArray_v
      virtualNetworkRules: allowedSubnetsArray_v
    }
    sku: {
      family: 'A'
      name: skuName_p
    }
    softDeleteRetentionInDays: softDeleteRetentionInDays_p
    tenantId: subscription().tenantId
  }

  resource accessPolicies 'accessPolicies' = if (!empty(adminId_p)) {
    name: 'add'
    properties: {
      accessPolicies: [
        {
          tenantId: subscription().tenantId
          permissions: {
            certificates: [
              'all'
            ]
            keys: [
              'all'
            ]
            secrets: [
              'all'
            ]
          }
          objectId: adminId_p
        }
      ]
    }
  }
}

resource vaultDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: vault_r
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
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// optional private endpoint
module privateEndpoint_m 'privateEndpoint.bicep' = if (!empty(dnsZoneId_p) && !empty(subnetId_p)) {
  name: 'privateEndpoint_m'
  params: {
    location_p: location_p
    dnsZoneId_p: dnsZoneId_p
    groupIds_p: [
      'vault'
    ]
    resourceTags_p: resourceTags_p
    serviceId_p: vault_r.id
    subnetId_p: subnetId_p
  }
}

// outputs
output api string = vault_r.apiVersion
output id string = vault_r.id
output name string = vault_r.name
output type string = vault_r.type

// File: vaultSecrets.bicep
// Author: Bunny Davies
// 
// Change log:
// - Initial release
// - Added example usage
// - Added ability to create key vault secrets user assignment
// 
// @secure()
// param localAdminPass_p string

// module secrets_m 'modules/modular/vaultSecrets.bicep' = {
//   scope: group_r
//   name: 'secrets_m'
//   params: {
//     vaultName_p: vault_m.outputs.name
//     secrets: {
//       'pass-localadmin': localAdminPass_p
//     }
//   }
// }

// global params

// resource specific params
@description('The principal ID to be assigned roles to the Key Vault.')
param principalId_p string = ''

@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
@description('''
The principal type of the assigned principal ID.
Default set to `ServicePrincipal`. 
''')
param principalType_p string = 'ServicePrincipal'

@description('''
Array of Key Vault related role definition IDs to be assigned to the principal ID.
https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
''')
param roleDefinitionIds_p array = []

param vaultName_p string

@description('''
Objecting containing Key/value list of secrets
{
  secret1: shhhh
  secret2: shhhhmore
}

''')
@secure()
param secrets_p object = {}

// resources
resource vault_r 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: vaultName_p
}

resource assignRoleSecretsUser_m 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds_p: if (!empty(roleDefinitionIds_p)) {
  scope: vault_r
  name: guid(subscription().id, principalId_p, resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId))
  properties: {
    principalId: principalId_p
    principalType: principalType_p
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}]

resource vaultSecrets_r 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = [for secret in items(secrets_p): if (!empty(secrets_p)) {
  parent: vault_r
  name: secret.key
  properties: {
    value: secret.value
  }
}]

// outputs

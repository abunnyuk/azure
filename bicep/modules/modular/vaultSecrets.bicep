// File: vaultSecrets.bicep
// 
// Change log:
// - Initial release
// - Added example usage
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
param vaultName_p string

@description('''
Objecting containing Key/value list of secrets
{
  foo: bar
  my: secret
}

''')
@secure()
param secrets object

// resources
resource vault_r 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: vaultName_p
}

resource vaultSecrets_r 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = [for secret in items(secrets): if (!empty(secrets)) {
  parent: vault_r
  name: secret.key
  properties: {
    value: secret.value
  }
}]

// outputs

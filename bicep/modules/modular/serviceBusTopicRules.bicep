// File: serviceBusQueue.bicep
// Author: Bunny Davies & Jan Widlinski

// params
@description('''
Array containing authorisation rules consisting of policy names and rights.

```
[
  {
    name: 'function1'
    rights: [
      'Listen'
      'Send'
    ]
  }
  {
    name: 'app2'
    rights: [
      'Send'
    ]
  }
]
```
''')
param authRules_p array = []

@description('''
There is a known issue where connection strings with ;EntityPath=queuename on the end will cause a Function App to fail.

Setting to true will remove the EntityPath parameter from the connection string before the secret to the Key Vault.

https://github.com/Azure/azure-functions-servicebus-extension/issues/25
''')
param entityFix_p bool = false

@description('Name of the Service Bus Queue')
param topicName_p string

@description('Name of the Service Bus')
param serviceBusName_p string

@description('Resource ID of Key Vault to write the auth rule connection string to.')
param vaultId_p string = ''

var vaultName_v = last(split(vaultId_p, '/'))
var vaultGroup_v = split(vaultId_p, '/')[4]

// existing resources
resource serviceBus_r 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName_p
}

// resources
resource serviceBusTopic_r 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' existing = {
  parent: serviceBus_r
  name: topicName_p
}

resource authRules_r 'Microsoft.ServiceBus/namespaces/topics/authorizationRules@2022-01-01-preview' = [for rule in authRules_p: {
  parent: serviceBusTopic_r
  name: rule.name
  properties: {
    rights: rule.rights
  }
}]

module secret_m 'vaultSecrets.bicep' = [for (rule, i) in authRules_p: if (!empty(vaultId_p) && !empty(authRules_p)) {
  scope: resourceGroup(vaultGroup_v)
  name: 'secret_m-${rule.name}'
  params: {
    secrets: {
      '${topicName_p}-${rule.name}': entityFix_p ? replace(listKeys(authRules_r[i].id, authRules_r[i].apiVersion).primaryConnectionString, ';EntityPath=${topicName_p}', '') : listKeys(authRules_r[i].id, authRules_r[i].apiVersion).primaryConnectionString
    }
    vaultName_p: vaultName_v
  }
}]

// outputs
output api string = serviceBusTopic_r.apiVersion
output id string = serviceBusTopic_r.id
output name string = serviceBusTopic_r.name
output type string = serviceBusTopic_r.type

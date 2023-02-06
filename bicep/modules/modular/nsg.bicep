// File: nsg.bicep
//
// Creates a Network Security Group
//
// Note that recreating an NSG will usually wipe its rules
//
//
// @description('''
// Should the Network Security Groupo be recreated?
// Note that recreating an NSG will usually wipe its rules.
// ''')
// param recreateNsg_p bool = true
// var subnets_v = [
//   {
//     name: 'ext'
//     address: '10.0.0.0/24'
//     delegations: [
//       'Microsoft.Web/serverFarms'
//     ]
//     endpoints: [
//       'Microsoft.Sql'
//       'Microsoft.Storage'
//       'Microsoft.Web'
//     ]
//   }
// ]

// module nsg_m 'modular/nsg.bicep' = [for subnet in subnets_v: if (recreateNsg_p == 'True') {
//   name: 'nsg_m-${subnet.name}'
//   params: {
//     eventHubAuthId_p: eventHubAuthId_p
//     eventHubName_p: eventHubName_p
//     location_p: location_p
//     nsgName_p: 'nsg-ops-app-${subnet.name}-dev'
//     resourceTags_p: resourceTags_p
//   }
// }]

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource specific params
@description('Name if the Network Security Group.')
param nsgName_p string = 'nsg-${uniqueString(resourceGroup().id)}'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// resources
resource nsg_r 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName_p
  location: location_p
  tags: resourceTags_p
}

resource nsgDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: nsg_r
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
  }
}

// ouputs
output api string = nsg_r.apiVersion
output id string = nsg_r.id
output name string = nsg_r.name
output type string = nsg_r.type

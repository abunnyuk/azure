// File: nsgRules.bicep
//
// Change log:
// - Initial release
// - Added example usage
// 
// Creates multiple Network Security Group rules from a dictionary object
//
// var nsgRulesGlobal_v = {
//   'allow-in-https-internet-any': {
//     access: 'Allow'
//     destinationAddressPrefix: '*'
//     destinationPortRange: '443'
//     direction: 'Inbound'
//     priority: 400
//     protocol: '*'
//     sourceAddressPrefix: 'Internet'
//     sourcePortRange: '*'
//   }
//   'deny-out-https-any-internet': {
//     access: 'Deny'
//     destinationAddressPrefix: 'Internet'
//     destinationPortRange: '443'
//     direction: 'Outbound'
//     priority: 2000
//     protocol: '*'
//     sourceAddressPrefix: '*'
//     sourcePortRange: '*'
//   }
// }
//
// module nsgRulesGlobal_m 'modules/modular/nsgRules.bicep' = {
//   scope: group_r
//   name: 'nsgRulesAgw_m'
//   params: {
//     nsgName_p: nsg_m.outputs.name
//     nsgRules_p: nsgRulesGlobal_v
//   }
// }

// required params
@description('Name of the Network Security Group.')
param nsgName_p string

@description('Rules dictionary object.')
param nsgRules_p object

// create rules by looping through object one at a time
@batchSize(1)
resource nsgRule_r 'Microsoft.Network/networkSecurityGroups/securityRules@2021-05-01' = [for rule in items(nsgRules_p): {
  name: '${nsgName_p}/nsgr-${toLower(rule.key)}'
  properties: {
    access: rule.value.access
    description: toLower('${rule.value.access}} ${rule.value.priority}:${rule.value.destinationPortRange} ${rule.value.direction} from ${rule.value.sourceAddressPrefix} to ${rule.value.destinationAddressPrefix}')
    destinationAddressPrefix: rule.value.destinationAddressPrefix
    destinationPortRange: rule.value.destinationPortRange
    direction: rule.value.direction
    priority: rule.value.priority
    protocol: rule.value.protocol
    sourceAddressPrefix: rule.value.sourceAddressPrefix
    sourcePortRange: rule.value.sourcePortRange
  }
}]

// outputs
output rules object = nsgRules_p

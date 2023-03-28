// File: nsgRule.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
// 
// Creates a single NSG rule

// resource params/vars
param destAddressPrefix_p string
param destPortRange_p string
param nsgName_p string

@allowed([
  'Allow'
  'Deny'
])
param access_p string

@allowed([
  'Inbound'
  'Outbound'
])
param direction_p string

@minValue(100)
@maxValue(4096)
param priority_p int

@allowed([
  '*'
  'Ah'
  'Esp'
  'Icmp'
  'Tcp'
  'Udp'
])
param protocol_p string

@description('Must start with nsgr-')
param ruleName_p string = ''
param sourceAddressPrefix_p string = '*'
param sourcePortRange_p string = '*'

var nsgResourceName_v = ((empty(ruleName_p)) ? '${nsgName_p}/nsgr-${toLower(access_p)}-${toLower(direction_p)}-${priority_p}' : '${nsgName_p}/${ruleName_p}')
var nsgRuleDesc_v = '${access_p} ${protocol_p}:${destPortRange_p} ${direction_p} from ${sourceAddressPrefix_p} to ${destAddressPrefix_p}'

// resources
resource nsgRule_p 'Microsoft.Network/networkSecurityGroups/securityRules@2021-05-01' = {
  name: nsgResourceName_v
  properties: {
    description: nsgRuleDesc_v
    protocol: protocol_p
    sourcePortRange: sourcePortRange_p
    destinationPortRange: destPortRange_p
    sourceAddressPrefix: sourceAddressPrefix_p
    destinationAddressPrefix: destAddressPrefix_p
    access: access_p
    priority: priority_p
    direction: direction_p
  }
}

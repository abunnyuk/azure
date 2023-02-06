// File: nsgRules-gw.bicep
// 0.1 - initial release
//
// Custom gateway NSG rules
//
// https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups

// global params
param env_p object

// deny rules params
param nsgGlobalRules_p object = {
  'deny-in-vnet-any': {
    priority: 3800
    ruleName: 'deny-in-vnet-any'
    access: 'Deny'
    direction: 'Inbound'
    protocol: '*'
    destPortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destAddressPrefix: '*'
  }
  'deny-in-inet-any': {
    priority: 3900
    ruleName: 'deny-in-inet'
    access: 'Deny'
    direction: 'Inbound'
    protocol: '*'
    destPortRange: '*'
    sourceAddressPrefix: 'Internet'
    destAddressPrefix: '*'
  }
  'deny-in-any': {
    priority: 4000
    ruleName: 'deny-in-any'
    access: 'Deny'
    direction: 'Inbound'
    protocol: '*'
    destPortRange: '*'
    sourceAddressPrefix: '*'
    destAddressPrefix: '*'
  }
}

// networking vars
var nsgNameAgw_v = 'nsg-${env_p.appShort}-gw-agw-${env_p.envShort}'
var gatewayVnetName_v = 'vnet-${env_p.appShort}-gw-${env_p.envShort}'
var gatewayAgwSubnetName_v = 'snet-${env_p.appShort}-gw-agw-${env_p.envShort}'

var appGroupName_v = 'rg-${env_p.appShort}-app-${env_p.envShort}'
var appVnetName_v = 'vnet-${env_p.appShort}-app-${env_p.envShort}'
var appExtSubnetName_v = 'snet-${env_p.appShort}-app-ext-${env_p.envShort}'

// existing network resources
resource gatewayAgwSubnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${gatewayVnetName_v}/${gatewayAgwSubnetName_v}'
}

resource appExtSubnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  scope: resourceGroup(appGroupName_v)
  name: '${appVnetName_v}/${appExtSubnetName_v}'
}

// gateway nsg rules
module nsgRulesAgwInRangeGwmgrAny_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-agw-allow-in-range-gwmgr-any'
  params: {
    nsgName_p: nsgNameAgw_v
    priority_p: 200
    ruleName_p: 'allow-in-range-gwmgr-any'
    access_p: 'Allow'
    direction_p: 'Inbound'
    protocol_p: 'Tcp'
    destPortRange_p: '65503-65534'
    sourceAddressPrefix_p: 'GatewayManager'
    destAddressPrefix_p: '*'
  }
}

module nsgRulesAgwInHttpsAnyExt_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-agw-allow-in-https-ext-ext'
  params: {
    nsgName_p: nsgNameAgw_v
    priority_p: 250
    ruleName_p: 'allow-in-https-any-ext'
    access_p: 'Allow'
    direction_p: 'Inbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: gatewayAgwSubnet_r.properties.addressPrefix
  }
}

@batchSize(1)
module nsgRulesAgwDeny_m '../modular/nsgRule.bicep' = [for rule in items(nsgGlobalRules_p): {
  name: 'nsgr-agw-${rule.key}'
  params: {
    nsgName_p: nsgNameAgw_v
    priority_p: rule.value.priority
    ruleName_p: rule.value.ruleName
    access_p: rule.value.access
    direction_p: rule.value.direction
    protocol_p: rule.value.protocol
    destPortRange_p: rule.value.destPortRange
    sourceAddressPrefix_p: ((contains(rule.value, 'sourceAddressPrefix')) ? rule.value.sourceAddressPrefix : '*')
    destAddressPrefix_p: rule.value.destAddressPrefix
  }
}]

// ouputs

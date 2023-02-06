// File: nsgRules-app.bicep
// 0.1 - initial release
//
// Custom NSG rules

// global params
param env_p object

// deny rules params
param nsgGlobalRules_p object = {
  'allow-in-alb-any': {
    priority: 3000
    ruleName: 'allow-in-alb-any'
    access: 'Allow'
    direction: 'Inbound'
    protocol: '*'
    destPortRange: '*'
    sourceAddressPrefix: 'AzureLoadBalancer'
    destAddressPrefix: '*'
  }
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
  'deny-out-any-vnet': {
    priority: 3800
    ruleName: 'deny-out-any-vnet'
    access: 'Deny'
    direction: 'Outbound'
    protocol: '*'
    destPortRange: '*'
    destAddressPrefix: 'VirtualNetwork'
  }
  'deny-out-any-inet': {
    priority: 3900
    ruleName: 'deny-out-any-inet'
    access: 'Deny'
    direction: 'Outbound'
    protocol: '*'
    destPortRange: '*'
    destAddressPrefix: 'Internet'
  }
  'deny-out-any': {
    priority: 4000
    ruleName: 'deny-out-any'
    access: 'Deny'
    direction: 'Outbound'
    protocol: '*'
    destPortRange: '*'
    destAddressPrefix: '*'
  }
}

// networking vars
var nsgNameExt_v = 'nsg-${env_p.appShort}-app-ext-${env_p.envShort}'
var nsgNameInt_v = 'nsg-${env_p.appShort}-app-int-${env_p.envShort}'
var nsgNamePep_v = 'nsg-${env_p.appShort}-app-pep-${env_p.envShort}'

var appVnetName_v = 'vnet-${env_p.appShort}-app-${env_p.envShort}'
var appExtSubnetName_v = 'snet-${env_p.appShort}-app-ext-${env_p.envShort}'
var appIntSubnetName_v = 'snet-${env_p.appShort}-app-int-${env_p.envShort}'
var appPepSubnetName_v = 'snet-${env_p.appShort}-app-pep-${env_p.envShort}'

var gatewayGroupName_v = 'rg-${env_p.appShort}-gw-${env_p.envShort}'
var gatewayAgwSubnetName_v = 'snet-${env_p.appShort}-gw-agw-${env_p.envShort}'
var gatewayVnetName_v = 'vnet-${env_p.appShort}-gw-${env_p.envShort}'

// existing network resources
resource gatewayAgwSubnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  scope: resourceGroup(gatewayGroupName_v)
  name: '${gatewayVnetName_v}/${gatewayAgwSubnetName_v}'
}

resource appExtSubnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${appVnetName_v}/${appExtSubnetName_v}'
}

resource appIntSubnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${appVnetName_v}/${appIntSubnetName_v}'
}

resource appPepSubnet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${appVnetName_v}/${appPepSubnetName_v}'
}

// external nsg rules
module nsgRulesExtInHttpsAgwExt_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-ext-allow-in-https-agw-ext'
  params: {
    nsgName_p: nsgNameExt_v
    priority_p: 200
    ruleName_p: 'allow-in-https-agw-ext'
    access_p: 'Allow'
    direction_p: 'Inbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: gatewayAgwSubnet_r.properties.addressPrefix
    destAddressPrefix_p: appExtSubnet_r.properties.addressPrefix
  }
}

module nsgRulesExtOutHttpsAnyInt_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-ext-allow-out-https-any-int'
  params: {
    nsgName_p: nsgNameExt_v
    priority_p: 200
    ruleName_p: 'allow-out-https-any-int'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: appIntSubnet_r.properties.addressPrefix
  }
}

module nsgRulesExtOutSqlAnyPep_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-ext-allow-out-sql-any-pep'
  params: {
    nsgName_p: nsgNameExt_v
    priority_p: 250
    ruleName_p: 'allow-out-sql-any-pep'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '1433'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: appPepSubnet_r.properties.addressPrefix
  }
}

module nsgRulesExtOutHttpsAnyInet_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-ext-allow-out-https-any-inet'
  params: {
    nsgName_p: nsgNameExt_v
    priority_p: 300
    ruleName_p: 'allow-out-https-any-inet'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: 'Internet'
  }
}

@batchSize(1)
module nsgRulesExtDeny_m '../modular/nsgRule.bicep' = [for rule in items(nsgGlobalRules_p): {
  name: 'nsgr-ext-${rule.key}'
  params: {
    nsgName_p: nsgNameExt_v
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

// internal nsg rules
module nsgRulesIntInHttpsExtAny_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-int-allow-in-https-ext-any'
  params: {
    nsgName_p: nsgNameInt_v
    priority_p: 200
    ruleName_p: 'allow-in-https-ext-any'
    access_p: 'Allow'
    direction_p: 'Inbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: appExtSubnet_r.properties.addressPrefix
    destAddressPrefix_p: '*'
  }
}

module nsgRulesIntOutHttpsAnyAStag_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-int-allow-out-https-any-ext'
  params: {
    nsgName_p: nsgNameInt_v
    priority_p: 200
    ruleName_p: 'allow-out-https-any-ext'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: appExtSubnet_r.properties.addressPrefix
  }
}
module nsgRulesIntOutSqlAnyPep_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-int-allow-out-sql-any-pep'
  params: {
    nsgName_p: nsgNameInt_v
    priority_p: 210
    ruleName_p: 'allow-out-sql-any-pep'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '1433'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: appPepSubnet_r.properties.addressPrefix
  }
}

module nsgRulesIntOutHttpsAnyInet_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-int-allow-out-https-any-inet'
  params: {
    nsgName_p: nsgNameInt_v
    priority_p: 220
    ruleName_p: 'allow-out-https-any-inet'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: 'Internet'
  }
}

module nsgRulesIntOutHttpsAnyStorage_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-int-allow-out-https-any-storage'
  params: {
    nsgName_p: nsgNameInt_v
    priority_p: 230
    ruleName_p: 'allow-out-https-any-storage'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '443'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: 'Storage'
  }
}

module nsgRulesIntOutAmpqAnyInet_m '../modular/nsgRule.bicep' = {
  name: 'nsgr-int-allow-out-ampq-any-inet'
  params: {
    nsgName_p: nsgNameInt_v
    priority_p: 240
    ruleName_p: 'allow-out-ampq-any-inet'
    access_p: 'Allow'
    direction_p: 'Outbound'
    protocol_p: 'Tcp'
    destPortRange_p: '5671'
    sourceAddressPrefix_p: '*'
    destAddressPrefix_p: 'Internet'
  }
}

@batchSize(1)
module nsgRulesIntDeny_m '../modular/nsgRule.bicep' = [for rule in items(nsgGlobalRules_p): {
  name: 'nsgr-int-${rule.key}'
  params: {
    nsgName_p: nsgNameInt_v
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

@batchSize(1)
module nsgRulesPepDeny_m '../modular/nsgRule.bicep' = [for rule in items(nsgGlobalRules_p): {
  name: 'nsgr-pep-${rule.key}'
  params: {
    nsgName_p: nsgNamePep_v
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

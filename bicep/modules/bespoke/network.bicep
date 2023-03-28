// File: network.bicep
// 0.1 - initial release
//
// Deploys vnet, nsg, and subnet resources
// Loops through objects in networking_p
// Only creates vnet if env_p.recreateVnet is true

// global params
param env_p object
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource specific params
param networking_p object
param vnetName_p string = 'vnet-${uniqueString(resourceGroup().id)}'

// diags params
param eventHubAuthId_p string
param eventHubName_p string

// extract group string
var resourceGroupString_v = split(resourceGroup().name, '-')[2]

// resources
resource vnet_r 'Microsoft.Network/virtualNetworks@2021-05-01' = if (env_p.recreateVnet == 'true') {
  name: vnetName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    addressSpace: {
      addressPrefixes: [
        networking_p.vnetAddressPrefix
      ]
    }
  }
}

resource vnetDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: vnet_r
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
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// create an nsg for each subnet
@batchSize(1)
resource nsgs_r 'Microsoft.Network/networkSecurityGroups@2021-05-01' = [for subnet in networking_p.subnets: {
  name: 'nsg-${env_p.appShort}-${resourceGroupString_v}-${subnet.name}-${env_p.envShort}'
  location: location_p
  tags: resourceTags_p
}]

resource nsgDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (subnet, i) in networking_p.subnets: if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: nsgs_r[i]
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
}]

// create subnets
@batchSize(1)
resource subnets_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = [for (subnet, i) in networking_p.subnets: {
  name: '${vnetName_p}/snet-${env_p.appShort}-${resourceGroupString_v}-${subnet.name}-${env_p.envShort}'
  dependsOn: [
    nsgs_r
    vnet_r
  ]
  properties: {
    addressPrefix: subnet.addressPrefix
    networkSecurityGroup: {
      id: nsgs_r[i].id
    }
    delegations: ((contains(subnet, 'delegations')) ? subnet.delegations : null)
    privateEndpointNetworkPolicies: ((contains(subnet, 'privateEndpointNetworkPolicies')) ? subnet.privateEndpointNetworkPolicies : 'Enabled')
    serviceEndpoints: ((contains(subnet, 'serviceEndpoints')) ? subnet.serviceEndpoints : null)
  }
}]

module appNsgRules_m 'nsgRules-app.bicep' = if (resourceGroupString_v == 'app') {
  dependsOn: [
    subnets_r
  ]
  name: 'appNsgRules'
  params: {
    env_p: env_p
  }
}

module gatewayNsgRules_m 'nsgRules-gateway.bicep' = if (resourceGroupString_v == 'gw') {
  dependsOn: [
    subnets_r
  ]
  name: 'gatewayNsgRules'
  params: {
    env_p: env_p
  }
}

// outputs
output firstSubnetId string = subnets_r[0].id
output vnetId string = vnet_r.id

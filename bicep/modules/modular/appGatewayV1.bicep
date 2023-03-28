// File: appGatewayV1.bicep
// Author: Bunny Davies
// Version: 0.1

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// gateway params
@allowed([
  'Detection'
  'Prevention'
])
param agwFirewallMode string = 'Detection'
param agwName_p string = 'agw-${uniqueString(resourceGroup().id)}'

@allowed([
  '2.29'
  '3.0'
])
param agwRuleSetVersion string = '3.0'

@minValue(1)
@maxValue(32)
param agwSkuCapacity_p int = 1

@allowed([
  'Standard_Large'
  'Standard_Medium'
  'Standard_Small'
  'WAF_Large'
  'WAF_Medium'
])
param agwSkuName_p string = 'Standard_Small'
param agwSubnetId_p string
param pipId_r string

param backendHttpSettingsCollection_p array = [
  {
    name: 'backendHttpSettingDefault'
    properties: {
      port: 80
      protocol: 'Http'
    }
  }
]

param backendAddressPools_p array = []

param frontendIPConfigurations_p array = [
  {
    name: 'frontendIP'
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      publicIPAddress: {
        id: pipId_r
      }
    }
  }
]

param frontEndPorts_p array = [
  {
    name: 'frontendPortDefault'
    properties: {
      port: 80
    }
  }
  {
    name: 'frontendPort443'
    properties: {
      port: 443
    }
  }
]

param gatewayIPConfigurations_p array = [
  {
    name: 'gatewayIP'
    properties: {
      subnet: {
        id: agwSubnetId_p
      }
    }
  }
]

param probes_p array = []

param webApplicationFirewallConfiguration_p object = contains(agwSkuName_p, 'WAF') ? {
  enabled: true
  firewallMode: agwFirewallMode
  ruleSetType: 'OWASP'
  ruleSetVersion: agwRuleSetVersion
} : { enabled: false }

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

var backendPoolDefault_v = [
  {
    name: 'backendAddressPoolDefault'
    properties: {}
  }
]

var backendPoolsUnion_v = union(backendPoolDefault_v, backendAddressPools_p)

// resources
resource agw_r 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: agwName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    backendAddressPools: backendPoolsUnion_v
    backendHttpSettingsCollection: backendHttpSettingsCollection_p
    frontendIPConfigurations: frontendIPConfigurations_p
    frontendPorts: frontEndPorts_p
    gatewayIPConfigurations: gatewayIPConfigurations_p
    httpListeners: [
      {
        name: 'httpListenerDefault'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName_p, 'frontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName_p, 'frontendPortDefault')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'ruleDefault'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName_p, 'httpListenerDefault')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName_p, 'backendAddressPoolDefault')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName_p, 'backendHttpSettingDefault')
          }
        }
      }
    ]
    probes: probes_p
    sku: {
      name: agwSkuName_p
      tier: split(agwSkuName_p, '_')[0]
      capacity: agwSkuCapacity_p
    }
    webApplicationFirewallConfiguration: webApplicationFirewallConfiguration_p
  }
}

resource agwDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: agw_r
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

// outputs
output api string = agw_r.apiVersion
output id string = agw_r.id
output name string = agw_r.name
output type string = agw_r.type

// File: appGatewayV2.bicep
// Version: 0.1
// 
//! MODULE IN DEVELOPMENT - NOT PRODUCTION READY

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
param agwUserIdentityName_p string = 'id-${agwName_p}'

@allowed([
  '2.29'
  '3.0'
])
param agwRuleSetVersion string = '3.0'

@minValue(1)
@maxValue(32)
param agwSkuCapacity_p int = 1

@allowed([
  'Standard_v2'
  'WAF_v2'
])
param agwSkuName_p string = 'Standard_v2'
param agwSubnetId_p string

@allowed([
  'None'
  'UserAssigned'
])
param identity_p string = 'UserAssigned'

// public ip params
param pipName_p string = 'pip-${uniqueString(resourceGroup().id)}'

@allowed([
  'Global'
  'Regional'
])
param pipSkuTier_p string = 'Regional'

@allowed([
  'Basic'
  'Standard'
])
param pipSkuName_p string = 'Basic'

@allowed([
  'IPv4'
  'IPv6'
])
param pipVersion_p string = 'IPv4'

@allowed([
  'Dynamic'
  'Static'
])
param pipMethod_p string = 'Dynamic'

var identity_v = {
  None: {
    type: identity_p
  }
  UserAssigned: {
    type: identity_p
    userAssignedIdentities: {
      '${identity_r.id}': {}
    }
  }
}

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// resources

// outputs
resource pip_r 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: pipName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: pipSkuName_p
    tier: pipSkuTier_p
  }
  properties: {
    publicIPAddressVersion: pipVersion_p
    publicIPAllocationMethod: pipMethod_p
  }
}

resource identity_r 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = if (identity_p == 'UserAssigned') {
  name: agwUserIdentityName_p
  location: location_p
  tags: resourceTags_p
}

resource agw_r 'Microsoft.Network/applicationGateways@2021-05-01' = if (endsWith(agwSkuName_p, 'v2')) {
  name: agwName_p
  location: location_p
  tags: resourceTags_p
  identity: identity_v[identity_p]
  properties: {
    sku: {
      name: agwSkuName_p
      tier: split(agwSkuName_p, '_')[0]
      capacity: agwSkuCapacity_p
    }
    gatewayIPConfigurations: [
      {
        name: 'gatewayIP'
        properties: {
          subnet: {
            id: agwSubnetId_p
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendIP'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip_r.id
          }
        }
      }
    ]
    frontendPorts: [
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
    backendAddressPools: [
      {
        name: 'backendAddressPoolDefault'
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'backendHttpSettingDefault'
        properties: {
          port: 80
          protocol: 'Http'
        }
      }
    ]
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
    webApplicationFirewallConfiguration: {
      enabled: ((contains(agwSkuName_p, 'WAF')) ? true : false)
      firewallMode: agwFirewallMode
      ruleSetType: 'OWASP'
      ruleSetVersion: agwRuleSetVersion
    }
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

resource agwPipDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: pip_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
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

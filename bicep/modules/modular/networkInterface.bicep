// File: networkInterface.bicep
// Author: Bunny Davies
//
// Work in progress!

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
@description('Array of custom DNS servers.')
param dnsServers_p array = []

@description('Unique ID number.')
param nicId_p int = 0

@description('Name of the network interface. Default value of `nic-vmName_p-nidId_p`')
param nicName_p string = 'nic-${nicId_p}-${vmName_p}'

@description('Public IP resource ID.')
param pipId_p string = ''

@description('Subnet resource ID.')
param subnetId_p string

@description('Name of the virtal machine. Used to generate the NIC name.')
param vmName_p string = 'vm${uniqueString(resourceGroup().id)}'

// diags params
param eventHubAuthId_p string = ''
param eventHubName_p string = ''

// resources
resource nic_r 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: nicName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    dnsSettings: {
      dnsServers: dnsServers_p
    }
    ipConfigurations: [
      {
        name: 'ipconfig${nicId_p}'
        properties: {
          publicIPAddress: !empty(pipId_p) ? json('{ "id": "${pipId_p}"}') : null
          subnet: {
            id: subnetId_p
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource nicDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
  scope: nic_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_p
    eventHubAuthorizationRuleId: eventHubAuthId_p
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// outputs
output api string = nic_r.apiVersion
output id string = nic_r.id
output name string = nic_r.name
output privateIp string = nic_r.properties.ipConfigurations[0].properties.privateIPAddress
output type string = nic_r.type

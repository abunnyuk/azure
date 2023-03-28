// File: vnetSubnet.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
// - Added route table support
// 
// Creates a Subnet supporting delegations, service endpoints, NAT gatway, and Network Security Group
//
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
// 
// module subnets_m 'modules/modular/vnetSubnet.bicep' = [for (subnet, i) in subnets_v: {
//   scope: group_r
//   name: 'subnets_m-${subnet.name}'
//   params: {
//     address_p: subnet.address
//     delegations_p: subnet.delegations
//     endpoints_p: subnet.endpoints
//     ngId_p: natGateway_m.outputs.id
//     nsgId_p: nsg_m[i].outputs.id
//     routeTableId_p: routeTable_m.outputs.id
//     subnetName_p: 'snet-ops-app-${subnet.name}-dev'
//     vnetName_p: vnet_m.outputs.name
//   }
// }]

// global params/vars

// resource params/vars
@description('The address prefix for the subnet.')
param address_p string

@description('An array of references to the delegations on the subnet.')
param delegations_p array = []

@description('An array of service endpoints.')
param endpoints_p array = []

@description('The reference to the Nat Gatway resource.')
param ngId_p string = ''

@description('The reference to the Network Security Group resource.')
param nsgId_p string = ''

@allowed([
  'Disabled'
  'Enabled'
])
@description('Enable or Disable apply network policies on private end point in the subnet.')
param privateEndpointNetworkPolicies_p string = 'Enabled'

@allowed([
  'Disabled'
  'Enabled'
])
@description('Enable or Disable apply network policies on private link service in the subnet.')
param privateLinkServiceNetworkPolicies_p string = 'Enabled'

@description('The reference to the Route Table resource.')
param routeTableId_p string = ''

@description('Name of the subnet.')
param subnetName_p string

@description('Name of the virtual network.')
param vnetName_p string

// create properties array from delegations
var delegationsArray_v = [for delegation in delegations_p: {
  name: 'delegation'
  properties: {
    serviceName: delegation
  }
}]

// create properties array from service endpoints
var endpointsArray_v = [for endpoint in endpoints_p: {
  service: endpoint
}]

// if nat gateway id passed then create property, else empty
var ngProperty_v = !empty(ngId_p) ? {
  natGateway: {
    id: ngId_p
  }
} : {}

// if network security group id passed then create property, else empty
var nsgProperty_v = !empty(nsgId_p) ? {
  networkSecurityGroup: {
    id: nsgId_p
  }
} : {}

// if route table id passed then create property, else empty
var routeTableProperty_v = !empty(routeTableId_p) ? {
  routeTable: {
    id: routeTableId_p
  }
} : {}

// base set of resource properties
var baseProperties_v = {
  addressPrefix: address_p
  delegations: delegationsArray_v
  privateEndpointNetworkPolicies: privateEndpointNetworkPolicies_p
  privateLinkServiceNetworkPolicies: privateLinkServiceNetworkPolicies_p
  serviceEndpoints: endpointsArray_v
}

// combine base, nat gateway, network security group, and route table properties
var propertiesUnion_v = union(baseProperties_v, ngProperty_v, nsgProperty_v, routeTableProperty_v)

// resources
resource snet_r 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: '${vnetName_p}/${subnetName_p}'
  properties: propertiesUnion_v
}

// outputs
output addressPrefix string = snet_r.properties.addressPrefix
output api string = snet_r.apiVersion
output id string = snet_r.id
output name string = snet_r.name
output propertiesUnion object = propertiesUnion_v
output type string = snet_r.type

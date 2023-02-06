// File: natGateway.bicep
//
// Change log:
// - Initial release
// - Added example usage
// 
// Creates a NAT Gateway
//
// module natGateway_m 'modules/modular/natGateway.bicep' = {
//   scope: group_r
//   name: 'natGateway_m'
//   params: {
//     location_p: location_p
//     ngName_p: natName_v
//     pipId_p: pip_m.outputs.id
//     resourceTags_p: resourceTags_p
//   }
// }

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource specific params
@description('The idle timeout in minutes of the NAT gateway.')
param idleTimeout_p int = 4

@description('Name of the NAT gateway.')
param ngName_p string = 'ng${uniqueString(resourceGroup().id)}'

@description('Resource ID of the public IP address.')
param pipId_p string

resource natGateway_r 'Microsoft.Network/natGateways@2021-08-01' = {
  name: ngName_p
  properties: {
    idleTimeoutInMinutes: idleTimeout_p
    publicIpAddresses: [
      {
        id: pipId_p
      }
    ]
  }
  location: location_p
  tags: resourceTags_p
  sku: {
    name: 'Standard'
  }
}

// ouputs
output api string = natGateway_r.apiVersion
output id string = natGateway_r.id
output name string = natGateway_r.name

// File: privateDnsZone.bicep
//
// Change log:
// - Initial release
// - Made private link name unique per zone by pulling the vnet name from its id
// - Set zoneName_p to required with no default value
// 
// Creates a Private DNS Zone with optional Private Link
//
// Note that environment suffixes have inconsistent leading periods
// https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-deployment#example-1
//
// var privateDnsZones_v = [
//   'privatelink.file.${environment().suffixes.storage}'
//   'privatelink${environment().suffixes.sqlServerHostname}'
// ]
//
// module privateDnsZones_m 'modules/modular/privateDnsZone.bicep' = [for zone in privateDnsZones_v: {
//   scope: group_r
//   name: zone
//   params: {
//     location_p: 'global'
//     resourceTags_p: resourceTags_p
//     vnetIdDeployed_p: vnetId_p
//     zoneName_p: zone
//   }
// }]

// global params/vars
param location_p string = 'global'
param resourceTags_p object = {}

// resource params/vars
@description('Is auto-registration of virtual machine records in the virtual network in the Private DNS zone enabled?')
param registrationEnabled_p bool = false

@description('''
The reference of the Virtual Network.
Only required for the creation of a Private Link.
''')
param vnetId_p string = ''

@description('''
The DNS zone name.

Note that environment suffixes have inconsistent leading periods:
https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-deployment#example-1
''')
param zoneName_p string

var vnetName_v = last(split(vnetId_p, '/'))

// resources
resource privateDnsZone_r 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zoneName_p
  location: location_p
  tags: resourceTags_p

  // if vnetId_p is passed then create a Private Link
  resource sqlvirtualNetworkLink_r 'virtualNetworkLinks' = if (!empty(vnetId_p)) {
    name: 'link-${vnetName_v}'
    location: location_p
    tags: resourceTags_p
    properties: {
      registrationEnabled: registrationEnabled_p
      virtualNetwork: {
        id: vnetId_p
      }
    }
  }
}

// outputs
output api string = privateDnsZone_r.apiVersion
output id string = privateDnsZone_r.id
output name string = privateDnsZone_r.name
output type string = privateDnsZone_r.type

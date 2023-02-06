// File: privateEndpoint.bicep
//
// Creates a Private Endpoint and attaches it to a Private DNS Zone
//
// module privateEndpoint_m 'modules/modular/privateEndpoint.bicep' = {
//   scope: group_r
//   name: 'privateEndpoint_m-${sqlServer_m.outputs.name}'
//   params: {
//     dnsZoneId_p: privateDnsZones_m.outputs.id
//     endpointName_p: 'pep-${sqlServer_m.outputs.name}'
//     groupIds_p: [
//       'sqlServer'
//     ]
//     location_p: location_p
//     resourceTags_p: resourceTags_p
//     serviceId_p: sqlServer_m.outputs.id
//     subnetId_p: subnet_m.outputs.id
//   }
// }

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params

// private endpoint params
@description('The resource id of the private dns zone.')
param dnsZoneId_p string

@description('''
The ID(s) of the group(s) obtained from the remote resource that this private endpoint should connect to.
https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource
''')
param groupIds_p array

@description('The ID of the existing subnet from which the private IP will be allocated.')
param subnetId_p string

@description('The name of the private endpoint.')
param endpointName_p string = 'pep-${last(split(subnetId_p, '/'))}-${last(split(serviceId_p, '/'))}'

@description('The resource id of the existing private link service, e.g., SQL Server or Storage Account.')
param serviceId_p string

// resources
resource privateEndpoint_r 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: endpointName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    subnet: {
      id: subnetId_p
    }
    privateLinkServiceConnections: [
      {
        name: endpointName_p
        properties: {
          privateLinkServiceId: serviceId_p
          groupIds: groupIds_p
        }
      }
    ]
  }

  resource dnsZoneGroup_r 'privateDnsZoneGroups' = {
    name: 'mydnsgroupname'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config1'
          properties: {
            privateDnsZoneId: dnsZoneId_p
          }
        }
      ]
    }
  }
}

// ouputs
output api string = privateEndpoint_r.apiVersion
output id string = privateEndpoint_r.id
output name string = privateEndpoint_r.name
output type string = privateEndpoint_r.type

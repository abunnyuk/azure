// File: routeTable.bicep
// Author: Bunny Davies
//
// Change log:
// - Initial release
// 
// Creates a Route Table
// 
// module routeTable_m 'modules/modular/routeTable.bicep' = {
//   scope: group_r
//   name: 'routeTables_m-${subnet.name}'
//   params: {
//     location_p: location_p
//     resourceTags_p: resourceTags_p
//     tableName_p: routeTableName_p
//   }
// }

// global params/vars
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params/vars
param disableBgpRoutePropagation_p bool = false
param routes_p array = []
param tableName_p string = 'route-${uniqueString(resourceGroup().id)}'

// resources
resource routeTable_r 'Microsoft.Network/routeTables@2021-05-01' = {
  name: tableName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation_p
    routes: routes_p
  }
}

// outputs
output api string = routeTable_r.apiVersion
output id string = routeTable_r.id
output name string = routeTable_r.name
output type string = routeTable_r.type

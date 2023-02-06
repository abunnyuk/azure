// scope
targetScope = 'subscription'

// params
@description('Location of the deployment as passed to `az deployment`')
param location_p string = deployment().location

// vars
var json_v = loadJsonContent('params/main.jsonc')
var resourcegroupName_v = 'rg-${json_v.env.appShort}-${json_v.env.workItemId}-${json_v.env.envShort}'

var resourceTags_v = {
  Application: json_v.env.appLong
  Environment: json_v.env.envLong
  'Created By': json_v.env.createdBy
  'Work Item': json_v.env.workItemId
}

// resources
resource group_res 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourcegroupName_v
  location: location_p
  tags: resourceTags_v
}

// modules

// outputs
output resourceGroup string = group_res.name

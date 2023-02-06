// File: sqlServer.bicep
// 0.1 - initial release

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
param adAdminLogin_p string
@secure()
param adAdminSid_p string
param adAdminTenantId_p string = subscription().tenantId

@description('Azure Active Directory only Authentication enabled.')
param azureADOnlyAuthentication_p bool = false

@allowed([
  'None'
  'SystemAssigned'
  'UserAssigned'
])
param identity_p string = 'SystemAssigned'

@allowed([
  'BasePrice'
  'LicenseIncluded'
])
@description('''
The license type:

- 'BasePrice' (discounted AHB price for bringing your own SQL licenses)
- 'LicenseIncluded' (regular price inclusive of a new SQL license)
''')
param licenseType_p string = 'LicenseIncluded'
param localAdminUser_p string = 'sqldba'

@secure()
param localAdminPass_p string = ''

@description('Whether or not the public data endpoint is enabled.')
param publicDataEndpointEnabled_p bool = false
param serverName_p string = 'sqlmi-${uniqueString(resourceGroup().id)}'

@allowed([
  'None'
  'SystemAssigned'
])
param servicePrincipal_p string = 'SystemAssigned'

@allowed([
  'BC_Gen4'
  'BC_Gen5'
  'GP_Gen4'
  'GP_Gen5'
])
@description('The name of the SKU, typically, a letter + Number code, e.g. P3.')
param skuName_p string = 'GP_Gen5'

@description('Subnet resource ID for the managed instance.')
param subnetId_p string

@allowed([
  4
  8
  16
  24
  32
  40
  64
  80
])
@description('The number of vCores.')
param vCores_p int = 4

// diags params
// param eventHubAuthId_p string = ''
// param eventHubName_p string = ''

resource sqlManagedInstance_r 'Microsoft.Sql/managedInstances@2022-02-01-preview' = {
  name: serverName_p
  location: location_p
  tags: resourceTags_p
  identity: {
    type: identity_p
  }
  sku: {
    name: skuName_p
  }
  properties: {
    administratorLogin: ((!empty(localAdminUser_p) && !empty(localAdminPass_p)) ? localAdminUser_p : null)
    administratorLoginPassword: ((!empty(localAdminPass_p)) ? localAdminPass_p : null)
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: azureADOnlyAuthentication_p
      login: adAdminLogin_p
      principalType: 'Group'
      sid: adAdminSid_p
      tenantId: adAdminTenantId_p
    }
    licenseType: licenseType_p
    publicDataEndpointEnabled: publicDataEndpointEnabled_p
    servicePrincipal: {
      type: servicePrincipal_p
    }
    subnetId: subnetId_p
    vCores: vCores_p
  }
}

// resource master_r 'Microsoft.Sql/managedInstances/databases@2022-02-01-preview' existing = {
//   parent: sqlManagedInstance_r
//   name: 'master'
// }

// resource sqlManagedInstanceDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(eventHubName_p) && !empty(eventHubAuthId_p)) {
//   scope: master_r
//   name: 'default'
//   properties: {
//     eventHubName: eventHubName_p
//     eventHubAuthorizationRuleId: eventHubAuthId_p
//     logs: [
//       {
//         categoryGroup: 'audit'
//         enabled: true
//       }
//       {
//         categoryGroup: 'allLogs'
//         enabled: true
//       }
//     ]
//     metrics: [
//       {
//         category: 'Basic'
//         enabled: true
//       }
//       {
//         category: 'InstanceAndAppAdvanced'
//         enabled: true
//       }
//       {
//         category: 'WorkloadManagement'
//         enabled: true
//       }
//     ]
//   }
// }

// ouputs
output api string = sqlManagedInstance_r.apiVersion
output dnsZone string = sqlManagedInstance_r.properties.dnsZone
output fqdn string = sqlManagedInstance_r.properties.fullyQualifiedDomainName
output id string = sqlManagedInstance_r.id
output name string = sqlManagedInstance_r.name
output type string = sqlManagedInstance_r.type

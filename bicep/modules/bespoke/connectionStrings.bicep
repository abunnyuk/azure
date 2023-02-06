// File: connectionStrings.bicep
// Author: Bunny Davies
// 
// Creates App Service connection strings from a JSON array
// 
// {
//   "conStrings": [
//       {
//           "name": "OctopusHRConnection",
//           "serverId": 0,
//           "managedInstance": true,
//           "database": "OctopusHR",
//           "type": "AzureSQLManagedInstance",
//           "roles": [
//               {
//                   "name": "db_owner"
//               }
//           ]
//       },
//       {
//           "name": "LookupConnection",
//           "serverId": 0,
//           "managedInstance": false,
//           "database": "Lookup",
//           "type": "AzureSQL",
//           "roles": [
//               {
//                   "name": "db_owner"
//               }
//           ]
//       }
//   ]
// }

// params/vars
@description('JSON array of connection strings')
param conStrings_p array

@description('Name of the data resource group. Added to the sql roles array and used to create the firewall rule.')
param dataGroupName_p string

@description('JSON object containing environment variables')
param env_p object

@description('Prefix string of the SQL Managed Instance.')
param sqlMiPrefix_p string

var sqlServerSuffix_v = environment().suffixes.sqlServerHostname

// define connection string parameters
var conStringParams_v = ';Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=Active Directory Managed Identity;'

// create array of connection strings
var conStringsArray_v = [for connection in conStrings_p: {
  name: connection.name
  server: connection.managedInstance == bool('true') ? 'sqlmi-${env_p.appShort}-data-${connection.ServerId}-${env_p.envShort}.${sqlMiPrefix_p}${sqlServerSuffix_v}' : 'sql-${env_p.appShort}-data-${connection.ServerId}-${env_p.envShort}${sqlServerSuffix_v}'
  database: ';Database=${connection.database}'
  type: connection.type
}]

// create a json array of connection strings
var conStringsJsonArray_v = [for (connection, i) in conStringsArray_v: json('{"${connection.name}": {"type": "${connection.type}", "value": "Server=tcp:${connection.server}${connection.database}${conStringParams_v}"}}')]

// convert into a string in the format expected by the app service connection string resource
// replace "},{" with "," and remove "/" escape characters
var conStringFlatFormatted_v = replace(replace(string(conStringsJsonArray_v), '},{', ','), '/', '')

// then turn into a json object by removing surrounding square brackets
var conStringJsonObject_v = json(replace(replace(string(conStringFlatFormatted_v), '[', ''), ']', ''))

// build the sql roles task array which is used in a separate pipeline task
// note that the managed instance connection uses the public endpoint
var sqlRolesArray_v = [for connection in conStrings_p: {
  server: connection.managedInstance == bool('true') ? 'sqlmi-${env_p.appShort}-data-${connection.ServerId}-${env_p.envShort}.public.${sqlMiPrefix_p}' : 'sql-${env_p.appShort}-data-${connection.ServerId}-${env_p.envShort}'
  suffix: connection.managedInstance == bool('true') ? '${environment().suffixes.sqlServerHostname},3342' : environment().suffixes.sqlServerHostname
  database: connection.database
  group: dataGroupName_p
  nsg: connection.managedInstance == bool('true') ? 'nsg-${env_p.appShort}-data-smi${connection.ServerId}-${env_p.envShort}' : null
  perms: contains(connection, 'perms') ? connection.perms : []
  roles: contains(connection, 'roles') ? connection.roles : []
  sprs: contains(connection, 'sprs') ? connection.sprs : []
}]

// outputs
output conStringsJson object = conStringJsonObject_v
output sqlRoles array = sqlRolesArray_v

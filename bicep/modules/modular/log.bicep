// File: log.bicep

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource specific params
param eventHubName_p string = 'evh-${uniqueString(resourceGroup().id)}'
param namespaceName_p string = 'ehns-${uniqueString(resourceGroup().id)}'
param namespaceSku_p string = 'Basic'
param workspaceName_p string = 'log-${uniqueString(resourceGroup().id)}'
param workspaceSku_p string = 'PerGB2018'

// resource specific vars
var workspaceId_v = logWorkspace_r.id
var eventHubName_v = eventHub_r.name
var eventHubAuthorizationRuleId_v = '${namespace_r.id}/AuthorizationRules/RootManageSharedAccessKey'

// resources
resource logWorkspace_r 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    sku: {
      name: workspaceSku_p
    }
  }
}

resource logWorkspaceDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: logWorkspace_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_v
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId_v
    workspaceId: workspaceId_v
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

resource namespace_r 'Microsoft.EventHub/namespaces@2021-06-01-preview' = {
  name: namespaceName_p
  location: location_p
  tags: resourceTags_p
  sku: {
    name: namespaceSku_p
    tier: namespaceSku_p
    capacity: 1
  }
}

resource namespaceDiags_r 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: namespace_r
  name: 'default'
  properties: {
    eventHubName: eventHubName_v
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId_v
    workspaceId: workspaceId_v
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

resource eventHub_r 'Microsoft.EventHub/namespaces/eventhubs@2021-06-01-preview' = {
  parent: namespace_r
  name: eventHubName_p
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
    status: 'Active'
  }
}

// outputs
output workspaceId string = workspaceId_v
output eventHubName string = eventHubName_v
output eventHubAuthorizationRuleId string = eventHubAuthorizationRuleId_v

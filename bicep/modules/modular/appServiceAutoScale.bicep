// File: appServiceAutoScale.bicep
// 0.1 - initial release

// global params
@description('Resource location. Defaults to resource group location.')
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// resource params
@description('The number of instances that will be set if metrics are not available for evaluation. The default is only used if the current instance count is lower than the default.')
param countDefault_p string = '1'

@description('The maximum number of instances for the resource. The actual maximum number of instances is limited by the cores that are available in the subscription.')
param countMin_p string = '1'

@description('The maximum number of instances for the resource. The actual maximum number of instances is limited by the cores that are available in the subscription.')
param countMax_p string = '2'

@description('The resource identifier of the resource the rule monitors. Defaults to targetResourceId_p.')
param metricResourceId_p string = targetResourceId_p

@description('The sku of the app service plan. Used to skip scaling if module is used in a loop and the plan does not support it.')
param planSku_p string = ''

// profile names should be unique as they are stored in the resource group
// az monitor autoscale list --resource-group mygroup --query '[].{Name:name, Target:targetResourceUri}' --output json
@description('The name of the autoscale setting.')
param profileName_p string = 'autoscale-${uniqueString(targetResourceId_p, deployment().name)}'

@description('The resource identifier of the resource that the autoscale setting should be added to.')
param targetResourceId_p string

param rules_p array = [
  {
    scaleAction: {
      cooldown: 'PT5M'
      direction: 'Increase'
      type: 'ChangeCount'
      value: '1'
    }
    metricTrigger: {
      metricName: 'CpuPercentage'
      metricResourceUri: metricResourceId_p
      operator: 'GreaterThanOrEqual'
      statistic: 'Average'
      threshold: 70
      timeAggregation: 'Average'
      timeGrain: 'PT1M'
      timeWindow: 'PT10M'
    }
  }
  {
    scaleAction: {
      cooldown: 'PT5M'
      direction: 'Decrease'
      type: 'ChangeCount'
      value: '1'
    }
    metricTrigger: {
      metricName: 'CpuPercentage'
      metricResourceUri: metricResourceId_p
      operator: 'LessThan'
      statistic: 'Average'
      threshold: 40
      timeAggregation: 'Average'
      timeGrain: 'PT1M'
      timeWindow: 'PT10M'
    }
  }
]

resource autoscale_r 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = if (planSku_p != 'Y1') {
  name: profileName_p
  location: location_p
  tags: resourceTags_p
  properties: {
    enabled: true
    targetResourceUri: targetResourceId_p
    profiles: [
      {
        name: profileName_p
        capacity: {
          default: countDefault_p
          maximum: countMax_p
          minimum: countMin_p
        }
        rules: rules_p
      }
    ]
  }
}

// outputs

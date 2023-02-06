// File: serviceBusQueue.bicep

// params
// @description('ISO 8061 timeSpan idle interval after which the queue is automatically deleted. The minimum duration is 5 minutes.')
// param autoDeleteOnIdle_p string = 'PT5M'  //TODO find out how to set as not configured

@description('A value that indicates whether this queue has dead letter support when a message expires.')
param deadLetteringOnMessageExpiration_p bool = false

@description('''
ISO 8601 default message timespan to live value.
This is the duration after which the message expires, starting from when the message is sent to Service Bus.
This is the default value used when TimeToLive is not set on a message itself.
''')
param defaultMessageTimeToLive_p string = 'P14D'

@description('ISO 8601 timeSpan structure that defines the duration of the duplicate detection history.')
param duplicateDetectionHistoryTimeWindow_p string = 'PT10M'

@description('Value that indicates whether server-side batched operations are enabled.')
param enableBatchedOperations_p bool = true

@description('A value that indicates whether Express Entities are enabled. An express queue holds a message in memory temporarily before writing it to persistent storage.')
param enableExpress_p bool = false

@description('A value that indicates whether the queue is to be partitioned across multiple message brokers.')
param enablePartitioning_p bool = false

@description('''
ISO 8601 timespan duration of a peek-lock; that is, the amount of time that the message is locked for other receivers.
The maximum value for LockDuration is 5 minutes; the default value is 1 minute.
''')
param lockDuration_p string = 'PT1M'

@description('The maximum delivery count. A message is automatically deadlettered after this number of deliveries.')
param maxDeliveryCount_p int = 10

@description('The maximum size of the queue in megabytes, which is the size of memory allocated for the queue. Default is 1024.')
param maxSizeInMegabytes_p int = 1024

@description('Name of the Service Bus Queue')
param queueName_p string

@description('A value indicating if this queue requires duplicate detection.')
param requiresDuplicateDetection_p bool = false

@description('A value that indicates whether the queue supports the concept of sessions.')
param requiresSession_p bool = false

@description('Name of the Service Bus')
param serviceBusName_p string

// existing resources
resource serviceBus_r 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName_p
}

// resources
resource serviceBusQueue_r 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBus_r
  name: queueName_p
  properties: {
    // autoDeleteOnIdle: autoDeleteOnIdle_p //TODO find out how to set as not configured
    // forwardDeadLetteredMessagesTo: //TODO
    // forwardTo: //TODO
    // maxMessageSizeInKilobytes: //TODO premium only
    deadLetteringOnMessageExpiration: deadLetteringOnMessageExpiration_p
    defaultMessageTimeToLive: defaultMessageTimeToLive_p
    duplicateDetectionHistoryTimeWindow: duplicateDetectionHistoryTimeWindow_p
    enableBatchedOperations: enableBatchedOperations_p
    enableExpress: enableExpress_p
    enablePartitioning: enablePartitioning_p
    lockDuration: lockDuration_p
    maxDeliveryCount: maxDeliveryCount_p
    maxSizeInMegabytes: maxSizeInMegabytes_p
    requiresDuplicateDetection: requiresDuplicateDetection_p
    requiresSession: requiresSession_p
  }
}
// outputs
output api string = serviceBusQueue_r.apiVersion
output id string = serviceBusQueue_r.id
output name string = serviceBusQueue_r.name
output type string = serviceBusQueue_r.type

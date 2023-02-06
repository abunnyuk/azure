// File: vnetPeering.bicep
// Version: 0.1

@description('Name of the peering to be created.')
param peeringName_p string = 'peer-${split(remoteVnetId_p, '/')[8]}'

@description('Name of the local virtual network.')
param localVnetName_p string

@description('ID of the remote virtual network.')
param remoteVnetId_p string

@description('Whether the forwarded traffic from the VMs in the local virtual network will be allowed/disallowed in remote virtual network.')
param allowForwardedTraffic_p bool = false

@description('If gateway links can be used in remote virtual networking to link to this virtual network.')
param allowGatewayTransit_p bool = false

@description('Whether the VMs in the local virtual network space would be able to access the VMs in remote virtual network space.')
param allowVirtualNetworkAccess_p bool = false

@description('If we need to verify the provisioning state of the remote gateway.')
param doNotVerifyRemoteGateways_p bool = false

@allowed([
  'Connected'
  'Disconnected'
  'Initiated'
])
@description('The status of the virtual network peering.')
param peeringState_p string = 'Connected'

@allowed([
  'FullyInSync'
  'LocalAndRemoteNotInSync'
  'LocalNotInSync'
  'RemoteNotInSync'
])
@description('')
param peeringSyncLevel_p string = 'FullyInSync'

@description('''
If remote gateways can be used on this virtual network.
If the flag is set to true, and allowGatewayTransit on remote peering is also true, virtual network will use gateways of remote virtual network for transit.
Only one peering can have this flag set to true.
This flag cannot be set if virtual network already has a gateway.
''')
param useRemoteGateways_p bool = false

// resources

resource peering_r 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-08-01' = {
  name: '${localVnetName_p}/${peeringName_p}'
  properties: {
    allowForwardedTraffic: allowForwardedTraffic_p
    allowGatewayTransit: allowGatewayTransit_p
    allowVirtualNetworkAccess: allowVirtualNetworkAccess_p
    doNotVerifyRemoteGateways: doNotVerifyRemoteGateways_p
    peeringState: peeringState_p
    peeringSyncLevel: peeringSyncLevel_p
    remoteVirtualNetwork: {
      id: remoteVnetId_p
    }
    useRemoteGateways: useRemoteGateways_p
  }
}

// outputs
output api string = peering_r.apiVersion
output id string = peering_r.id
output name string = peering_r.name
output type string = peering_r.type

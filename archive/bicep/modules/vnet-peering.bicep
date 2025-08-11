// VNet Peering between two Virtual Networks
// Used for connecting NVA spoke with Route Server spoke for BGP communication

@description('First VNet name')
param vnet1Name string

@description('First VNet resource ID')
param vnet1Id string

@description('Second VNet name') 
param vnet2Name string

@description('Second VNet resource ID')
param vnet2Id string

@description('Allow forwarded traffic from remote VNet')
param allowForwardedTraffic bool = true

@description('Allow gateway transit')
param allowGatewayTransit bool = false

@description('Use remote gateways')
param useRemoteGateways bool = false

// Peering from VNet1 to VNet2
resource peering1to2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${vnet1Name}/${vnet1Name}-to-${vnet2Name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: vnet2Id
    }
  }
}

// Peering from VNet2 to VNet1  
resource peering2to1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${vnet2Name}/${vnet2Name}-to-${vnet1Name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: vnet1Id
    }
  }
}

// Outputs
output peering1to2Id string = peering1to2.id
output peering2to1Id string = peering2to1.id

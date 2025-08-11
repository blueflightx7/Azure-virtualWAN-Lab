// Phase 4c: VNet Peering Between Spoke1 and Spoke3 VNet for NVA-Route Server BGP
// Create peering to allow NVA in spoke1 to communicate with Route Server in spoke3

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

// Get existing VNets
resource spokeVnet1 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke1-vnet'
}

resource spoke3Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke3-vnet'
}

// Create peering from spoke1 to spoke3 VNet
resource spoke1ToSpoke3Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spokeVnet1
  name: 'to-spoke3-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke3Vnet.id
    }
  }
}

// Create peering from spoke3 VNet to spoke1
resource spoke3ToSpoke1Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke3Vnet
  name: 'to-spoke1-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnet1.id
    }
  }
}

output spoke1ToSpoke3PeeringId string = spoke1ToSpoke3Peering.id
output spoke3ToSpoke1PeeringId string = spoke3ToSpoke1Peering.id
output peeringState string = spoke1ToSpoke3Peering.properties.peeringState

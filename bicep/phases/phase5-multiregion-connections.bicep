// Phase 5: VWAN Hub Connections
// Creates connections between spokes and VWAN hubs

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

// Hub Names
@description('West US VWAN Hub name')
param westUsHubName string = 'vhub-${environmentPrefix}-wus'
@description('Southeast Asia VWAN Hub name')
param southeastAsiaHubName string = 'vhub-${environmentPrefix}-sea'

// VNet Names
@description('Spoke 1 VNet name (West US)')
param spoke1VnetName string = 'vnet-spoke1-${environmentPrefix}-wus'
@description('Spoke 2 VNet name (Southeast Asia)')
param spoke2VnetName string = 'vnet-spoke2-${environmentPrefix}-sea'
@description('Spoke 4 VNet name (West US)')
param spoke4VnetName string = 'vnet-spoke4-${environmentPrefix}-wus'
@description('Spoke 5 VNet name (West US)')
param spoke5VnetName string = 'vnet-spoke5-${environmentPrefix}-wus'

// Get existing VWAN Hubs
resource westUsHub 'Microsoft.Network/virtualHubs@2023-05-01' existing = {
  name: westUsHubName
}

resource southeastAsiaHub 'Microsoft.Network/virtualHubs@2023-05-01' existing = {
  name: southeastAsiaHubName
}

// Get existing VNets
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke1VnetName
}

resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke2VnetName
}

resource spoke4Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke4VnetName
}

resource spoke5Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke5VnetName
}

// Connect Spoke 1 to West US Hub
resource spoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  parent: westUsHub
  name: '${spoke1VnetName}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Vnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}

// Connect Spoke 2 to Southeast Asia Hub
resource spoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  parent: southeastAsiaHub
  name: '${spoke2VnetName}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: spoke2Vnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}

// Traditional VNet Peering: Spoke 4 ↔ Spoke 1 (bidirectional)
resource spoke4ToSpoke1Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: spoke4Vnet
  name: 'spoke4-to-spoke1'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource spoke1ToSpoke4Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: spoke1Vnet
  name: 'spoke1-to-spoke4'
  properties: {
    remoteVirtualNetwork: {
      id: spoke4Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// Traditional VNet Peering: Spoke 5 ↔ Spoke 1 (bidirectional)
resource spoke5ToSpoke1Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: spoke5Vnet
  name: 'spoke5-to-spoke1'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource spoke1ToSpoke5Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: spoke1Vnet
  name: 'spoke1-to-spoke5'
  properties: {
    remoteVirtualNetwork: {
      id: spoke5Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}// Outputs
output spoke1ConnectionId string = spoke1Connection.id
output spoke2ConnectionId string = spoke2Connection.id
output spoke4PeeringId string = spoke4ToSpoke1Peering.id
output spoke5PeeringId string = spoke5ToSpoke1Peering.id

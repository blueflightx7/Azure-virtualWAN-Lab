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

// Connect Spoke 4 to West US Hub
resource spoke4Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  parent: westUsHub
  name: '${spoke4VnetName}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: spoke4Vnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}

// Connect Spoke 5 to West US Hub  
resource spoke5Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  parent: westUsHub
  name: '${spoke5VnetName}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: spoke5Vnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}

// Outputs
output spoke1ConnectionId string = spoke1Connection.id
output spoke2ConnectionId string = spoke2Connection.id
output spoke4ConnectionId string = spoke4Connection.id
output spoke5ConnectionId string = spoke5Connection.id

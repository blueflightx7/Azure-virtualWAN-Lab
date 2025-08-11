// VWAN Hub connections for spoke VNets

@description('VWAN hub name')
param vwanHubName string

@description('First spoke VNet ID')
param spokeVnet1Id string

@description('Second spoke VNet ID')
param spokeVnet2Id string

@description('First spoke VNet name')
param spokeVnet1Name string

@description('Second spoke VNet name')
param spokeVnet2Name string

// Reference to existing VWAN hub
resource vwanHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: vwanHubName
}

// Connection for first spoke VNet (with NVA and ARS)
resource spokeVnet1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: vwanHub
  name: '${spokeVnet1Name}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet1Id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
      }
    }
  }
}

// Connection for second spoke VNet (direct connection)
resource spokeVnet2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: vwanHub
  name: '${spokeVnet2Name}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet2Id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
      }
    }
  }
}

// Output connection information
output spokeVnet1ConnectionId string = spokeVnet1Connection.id
output spokeVnet2ConnectionId string = spokeVnet2Connection.id

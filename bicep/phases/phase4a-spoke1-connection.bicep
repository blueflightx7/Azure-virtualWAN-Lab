// Phase 4a: Spoke1 VWAN Connection Only
// Deploy one connection at a time to avoid timeouts

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('VWAN hub name')
param vwanHubName string = '${environmentPrefix}-hub'

@description('First spoke VNet name')
param spokeVnet1Name string = '${environmentPrefix}-spoke1-vnet'

// Get existing resources
resource vwanHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: vwanHubName
}

resource spokeVnet1 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spokeVnet1Name
}

// Create spoke1 connection to VWAN hub
resource spoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: vwanHub
  name: '${spokeVnet1Name}-connection'
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: spokeVnet1.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        ids: [
          {
            id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
        labels: ['default']
      }
    }
  }
}

output connectionId string = spoke1Connection.id
output connectionState string = spoke1Connection.properties.provisioningState

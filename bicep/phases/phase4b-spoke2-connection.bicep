// Phase 4b: Spoke2 VWAN Connection Only
// Deploy second connection separately to avoid timeouts

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('VWAN hub name')
param vwanHubName string = '${environmentPrefix}-hub'

@description('Second spoke VNet name')
param spokeVnet2Name string = '${environmentPrefix}-spoke2-vnet'

// Get existing resources
resource vwanHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: vwanHubName
}

resource spokeVnet2 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spokeVnet2Name
}

// Create spoke2 connection to VWAN hub
resource spoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: vwanHub
  name: '${spokeVnet2Name}-connection'
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: spokeVnet2.id
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

output connectionId string = spoke2Connection.id
output connectionState string = spoke2Connection.properties.provisioningState

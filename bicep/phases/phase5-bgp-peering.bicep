// Phase 5: BGP Peering Configuration Between NVA and Route Server
// Establishes BGP peering for route exchange and redundancy

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('Local ASN for NVA BGP peering')
param nvaAsn int = 65001

// Get existing Route Server in Spoke 3
resource routeServer 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke3-route-server'
}

// Get NVA network interface to get private IP
resource nvaNic 'Microsoft.Network/networkInterfaces@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke1-nva-nic'
}

// Create BGP Connection from Route Server to NVA
// ✅ BEST PRACTICE: ASN 65001 is in private range (64512-65534)
// ✅ HIGH AVAILABILITY: NVA must peer with both Route Server IPs (10.3.0.4 and 10.3.0.5)
resource nvaBgpConnection 'Microsoft.Network/virtualHubs/bgpConnections@2024-05-01' = {
  parent: routeServer
  name: 'nva-bgp-peer'
  properties: {
    peerAsn: nvaAsn // ✅ 65001: Private ASN as per RFC 6996
    peerIp: nvaNic.properties.ipConfigurations[0].properties.privateIPAddress
  }
}

// Output BGP peering information
output bgpConnectionId string = nvaBgpConnection.id
output bgpConnectionName string = nvaBgpConnection.name
output nvaPeerIp string = nvaNic.properties.ipConfigurations[0].properties.privateIPAddress
output nvaPeerAsn int = nvaAsn
output routeServerAsn int = routeServer.properties.virtualRouterAsn
output routeServerIps array = routeServer.properties.virtualRouterIps

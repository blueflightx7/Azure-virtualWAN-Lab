// Phase 4: VPN Gateway Deployment
// Deploys VPN Gateway in Central US VWAN Hub for Spoke 3 connectivity

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('Central US region')
param centralUsRegion string = 'Central US'

@description('Central US VWAN Hub name')
param centralUsHubName string = 'vhub-${environmentPrefix}-cus'

@description('VPN Gateway name')
param vpnGatewayName string = 'vpngw-${environmentPrefix}-cus'

@description('VPN Gateway SKU')
param vpnGatewaySku string = 'VpnGw1'

@description('Spoke 3 VNet name for local network gateway')
param spoke3VnetName string = 'vnet-spoke3-${environmentPrefix}-cus'

@description('Spoke 3 address space for local network gateway')
param spoke3AddressSpace string = '10.16.1.0/26'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
}

// Get existing Central US VWAN Hub
resource centralUsHub 'Microsoft.Network/virtualHubs@2023-05-01' existing = {
  name: centralUsHubName
}

// Get existing Spoke 3 VNet 
resource spoke3Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke3VnetName
}

// Create VPN Gateway in VWAN Hub
resource vpnGateway 'Microsoft.Network/vpnGateways@2023-05-01' = {
  name: vpnGatewayName
  location: centralUsRegion
  tags: tags
  properties: {
    virtualHub: {
      id: centralUsHub.id
    }
    vpnGatewayScaleUnit: 1
    bgpSettings: {
      asn: 65515
      peerWeight: 0
    }
  }
}

// Create VPN Site for Spoke 3 RRAS connection
resource vpnSite 'Microsoft.Network/vpnSites@2023-05-01' = {
  name: '${environmentPrefix}-spoke3-vpnsite'
  location: centralUsRegion
  tags: tags
  properties: {
    virtualWan: {
      id: centralUsHub.properties.virtualWan.id
    }
    deviceProperties: {
      deviceVendor: 'Microsoft'
      deviceModel: 'RRAS'
      linkSpeedInMbps: 100
    }
    addressSpace: {
      addressPrefixes: [
        spoke3AddressSpace
      ]
    }
    bgpProperties: {
      asn: 65001
      peerWeight: 0
    }
    // Note: ipAddress will need to be updated with actual RRAS VM public IP after VM deployment
    ipAddress: '1.1.1.1' // Placeholder - will be updated in deployment script
  }
}

// Create VPN Connection
resource vpnConnection 'Microsoft.Network/vpnGateways/vpnConnections@2023-05-01' = {
  parent: vpnGateway
  name: '${environmentPrefix}-spoke3-vpnconnection'
  properties: {
    remoteVpnSite: {
      id: vpnSite.id
    }
    connectionBandwidth: 100
    enableBgp: true
    routingWeight: 0
    vpnConnectionProtocolType: 'IKEv2'
    vpnLinkConnections: [
      {
        name: 'link1'
        properties: {
          vpnSiteLink: {
            id: '${vpnSite.id}/vpnSiteLinks/link1'
          }
          sharedKey: 'VwanLabSharedKey123!'
          connectionBandwidth: 100
          enableBgp: true
        }
      }
    ]
  }
}

// Outputs
output vpnGatewayId string = vpnGateway.id
output vpnGatewayName string = vpnGateway.name
output vpnSiteId string = vpnSite.id
output vpnConnectionId string = vpnConnection.id
output sharedKey string = vpnConnection.properties.sharedKey

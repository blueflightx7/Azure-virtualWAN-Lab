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

@description('Spoke 3 address space for local network gateway - corrected to Central US allocation')
param spoke3AddressSpace string = '10.16.1.0/25'

@description('RRAS VM public IP address for VPN site configuration')
param rrasVmPublicIp string = '172.202.20.234' // Will be provided during deployment

@description('RRAS VM private IP address for BGP peering')
param rrasVmPrivateIp string = '10.16.1.4' // Default subnet assignment

@description('BGP ASN for RRAS VM (private ASN range)')
param rrasBgpAsn int = 65001

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
}

// Get existing Central US VWAN Hub
resource centralUsHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: centralUsHubName
}

// Create VPN Gateway in VWAN Hub
resource vpnGateway 'Microsoft.Network/vpnGateways@2024-05-01' = {
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
resource vpnSite 'Microsoft.Network/vpnSites@2024-05-01' = {
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
    vpnSiteLinks: [
      {
        name: 'link1'
        properties: {
          ipAddress: rrasVmPublicIp // RRAS VM public IP
          linkProperties: {
            linkProviderName: 'Microsoft'
            linkSpeedInMbps: 100
          }
          bgpProperties: {
            asn: rrasBgpAsn
            bgpPeeringAddress: rrasVmPrivateIp
          }
        }
      }
    ]
    // Note: ipAddress will need to be updated with actual RRAS VM public IP after VM deployment
  }
}

// Create VPN Connection
resource vpnConnection 'Microsoft.Network/vpnGateways/vpnConnections@2024-05-01' = {
  parent: vpnGateway
  name: '${environmentPrefix}-spoke3-vpnconnection'
  properties: {
    remoteVpnSite: {
      id: vpnSite.id
    }
    routingWeight: 0
    vpnConnectionProtocolType: 'IKEv2'
    vpnLinkConnections: [
      {
        name: 'link1'
        properties: {
          vpnSiteLink: {
            id: '${vpnSite.id}/vpnSiteLinks/link1'
          }
          sharedKey: 'VwanLabSharedKey123!' // Pre-shared key for RRAS configuration
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
output vpnSiteLinkId string = '${vpnSite.id}/vpnSiteLinks/link1'

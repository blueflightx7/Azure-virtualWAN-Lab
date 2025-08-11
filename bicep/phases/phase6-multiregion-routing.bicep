// Phase 6: Multi-Region Routing Configuration
// Creates static routes and User Defined Routes for traffic steering

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

// VNet Names for route tables
@description('Spoke 4 VNet name (West US)')
param spoke4VnetName string = 'vnet-spoke4-${environmentPrefix}-wus'
@description('Spoke 5 VNet name (West US)')
param spoke5VnetName string = 'vnet-spoke5-${environmentPrefix}-wus'

// Azure Firewall private IP (from Phase 3 output)
@description('Azure Firewall private IP address')
param azureFirewallPrivateIp string

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
}

// Get existing VNets
resource spoke4Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke4VnetName
}

resource spoke5Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke5VnetName
}

// Create Route Table for Spoke 4 (default route to Azure Firewall)
resource spoke4RouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: '${environmentPrefix}-spoke4-rt'
  location: resourceGroup().location
  tags: tags
  properties: {
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
      {
        name: 'Spoke1ToFirewall'
        properties: {
          addressPrefix: '10.0.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
      {
        name: 'Spoke5ToFirewall'
        properties: {
          addressPrefix: '10.0.3.0/26'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
    ]
    disableBgpRoutePropagation: false
  }
}

// Create Route Table for Spoke 5 (default route to Azure Firewall)
resource spoke5RouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: '${environmentPrefix}-spoke5-rt'
  location: resourceGroup().location
  tags: tags
  properties: {
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
      {
        name: 'Spoke1ToFirewall'
        properties: {
          addressPrefix: '10.0.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
      {
        name: 'Spoke4ToFirewall'
        properties: {
          addressPrefix: '10.0.2.0/26'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
    ]
    disableBgpRoutePropagation: false
  }
}

// Associate Route Table with Spoke 4 VM Subnet
resource spoke4SubnetRouteAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spoke4Vnet
  name: 'VmSubnet'
  properties: {
    addressPrefix: '10.0.2.0/27' // First half of /26
    routeTable: {
      id: spoke4RouteTable.id
    }
  }
}

// Associate Route Table with Spoke 5 VM Subnet
resource spoke5SubnetRouteAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spoke5Vnet
  name: 'VmSubnet'
  properties: {
    addressPrefix: '10.0.3.0/27' // First half of /26
    routeTable: {
      id: spoke5RouteTable.id
    }
  }
}

// Outputs
output spoke4RouteTableId string = spoke4RouteTable.id
output spoke5RouteTableId string = spoke5RouteTable.id

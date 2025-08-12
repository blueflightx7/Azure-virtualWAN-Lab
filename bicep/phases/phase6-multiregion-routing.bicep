// Phase 6: Multi-Region Routing Configuration
// Creates static routes, UDRs, and VWAN hub route advertisements

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

// Hub Names
@description('West US VWAN Hub name')
param westUsHubName string = 'vhub-${environmentPrefix}-wus'
@description('Central US VWAN Hub name')
param centralUsHubName string = 'vhub-${environmentPrefix}-cus'
@description('Southeast Asia VWAN Hub name')
param southeastAsiaHubName string = 'vhub-${environmentPrefix}-sea'

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

// Get existing VWAN Hubs for route table configuration
resource westUsHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: westUsHubName
}

resource centralUsHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: centralUsHubName
}

resource southeastAsiaHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: southeastAsiaHubName
}

// Get existing VNets
resource spoke4Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke4VnetName
}

resource spoke5Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke5VnetName
}

// ============================================================================
// VWAN Hub Route Tables - Advertise Regional /12 Networks
// ============================================================================

// West US Hub Route Table - Advertise 10.0.0.0/12 to connected spokes
resource westUsHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: westUsHub
  name: 'westUsRegionalRoutes'
  properties: {
    labels: [
      'westus-regional'
    ]
    routes: [
      {
        name: 'WestUsRegionalSummary'
        destinationType: 'CIDR'
        destinations: [
          '10.0.0.0/12'  // Advertise entire West US regional block
        ]
        nextHopType: 'IPAddress'
        nextHop: '10.0.1.4'  // Next hop to Spoke 1 (firewall subnet)
      }
    ]
  }
}

// Central US Hub Route Table - Advertise 10.16.0.0/12 to connected spokes  
resource centralUsHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: centralUsHub
  name: 'centralUsRegionalRoutes'
  properties: {
    labels: [
      'centralus-regional'
    ]
    routes: [
      {
        name: 'CentralUsRegionalSummary'
        destinationType: 'CIDR'
        destinations: [
          '10.16.0.0/12'  // Advertise entire Central US regional block
        ]
        nextHopType: 'IPAddress'
        nextHop: '10.16.1.4'  // Next hop to Spoke 3 RRAS VM
      }
    ]
  }
}

// Southeast Asia Hub Route Table - Advertise 10.32.0.0/12 to connected spokes
resource southeastAsiaHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: southeastAsiaHub
  name: 'southeastAsiaRegionalRoutes'
  properties: {
    labels: [
      'southeastasia-regional'
    ]
    routes: [
      {
        name: 'SoutheastAsiaRegionalSummary'
        destinationType: 'CIDR'
        destinations: [
          '10.32.0.0/12'  // Advertise entire Southeast Asia regional block
        ]
        nextHopType: 'IPAddress'  
        nextHop: '10.32.1.4'  // Next hop to Spoke 2
      }
    ]
  }
}

// ============================================================================
// User Defined Routes (UDRs) for Spoke VNets
// ============================================================================

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
output westUsHubRouteTableId string = westUsHubRouteTable.id
output centralUsHubRouteTableId string = centralUsHubRouteTable.id
output southeastAsiaHubRouteTableId string = southeastAsiaHubRouteTable.id

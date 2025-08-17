// Phase 6: Multi-Region Routing Configuration
// Creates static routes, UDRs, and VWAN hub route advertisements
// Note: This phase is optional - basic connectivity is already working from Phases 1-5
// VWAN provides automatic routing between hubs and spokes

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

// ============================================================================
// VWAN Hub Route Tables - Custom Route Tables for Advanced Routing
// ============================================================================
// Note: Default route table modifications are handled via PowerShell deployment script
// This template creates custom route tables for optional advanced routing policies

// West US Hub Custom Route Table
resource westUsHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: westUsHub
  name: 'westUsRegionalRoutes'
  properties: {
    labels: [
      'westus-regional'
    ]
    routes: [
      // Custom routing policies would go here
      // Default route table regional summary (10.0.0.0/12) added via PowerShell
    ]
  }
}

// Central US Hub Custom Route Table
resource centralUsHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: centralUsHub
  name: 'centralUsRegionalRoutes'
  properties: {
    labels: [
      'centralus-regional'
    ]
    routes: [
      // Custom routing policies would go here
      // VPN Gateway handles BGP advertisements automatically
    ]
  }
}

// Southeast Asia Hub Custom Route Table
resource southeastAsiaHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: southeastAsiaHub
  name: 'southeastAsiaRegionalRoutes'
  properties: {
    labels: [
      'southeastasia-regional'
    ]
    routes: [
      // Custom routing policies would go here
      // VWAN handles automatic routing for connected networks
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

// Note: Route table association with existing subnets containing VMs
// requires the VMs to be stopped or the association done via Azure CLI/PowerShell
// For now, we'll create the route tables but skip automatic association

// Outputs
output spoke4RouteTableId string = spoke4RouteTable.id
output spoke5RouteTableId string = spoke5RouteTable.id
output westUsHubRouteTableId string = westUsHubRouteTable.id
output centralUsHubRouteTableId string = centralUsHubRouteTable.id
output southeastAsiaHubRouteTableId string = southeastAsiaHubRouteTable.id

// Manual association commands (run after deployment):
// az network vnet subnet update --resource-group rg-vwanlab --vnet-name vnet-spoke4-vwanlab-wus --name VmSubnet --route-table vwanlab-spoke4-rt
// az network vnet subnet update --resource-group rg-vwanlab --vnet-name vnet-spoke5-vwanlab-wus --name VmSubnet --route-table vwanlab-spoke5-rt

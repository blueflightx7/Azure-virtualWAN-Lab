// Multi-Region Azure VWAN Lab Configuration
// Updated architecture with Azure Firewall, VPN connectivity, and expanded spoke topology

using '../phases/phase1-multiregion-core.bicep'      // Core infrastructure (default)
// using '../phases/phase2-multiregion-vms.bicep'       // Virtual machines  
// using '../phases/phase3-multiregion-firewall.bicep'  // Azure Firewall
// using '../phases/phase4-multiregion-vpn.bicep'       // VPN Gateway
// using '../phases/phase5-multiregion-connections.bicep' // VWAN connections
// using '../phases/phase6-multiregion-routing.bicep'   // Static routes & BGP

// 🚨 IMPORTANT: This parameter file contains parameters for ALL phases
// 🚨 NOTE: Only uncomment the 'using' line for the phase you want to deploy
// 🚨 RECOMMENDATION: Use Deploy-VwanLab.ps1 which handles parameters dynamically

// Environment Configuration
param environmentPrefix = 'vwanlab'

// Multi-Region VWAN Configuration  
param vwanName = 'vwan-${environmentPrefix}'

// VWAN Hub Configuration - 3 Hubs with dedicated infrastructure addressing
param westUsHubName = 'vhub-${environmentPrefix}-wus'
param westUsHubAddressPrefix = '10.200.0.0/24'    // Hub infrastructure only (NOT regional traffic)
param westUsRegion = 'West US'

param centralUsHubName = 'vhub-${environmentPrefix}-cus'  
param centralUsHubAddressPrefix = '10.201.0.0/24'  // Hub infrastructure only (NOT regional traffic)
param centralUsRegion = 'Central US'

param southeastAsiaHubName = 'vhub-${environmentPrefix}-sea'
param southeastAsiaHubAddressPrefix = '10.202.0.0/24'  // Hub infrastructure only (NOT regional traffic)
param southeastAsiaRegion = 'Southeast Asia'

// Regional Network Allocations (for spokes and route advertisements):
// West US Region: 10.0.0.0/12 (spokes: 10.0.1.0/24, 10.0.2.0/26, 10.0.3.0/26)
// Central US Region: 10.16.0.0/12 (spokes: 10.16.1.0/25)
// Southeast Asia Region: 10.32.0.0/12 (spokes: 10.32.1.0/26)
// Hub Infrastructure: 10.200.0.0/22 (hubs: 10.200.0.0/24, 10.201.0.0/24, 10.202.0.0/24)

// Spoke VNet Configuration
// Spoke 1 (West US) - Azure Firewall Hub - 3x /26 subnets
param spoke1VnetName = 'vnet-spoke1-${environmentPrefix}-wus'
param spoke1VnetAddressSpace = '10.0.1.0/24'  // Room for 3x /26 subnets
param spoke1VmSubnet = '10.0.1.0/26'         // VMs subnet
param spoke1FirewallSubnet = '10.0.1.64/26'  // AzureFirewallSubnet
param spoke1ManagementSubnet = '10.0.1.128/26' // Management subnet

// Spoke 2 (Southeast Asia) - Direct VWAN connection
param spoke2VnetName = 'vnet-spoke2-${environmentPrefix}-sea'
param spoke2VnetAddressSpace = '10.32.1.0/26'

// Spoke 3 (Central US) - VPN connection via RRAS
param spoke3VnetName = 'vnet-spoke3-${environmentPrefix}-cus'
param spoke3VnetAddressSpace = '10.16.1.0/25'

// Spoke 4 (West US) - Routes to Spoke 1 Firewall
param spoke4VnetName = 'vnet-spoke4-${environmentPrefix}-wus'
param spoke4VnetAddressSpace = '10.0.2.0/26'

// Spoke 5 (West US) - Routes to Spoke 1 Firewall  
param spoke5VnetName = 'vnet-spoke5-${environmentPrefix}-wus'
param spoke5VnetAddressSpace = '10.0.3.0/26'

// Tags - Multi-Region Architecture
param tags = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
  Owner: 'DevOps'
  LastUpdated: '2025-08-11'
  Architecture: 'Multi-Region-VWAN-Firewall-VPN'
  Purpose: 'BGP-Firewall-VPN-Connectivity-Testing'
  CostProfile: 'Premium-Multi-Region'
  Regions: 'WestUS-CentralUS-SoutheastAsia'
  Version: 'v2.0-MultiRegion'
}

// Security Configuration (optional)
param deployerPublicIP = '' // Your public IP for RDP access

// ==================================================================================
// PHASE-SPECIFIC PARAMETERS (uncomment when deploying specific phases)
// ==================================================================================

// PHASE 2 PARAMETERS - Virtual Machines
// param adminUsername = 'azureuser'
// param linuxVmSize = 'Standard_B1s'     // Low spec for Linux VMs
// param windowsVmSize = 'Standard_B2s'   // 2 core 4GB for Windows VM

// PHASE 3 PARAMETERS - Azure Firewall
// param firewallName = 'afw-${environmentPrefix}-wus'
// param firewallPolicyName = 'afwp-${environmentPrefix}-wus'
// param firewallSku = 'Premium'  // Premium SKU for all features

// PHASE 4 PARAMETERS - VPN Gateway
// param vpnGatewayName = 'vpngw-${environmentPrefix}-cus'
// param vpnGatewaySku = 'VpnGw1'

// PHASE 6 PARAMETERS - Routing Configuration
// param azureFirewallPrivateIp = '10.0.1.68'  // Set from Phase 3 output

// ==================================================================================
// Multi-Region Architecture Notes:
// - West US Hub: Spoke 1 (Firewall), Spoke 4, Spoke 5
// - Central US Hub: Spoke 3 (VPN connection)
// - Southeast Asia Hub: Spoke 2 (Direct connection)
// - Spoke 4 & 5 default route to Azure Firewall in Spoke 1
// - Spoke 3 connects via IPSec VPN tunnel
// - Use Deploy-VwanLab.ps1 for automated deployment with proper parameter handling
// ==================================================================================

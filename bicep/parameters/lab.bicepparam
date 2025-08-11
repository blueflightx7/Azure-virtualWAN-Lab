// For phased deployment use phase-specific templates:
using '../phases/phase1-core.bicep'      // Core infrastructure (default)
// using '../phases/phase2-vms.bicep'       // Virtual machines  
// using '../phases/phase3-routeserver.bicep' // Route Server
// using '../phases/phase4a-spoke1-connection.bicep' // VWAN connections
// using '../phases/phase5-bgp-peering.bicep' // BGP peering

// 🚨 IMPORTANT: Deploy-VwanLab.ps1 builds parameters dynamically - this file is for manual deployment reference only
// 🚨 NOTE: main.bicep is empty - uncomment appropriate phase template above for manual deployment

// Environment Configuration
param environmentPrefix = 'vwanlab'
param primaryRegion = 'East US'

// Virtual WAN Configuration
param vwanName = 'vwan-${environmentPrefix}'
param vwanHubName = 'vhub-${environmentPrefix}'
param vwanHubAddressPrefix = '10.0.0.0/16'

// Spoke VNet Configuration  
param spokeVnet1Name = 'vnet-spoke1-${environmentPrefix}'
param spokeVnet1AddressSpace = '10.1.0.0/16'
param spokeVnet2Name = 'vnet-spoke2-${environmentPrefix}'
param spokeVnet2AddressSpace = '10.2.0.0/16'

// Spoke 3 Configuration (Azure Route Server)
param spoke3VnetName = 'vnet-spoke3-${environmentPrefix}'
param spoke3VnetAddressSpace = '10.3.0.0/16'

// Tags - UPDATED FOR 2025 PRICING
param tags = {
  Environment: 'Demo-Optimized'
  Project: 'VWAN-BGP-Demo'
  CreatedBy: 'Bicep'
  Owner: 'DevOps'
  LastUpdated: '2025-01-27'
  Architecture: 'NVA-RouteServer-VWAN-Topology'
  Purpose: 'BGP-Peering-Connectivity-Testing'
  CostProfile: 'Optimized-Mixed-VMs'
  EstimatedMonthlyCost: '$506'
  PricingYear: '2025'
}

// Security Configuration (optional)
param deployerPublicIP = '' // Your public IP for RDP access

// ==================================================================================
// REMOVED PARAMETERS (not used in phase1-core.bicep):
// These parameters are used in other phases and built dynamically by Deploy-VwanLab.ps1:
//
// Phase 2 (VMs): adminUsername, adminPassword, vmSize, deployNvaVm, deployTestVm
// Phase 3 (Route Server): adminUsername, adminPassword, vmSize, deployTestVm  
// Phase 5 (BGP): nvaAsn
//
// For manual deployment of other phases, uncomment the appropriate 'using' statement above
// ==================================================================================

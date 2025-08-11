// Phase 2: VM Deployment Parameters
// Use this for manual deployment of phase2-vms.bicep
using '../phases/phase2-vms.bicep'

// Environment Configuration
param environmentPrefix = 'vwanlab'
param primaryRegion = 'East US'

// VM Credentials (required for VM creation)
param adminUsername = 'azureuser'
param adminPassword = 'ComplexP@ssw0rd2025!' // Change this for production

// VM Deployment Control (set to false if VMs already exist)
param deployNvaVm = true  // Deploy NVA VM in Spoke1
param deployTestVm = true // Deploy Test VM in Spoke2

// VM Configuration - PERFORMANCE OPTIMIZED
param vmSize = 'Standard_B2s' // 2 GB RAM for RRAS/BGP operations

// Tags
param tags = {
  Environment: 'Demo-Optimized'
  Project: 'VWAN-BGP-Demo'
  CreatedBy: 'Bicep'
  Purpose: 'VM-Deployment-Phase'
}

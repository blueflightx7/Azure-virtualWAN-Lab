// Phase 3: Route Server Parameters  
// Use this for manual deployment of phase3-routeserver.bicep
using '../phases/phase3-routeserver.bicep'

// Environment Configuration
param environmentPrefix = 'vwanlab'
param location = 'East US'

// VM Credentials (required if deployTestVm = true)
param adminUsername = 'azureuser'
param adminPassword = 'ComplexP@ssw0rd2025!' // Change this for production

// VM Deployment Control
param deployTestVm = true // Deploy Test VM in Spoke3 (Route Server VNet)

// VM Configuration
param vmSize = 'Standard_B2s' // 2 GB RAM for better performance

// Security Configuration
param deployerPublicIP = '' // Your public IP for RDP access

// Tags
param tags = {
  Environment: 'Lab'
  Project: 'VWAN-Demo'
  Purpose: 'Route-Server-BGP-Integration'
}

// Phase 1: Core Infrastructure (VWAN, VNets)
// This phase deploys the foundation without timeouts

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('Primary region for VWAN hub')
param primaryRegion string = 'East US'

@description('Virtual WAN name')
param vwanName string = '${environmentPrefix}-vwan'

@description('VWAN hub name')
param vwanHubName string = '${environmentPrefix}-hub'

@description('VWAN hub address prefix')
param vwanHubAddressPrefix string = '10.0.0.0/16'

@description('First spoke VNet name (with NVA)')
param spokeVnet1Name string = '${environmentPrefix}-spoke1-vnet'

@description('First spoke VNet address space')
param spokeVnet1AddressSpace string = '10.1.0.0/16'

@description('Second spoke VNet name (direct VWAN connection)')
param spokeVnet2Name string = '${environmentPrefix}-spoke2-vnet'

@description('Second spoke VNet address space')
param spokeVnet2AddressSpace string = '10.2.0.0/16'

@description('Spoke 3 VNet name (Azure Route Server)')
param spoke3VnetName string = '${environmentPrefix}-spoke3-vnet'

@description('Spoke 3 VNet address space')
param spoke3VnetAddressSpace string = '10.3.0.0/16'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab'
  Project: 'VWAN-BGP-Lab'
  CreatedBy: 'Bicep'
}

@description('Deployer public IP for RDP access (optional)')
param deployerPublicIP string = ''

// Deploy Virtual WAN
module vwan '../modules/vwan.bicep' = {
  name: 'vwan-deployment'
  params: {
    vwanName: vwanName
    vwanHubName: vwanHubName
    vwanHubAddressPrefix: vwanHubAddressPrefix
    location: primaryRegion
    tags: tags
  }
}

// Deploy VNets only (no VMs, no Route Server)
module spokeVnet1 '../modules/spoke-vnet-infrastructure-only.bicep' = {
  name: 'spoke-vnet1-infrastructure'
  params: {
    vnetName: spokeVnet1Name
    vnetAddressSpace: spokeVnet1AddressSpace
    location: primaryRegion
    environmentPrefix: environmentPrefix
    includeNvaSubnet: true
    includeRouteServerSubnet: false
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

module spokeVnet2 '../modules/spoke-vnet-infrastructure-only.bicep' = {
  name: 'spoke-vnet2-infrastructure'
  params: {
    vnetName: spokeVnet2Name
    vnetAddressSpace: spokeVnet2AddressSpace
    location: primaryRegion
    environmentPrefix: environmentPrefix
    includeNvaSubnet: false
    includeRouteServerSubnet: false
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

module spoke3Vnet '../modules/spoke-vnet-infrastructure-only.bicep' = {
  name: 'spoke3-vnet-infrastructure'
  params: {
    vnetName: spoke3VnetName
    vnetAddressSpace: spoke3VnetAddressSpace
    location: primaryRegion
    environmentPrefix: environmentPrefix
    includeNvaSubnet: false
    includeRouteServerSubnet: true
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

// Outputs
output vwanId string = vwan.outputs.vwanId
output vwanHubId string = vwan.outputs.vwanHubId
output spokeVnet1Id string = spokeVnet1.outputs.vnetId
output spokeVnet2Id string = spokeVnet2.outputs.vnetId
output spoke3VnetId string = spoke3Vnet.outputs.vnetId

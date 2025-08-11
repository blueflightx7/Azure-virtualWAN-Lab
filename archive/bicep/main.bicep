// Main Bicep template for Azure Virtual WAN lab environment
// This template deploys a comprehensive VWAN lab with BGP peering, NVA, and Azure Route Server

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

@description('First spoke VNet name (with NVA and ARS)')
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

@description('Admin username for VMs')
param adminUsername string

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VM size for NVA VM (minimum Standard_B2s for RRAS)')
param nvaVmSize string = 'Standard_B2s'

@description('VM size for test VMs')
param testVmSize string = 'Standard_B1s'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab'
  Project: 'VWAN-BGP-Lab'
  CreatedBy: 'Bicep'
}

// Deploy Virtual WAN
module vwan 'modules/vwan.bicep' = {
  name: 'vwan-deployment'
  params: {
    vwanName: vwanName
    vwanHubName: vwanHubName
    vwanHubAddressPrefix: vwanHubAddressPrefix
    location: primaryRegion
    tags: tags
  }
}

// Deploy first spoke VNet with NVA (no Route Server - that goes in spoke3)
module spokeVnet1 'modules/spoke-vnet-with-nva.bicep' = {
  name: 'spoke-vnet1-deployment'
  params: {
    vnetName: spokeVnet1Name
    vnetAddressSpace: spokeVnet1AddressSpace
    location: primaryRegion
    adminUsername: adminUsername
    adminPassword: adminPassword
    nvmVmSize: nvaVmSize
    testVmSize: testVmSize
    environmentPrefix: environmentPrefix
    tags: tags
  }
}

// Deploy second spoke VNet (direct VWAN connection)
module spokeVnet2 'modules/spoke-vnet-direct.bicep' = {
  name: 'spoke-vnet2-deployment'
  params: {
    vnetName: spokeVnet2Name
    vnetAddressSpace: spokeVnet2AddressSpace
    location: primaryRegion
    adminUsername: adminUsername
    adminPassword: adminPassword
    testVmSize: testVmSize
    environmentPrefix: environmentPrefix
    tags: tags
  }
}

// Deploy Spoke 3 VNet (Azure Route Server)
module spoke3 'modules/spoke-vnet-route-server.bicep' = {
  name: 'spoke3-deployment'
  params: {
    vnetName: spoke3VnetName
    vnetAddressSpace: spoke3VnetAddressSpace
    location: primaryRegion
    adminUsername: adminUsername
    adminPassword: adminPassword
    testVmSize: testVmSize
    environmentPrefix: environmentPrefix
    tags: tags
  }
}

// Connect spoke VNets to VWAN hub (spoke1 and spoke2 only - Route Server spoke stays separate)
module vnetConnections 'modules/vwan-connections.bicep' = {
  name: 'vnet-connections-deployment'
  params: {
    vwanHubName: vwanHubName
    spokeVnet1Id: spokeVnet1.outputs.vnetId
    spokeVnet2Id: spokeVnet2.outputs.vnetId
    spokeVnet1Name: spokeVnet1Name
    spokeVnet2Name: spokeVnet2Name
  }
  dependsOn: [
    vwan
  ]
}

// VNet Peering between NVA spoke (spoke1) and Spoke 3 for BGP peering
module nvaToSpoke3Peering 'modules/vnet-peering.bicep' = {
  name: 'nva-to-spoke3-peering'
  params: {
    vnet1Name: spokeVnet1Name
    vnet1Id: spokeVnet1.outputs.vnetId
    vnet2Name: spoke3VnetName
    vnet2Id: spoke3.outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// Outputs
output vwanId string = vwan.outputs.vwanId
output vwanHubId string = vwan.outputs.vwanHubId
output spokeVnet1Id string = spokeVnet1.outputs.vnetId
output spokeVnet2Id string = spokeVnet2.outputs.vnetId
output spoke3VnetId string = spoke3.outputs.vnetId
output nvaVmName string = spokeVnet1.outputs.nvaVmName
output testVmSpoke1Name string = spokeVnet1.outputs.testVmName
output testVmSpoke2Name string = spokeVnet2.outputs.testVmName
output testVmSpoke3Name string = spoke3.outputs.testVmName
output spoke3RouteServerId string = spoke3.outputs.routeServerId
output spoke3RouteServerIpAddress string = spoke3.outputs.routeServerIpAddress

// Phase 1: Multi-Region Core Infrastructure
// Deploys 3 VWAN hubs and 5 spoke VNets across multiple regions

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

// VWAN Configuration
@description('Virtual WAN name')
param vwanName string = '${environmentPrefix}-vwan'

// West US Hub Configuration
@description('West US VWAN hub name')
param westUsHubName string = 'vhub-${environmentPrefix}-wus'
@description('West US VWAN hub address prefix - dedicated hub infrastructure range (outside regional /12)')
param westUsHubAddressPrefix string = '10.200.0.0/24'
@description('West US region')
param westUsRegion string = 'West US'

// Central US Hub Configuration  
@description('Central US VWAN hub name')
param centralUsHubName string = 'vhub-${environmentPrefix}-cus'
@description('Central US VWAN hub address prefix - dedicated hub infrastructure range (outside regional /12)')
param centralUsHubAddressPrefix string = '10.201.0.0/24'
@description('Central US region')
param centralUsRegion string = 'Central US'

// Southeast Asia Hub Configuration
@description('Southeast Asia VWAN hub name')
param southeastAsiaHubName string = 'vhub-${environmentPrefix}-sea'
@description('Southeast Asia VWAN hub address prefix - dedicated hub infrastructure range (outside regional /12)')
param southeastAsiaHubAddressPrefix string = '10.202.0.0/24'
@description('Southeast Asia region')
param southeastAsiaRegion string = 'Southeast Asia'

// Regional Network Allocations (for route advertisements and spoke deployments)
// West US Region: 10.0.0.0/12 (10.0.0.0 - 10.15.255.255) - spokes and route advertisements
// Central US Region: 10.16.0.0/12 (10.16.0.0 - 10.31.255.255) - spokes and route advertisements
// Southeast Asia Region: 10.32.0.0/12 (10.32.0.0 - 10.47.255.255) - spokes and route advertisements
// Hub Infrastructure: 10.200.0.0/22 (10.200.0.0 - 10.203.255.255) - VWAN hubs only

// Spoke 1 Configuration (West US) - Azure Firewall Hub
@description('Spoke 1 VNet name')
param spoke1VnetName string = 'vnet-spoke1-${environmentPrefix}-wus'
@description('Spoke 1 VNet address space')
param spoke1VnetAddressSpace string = '10.0.1.0/24'
@description('Spoke 1 VM subnet')
param spoke1VmSubnet string = '10.0.1.0/26'
@description('Spoke 1 Firewall subnet')
param spoke1FirewallSubnet string = '10.0.1.64/26'
@description('Spoke 1 Management subnet')
param spoke1ManagementSubnet string = '10.0.1.128/26'

// Spoke 2 Configuration (Southeast Asia)
@description('Spoke 2 VNet name')
param spoke2VnetName string = 'vnet-spoke2-${environmentPrefix}-sea'
@description('Spoke 2 VNet address space')
param spoke2VnetAddressSpace string = '10.32.1.0/26'

// Spoke 3 Configuration (Central US)
@description('Spoke 3 VNet name')
param spoke3VnetName string = 'vnet-spoke3-${environmentPrefix}-cus'
@description('Spoke 3 VNet address space - within Central US 10.16.0.0/12 allocation')
param spoke3VnetAddressSpace string = '10.16.1.0/25'

// Spoke 4 Configuration (West US)
@description('Spoke 4 VNet name')
param spoke4VnetName string = 'vnet-spoke4-${environmentPrefix}-wus'
@description('Spoke 4 VNet address space')
param spoke4VnetAddressSpace string = '10.0.2.0/26'

// Spoke 5 Configuration (West US)
@description('Spoke 5 VNet name')
param spoke5VnetName string = 'vnet-spoke5-${environmentPrefix}-wus'
@description('Spoke 5 VNet address space')
param spoke5VnetAddressSpace string = '10.0.3.0/26'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
}

@description('Deployer public IP for RDP access (optional)')
param deployerPublicIP string = ''

// Deploy Virtual WAN
resource vwan 'Microsoft.Network/virtualWans@2023-05-01' = {
  name: vwanName
  location: westUsRegion  // Primary region
  tags: tags
  properties: {
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

// Deploy West US VWAN Hub
resource westUsHub 'Microsoft.Network/virtualHubs@2023-05-01' = {
  name: westUsHubName
  location: westUsRegion
  tags: tags
  properties: {
    addressPrefix: westUsHubAddressPrefix
    virtualWan: {
      id: vwan.id
    }
  }
}

// Deploy Central US VWAN Hub
resource centralUsHub 'Microsoft.Network/virtualHubs@2023-05-01' = {
  name: centralUsHubName
  location: centralUsRegion
  tags: tags
  properties: {
    addressPrefix: centralUsHubAddressPrefix
    virtualWan: {
      id: vwan.id
    }
  }
}

// Deploy Southeast Asia VWAN Hub
resource southeastAsiaHub 'Microsoft.Network/virtualHubs@2023-05-01' = {
  name: southeastAsiaHubName
  location: southeastAsiaRegion
  tags: tags
  properties: {
    addressPrefix: southeastAsiaHubAddressPrefix
    virtualWan: {
      id: vwan.id
    }
  }
}

// Deploy Spoke 1 VNet (West US) - Azure Firewall Hub
module spoke1Vnet '../modules/spoke-vnet-multisubnet.bicep' = {
  name: 'spoke1-vnet-deployment'
  params: {
    vnetName: spoke1VnetName
    vnetAddressSpace: spoke1VnetAddressSpace
    location: westUsRegion
    environmentPrefix: environmentPrefix
    vmSubnet: spoke1VmSubnet
    firewallSubnet: spoke1FirewallSubnet
    managementSubnet: spoke1ManagementSubnet
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

// Deploy Spoke 2 VNet (Southeast Asia)
module spoke2Vnet '../modules/spoke-vnet-simple.bicep' = {
  name: 'spoke2-vnet-deployment'
  params: {
    vnetName: spoke2VnetName
    vnetAddressSpace: spoke2VnetAddressSpace
    location: southeastAsiaRegion
    environmentPrefix: environmentPrefix
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

// Deploy Spoke 3 VNet (Central US) - VPN Connection
module spoke3Vnet '../modules/spoke-vnet-simple.bicep' = {
  name: 'spoke3-vnet-deployment'
  params: {
    vnetName: spoke3VnetName
    vnetAddressSpace: spoke3VnetAddressSpace
    location: centralUsRegion
    environmentPrefix: environmentPrefix
    deployerPublicIP: deployerPublicIP
    includeGatewaySubnet: true  // For VPN connection
    tags: tags
  }
}

// Deploy Spoke 4 VNet (West US)
module spoke4Vnet '../modules/spoke-vnet-simple.bicep' = {
  name: 'spoke4-vnet-deployment'
  params: {
    vnetName: spoke4VnetName
    vnetAddressSpace: spoke4VnetAddressSpace
    location: westUsRegion
    environmentPrefix: environmentPrefix
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

// Deploy Spoke 5 VNet (West US)
module spoke5Vnet '../modules/spoke-vnet-simple.bicep' = {
  name: 'spoke5-vnet-deployment'
  params: {
    vnetName: spoke5VnetName
    vnetAddressSpace: spoke5VnetAddressSpace
    location: westUsRegion
    environmentPrefix: environmentPrefix
    deployerPublicIP: deployerPublicIP
    tags: tags
  }
}

// Outputs
output vwanId string = vwan.id
output westUsHubId string = westUsHub.id
output centralUsHubId string = centralUsHub.id
output southeastAsiaHubId string = southeastAsiaHub.id
output spoke1VnetId string = spoke1Vnet.outputs.vnetId
output spoke2VnetId string = spoke2Vnet.outputs.vnetId
output spoke3VnetId string = spoke3Vnet.outputs.vnetId
output spoke4VnetId string = spoke4Vnet.outputs.vnetId
output spoke5VnetId string = spoke5Vnet.outputs.vnetId

// Hub BGP Information (for reference)
output westUsHubBgpAddress string = westUsHub.properties.virtualRouterAsn != null ? '${westUsHub.properties.virtualRouterIps[0]}, ${westUsHub.properties.virtualRouterIps[1]}' : 'Not Available'
output centralUsHubBgpAddress string = centralUsHub.properties.virtualRouterAsn != null ? '${centralUsHub.properties.virtualRouterIps[0]}, ${centralUsHub.properties.virtualRouterIps[1]}' : 'Not Available'
output southeastAsiaHubBgpAddress string = southeastAsiaHub.properties.virtualRouterAsn != null ? '${southeastAsiaHub.properties.virtualRouterIps[0]}, ${southeastAsiaHub.properties.virtualRouterIps[1]}' : 'Not Available'

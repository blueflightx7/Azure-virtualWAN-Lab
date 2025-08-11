// Simple Spoke VNet with single subnet
// Used for Spoke 2, 4, and 5 (basic VM deployment)

@description('VNet name')
param vnetName string

@description('VNet address space')
param vnetAddressSpace string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Environment prefix for naming')
param environmentPrefix string

@description('Include Gateway subnet for VPN connection')
param includeGatewaySubnet bool = false

@description('Tags to apply to resources')
param tags object

@description('Deployer public IP for RDP access (optional)')
param deployerPublicIP string = ''

// Calculate subnet prefixes
var addressParts = split(vnetAddressSpace, '/')
var addressBase = split(addressParts[0], '.')
var baseNetwork = '${addressBase[0]}.${addressBase[1]}.${addressBase[2]}'
var prefixLength = int(addressParts[1])

// Calculate VM subnet (use first half of /26)
var vmSubnetPrefix = prefixLength == 26 ? vnetAddressSpace : '${baseNetwork}.0/27'

// Calculate Gateway subnet (use second half if needed)
var gatewaySubnetPrefix = '${baseNetwork}.32/27'

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-${vnetName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: concat([
      {
        name: 'AllowBGPFromVirtualNetwork'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '179'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
          description: 'Allow BGP peering within virtual network only'
        }
      }
      {
        name: 'AllowICMPFromVirtualNetwork'
        properties: {
          protocol: 'Icmp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1200
          direction: 'Inbound'
          description: 'Allow ICMP ping within virtual network only'
        }
      }
      {
        name: 'AllowSSHFromVirtualNetwork'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1300
          direction: 'Inbound'
          description: 'Allow SSH within virtual network only'
        }
      }
    ], deployerPublicIP != '' ? [{
      name: 'AllowSSHFromDeployer'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: '${deployerPublicIP}/32'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
        description: 'Allow SSH from deployer IP'
      }
    }
    {
      name: 'AllowRDPFromDeployer'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefix: '${deployerPublicIP}/32'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1001
        direction: 'Inbound'
        description: 'Allow RDP from deployer IP'
      }
    }] : [])
  }
}

// Define subnets based on requirements
var baseSubnets = [
  {
    name: 'VmSubnet'
    properties: {
      addressPrefix: vmSubnetPrefix
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]

var gatewaySubnet = includeGatewaySubnet ? [
  {
    name: 'GatewaySubnet'
    properties: {
      addressPrefix: gatewaySubnetPrefix
      // No NSG for GatewaySubnet - not supported
    }
  }
] : []

var allSubnets = concat(baseSubnets, gatewaySubnet)

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: allSubnets
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output vmSubnetId string = vnet.properties.subnets[0].id
output gatewaySubnetId string = includeGatewaySubnet ? vnet.properties.subnets[1].id : ''
output nsgId string = nsg.id

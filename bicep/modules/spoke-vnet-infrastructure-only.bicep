// VNet Infrastructure Only (no VMs, no Route Server)
// Used for phased deployment to avoid timeouts

@description('VNet name')
param vnetName string

@description('VNet address space')
param vnetAddressSpace string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Environment prefix for naming')
param environmentPrefix string

@description('Include NVA subnet')
param includeNvaSubnet bool = false

@description('Include Route Server subnet')
param includeRouteServerSubnet bool = false

@description('Tags to apply to resources')
param tags object

@description('Deployer public IP for RDP access (optional)')
param deployerPublicIP string = ''

// Calculate subnet prefixes
var baseOctets = split(vnetAddressSpace, '.')
var baseNetwork = '${baseOctets[0]}.${baseOctets[1]}.${baseOctets[2]}'

// Define subnets based on parameters
var baseSubnets = [
  {
    name: 'VmSubnet'
    properties: {
      addressPrefix: '${baseNetwork}.128/26'
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]

var nvaSubnet = includeNvaSubnet ? [
  {
    name: 'NvaSubnet'
    properties: {
      addressPrefix: '${baseNetwork}.0/26'
    }
  }
] : []

var routeServerSubnet = includeRouteServerSubnet ? [
  {
    name: 'RouteServerSubnet'
    properties: {
      addressPrefix: '${baseNetwork}.64/26'
    }
  }
] : []

var allSubnets = concat(baseSubnets, nvaSubnet, routeServerSubnet)

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-${vnetName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: concat([
      // RDP access from deployer IP if provided
    ], deployerPublicIP != '' ? [{
      name: 'AllowRDPFromDeployer'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefix: '${deployerPublicIP}/32'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
        description: 'Allow RDP from deployer IP'
      }
    }] : [], [
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
    ])
  }
}

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
output nsgId string = nsg.id

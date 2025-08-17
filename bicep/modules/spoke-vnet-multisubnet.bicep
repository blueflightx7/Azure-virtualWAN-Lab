// Spoke VNet with multiple subnets (for Azure Firewall deployment)
// Used for Spoke 1 which needs VMs, Firewall, and Management subnets

@description('VNet name')
param vnetName string

@description('VNet address space')
param vnetAddressSpace string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Environment prefix for naming')
param environmentPrefix string

@description('VM subnet address prefix')
param vmSubnet string

@description('Firewall subnet address prefix')
param firewallSubnet string

@description('Management subnet address prefix')
param managementSubnet string

@description('Tags to apply to resources')
param tags object

@description('Deployer public IP for RDP access (optional)')
param deployerPublicIP string = ''

// Network Security Group for VM subnet
resource vmNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-${vnetName}-vm-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: concat([
      // Common rules
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
    }
    {
      name: 'AllowSSHFromDeployer'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: '${deployerPublicIP}/32'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1001
        direction: 'Inbound'
        description: 'Allow SSH from deployer IP'
      }
    }] : [])
  }
}

// Network Security Group for Management subnet
resource mgmtNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-${vnetName}-mgmt-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: concat([
      {
        name: 'AllowManagementTraffic'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
          description: 'Allow management traffic within virtual network'
        }
      }
    ], deployerPublicIP != '' ? [{
      name: 'AllowManagementFromDeployer'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: '${deployerPublicIP}/32'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
        description: 'Allow management from deployer IP'
      }
    }] : [])
  }
}

// Virtual Network with multiple subnets
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
    subnets: [
      {
        name: 'VmSubnet'
        properties: {
          addressPrefix: vmSubnet
          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnet
          // No NSG for AzureFirewallSubnet - not supported
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: managementSubnet
          // No NSG for AzureFirewallManagementSubnet - not supported
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output vmSubnetId string = vnet.properties.subnets[0].id
output firewallSubnetId string = vnet.properties.subnets[1].id
output managementSubnetId string = vnet.properties.subnets[2].id
output vmNsgId string = vmNsg.id
output mgmtNsgId string = mgmtNsg.id

// Spoke 3 VNet for Azure Route Server (BGP Integration Hub)
// This VNet hosts the Azure Route Server for BGP peering with the NVA

@description('Spoke 3 VNet name')
param vnetName string

@description('Spoke 3 VNet address space')
param vnetAddressSpace string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Environment prefix for naming')
param environmentPrefix string

@description('Admin username for test VM')
param adminUsername string

@description('Admin password for test VM')
@secure()
param adminPassword string

@description('VM size for test VM')
param testVmSize string = 'Standard_B1s'

@description('Tags to apply to resources')
param tags object

// Calculate subnet prefixes
var baseOctets = split(vnetAddressSpace, '.')
var baseNetwork = '${baseOctets[0]}.${baseOctets[1]}.${baseOctets[2]}'
var routeServerSubnetPrefix = '${baseNetwork}.0/26'  // Required for Route Server
var vmSubnetPrefix = '${baseNetwork}.64/26'          // For test VM
var gatewaySubnetPrefix = '${baseNetwork}.128/26'    // Optional for VPN Gateway

// Virtual Network for Spoke 3 Route Server
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
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: routeServerSubnetPrefix
        }
      }
      {
        name: 'VmSubnet'
        properties: {
          addressPrefix: vmSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]
  }
}

// Network Security Group for test VM
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
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
        name: 'DenyAllOtherInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
          description: 'Explicit deny all other inbound traffic'
        }
      }
    ]
  }
}

// Public IP for Spoke 3 Route Server
resource routeServerPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-route-server-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Public IP for test VM
resource testVmPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-test-vm-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Test VM Network Interface
resource testVmNetworkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-test-vm-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: testVmPublicIp.id
          }
          subnet: {
            id: '${vnet.id}/subnets/VmSubnet'
          }
        }
      }
    ]
  }
}

// Spoke 3 Route Server (Azure Route Server)
resource routeServer 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-route-server'
  location: location
  tags: tags
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
    virtualRouterAsn: 65515 // Default ASN for Azure Route Server
  }
}

// Route Server IP Configuration
// CRITICAL: Route Server requires public IP address to be specified
resource routeServerIpConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2024-05-01' = {
  parent: routeServer
  name: 'default'
  properties: {
    subnet: {
      id: vnet.properties.subnets[0].id // RouteServerSubnet
    }
    publicIPAddress: {
      id: routeServerPip.id
    }
  }
}

// Test VM - Spoke3-Test-VM
resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${environmentPrefix}-spoke3-test-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: testVmSize
    }
    osProfile: {
      computerName: 'spoke3-test-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: testVmNetworkInterface.id
        }
      ]
    }
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output routeServerId string = routeServer.id
output routeServerName string = routeServer.name
output routeServerIpAddress string = routeServer.properties.virtualRouterIps[0]
output testVmName string = testVm.name

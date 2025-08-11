// Spoke VNet with NVA (Windows Server with RRAS) - Spoke 1

@description('Virtual network name')
param vnetName string

@description('Virtual network address space')
param vnetAddressSpace string

@description('Location for the resources')
param location string

@description('Admin username for VMs')
param adminUsername string

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VM size for NVA (should be Standard_B2s or larger for RRAS)')
param nvmVmSize string = 'Standard_B2s'

@description('VM size for test VM (can be smaller)')
param testVmSize string = 'Standard_B1s'

@description('Environment prefix')
param environmentPrefix string

@description('Tags to apply to resources')
param tags object

// Variables for subnet calculations
var vnetPrefix = split(vnetAddressSpace, '/')[0]
var baseOctets = split(vnetPrefix, '.')
var baseNetwork = '${baseOctets[0]}.${baseOctets[1]}.${baseOctets[2]}'
var nvaSubnetPrefix = '${baseNetwork}.0/26'          // 10.1.0.0/26   (64 addresses)
var vmSubnetPrefix = '${baseNetwork}.128/26'         // 10.1.0.128/26 (64 addresses)

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
    subnets: [
      {
        name: 'NvaSubnet'
        properties: {
          addressPrefix: nvaSubnetPrefix
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
    ]
  }
}

// Network Security Group - Security Hardened
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-spoke1-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // RDP access will be configured dynamically by deployment script from deployer IP only
      // No default RDP rule - security best practice
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

// Public IP for NVA VM
resource nvaPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-nva-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Public IP for test VM
resource testVmPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-test1-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NVA VM Network Interface
resource nvaNetworkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${environmentPrefix}-nva-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '${substring(nvaSubnetPrefix, 0, lastIndexOf(nvaSubnetPrefix, '.'))}.10'
          publicIPAddress: {
            id: nvaPublicIp.id
          }
          subnet: {
            id: '${vnet.id}/subnets/NvaSubnet'
          }
        }
      }
    ]
    enableIPForwarding: true
  }
}

// Test VM Network Interface
resource testVmNetworkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${environmentPrefix}-test1-nic'
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

// NVA VM (Windows Server with RRAS)
resource nvaVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${environmentPrefix}-spoke1-nva-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: nvmVmSize  // Higher specs for RRAS operations
    }
    osProfile: {
      computerName: 'spoke1-nva-vm'
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
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nvaNetworkInterface.id
        }
      ]
    }
  }
}

// Test VM - Spoke1-Test-VM
resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${environmentPrefix}-spoke1-test-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: testVmSize  // Smaller size for test VM
    }
    osProfile: {
      computerName: 'spoke1-test-vm'
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
          storageAccountType: 'Standard_LRS'  // Standard storage for test VM
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

// Output values
output vnetId string = vnet.id
output nvaVmName string = nvaVm.name
output testVmName string = testVm.name
output nvaPrivateIp string = nvaNetworkInterface.properties.ipConfigurations[0].properties.privateIPAddress

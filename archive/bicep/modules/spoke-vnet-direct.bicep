// Second spoke VNet for direct VWAN hub connection

@description('Virtual network name')
param vnetName string

@description('Virtual network address space (CIDR notation)')
param vnetAddressSpace string

@description('Location for the resources')
param location string

@description('Admin username for VMs')
param adminUsername string

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VM size for test VM')
param testVmSize string = 'Standard_B1s'

@description('Environment prefix')
param environmentPrefix string

@description('Tags to apply to resources')
param tags object

// Variables for subnet calculations
var vnetPrefix = split(vnetAddressSpace, '/')[0]
var baseOctets = split(vnetPrefix, '.')
var baseNetwork = '${baseOctets[0]}.${baseOctets[1]}.${baseOctets[2]}'
var vmSubnetPrefix = '${baseNetwork}.0/26'  // 10.2.0.0/26 (64 addresses)

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
  name: '${environmentPrefix}-spoke2-nsg'
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

// Public IP for test VM
resource testVmPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-test2-pip'
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
  name: '${environmentPrefix}-test2-nic'
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

// Test VM - Spoke2-Test-VM
resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${environmentPrefix}-spoke2-test-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: testVmSize
    }
    osProfile: {
      computerName: 'spoke2-test-vm'
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

// Output values
output vnetId string = vnet.id
output testVmName string = testVm.name

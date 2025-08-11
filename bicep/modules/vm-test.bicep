// VM Test Module for Phased Deployment  
// Creates test VMs in spoke2

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for VM')
param adminUsername string = 'vwanlab-admin'

@description('Admin password for VM')
@secure()
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_B2s' // Performance optimized: 2 GB RAM for better RDP experience

@description('Tags for all resources')
param tags object = {
  Environment: 'Lab'
  Project: 'VWAN-Demo'
  Purpose: 'Test-VM'
}

// Get existing spoke2 VNet
resource spokeVnet2 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke2-vnet'
}

// Create public IP for test VM
resource testPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-spoke2-test-pip'
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

// Create network interface for test VM
resource testNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${environmentPrefix}-spoke2-test-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${spokeVnet2.id}/subnets/VmSubnet'
          }
          publicIPAddress: {
            id: testPublicIp.id
          }
        }
      }
    ]
    // NSG removed - using subnet-level NSG instead
  }
}

// Create test VM
resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${environmentPrefix}-spoke2-test-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          storageAccountType: 'Standard_LRS' // 🔥 COST OPTIMIZED: Standard HDD vs Premium SSD (-70%)
        }
        name: '${environmentPrefix}-spoke2-test-osdisk'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: testNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        // storageUri omitted to use managed storage (Azure best practice)
      }
    }
  }
}

output vmId string = testVm.id
output vmName string = testVm.name
output privateIp string = testNic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIp string = testPublicIp.properties.ipAddress

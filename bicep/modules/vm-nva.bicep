// VM NVA Module for Phased Deployment
// Creates NVA VM with routing and forwarding capabilities

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
param vmSize string = 'Standard_B2s' // Performance optimized: 2 GB RAM required for RRAS/BGP

@description('Tags for all resources')
param tags object = {
  Environment: 'Lab'
  Project: 'VWAN-Demo'
  Purpose: 'NVA-Routing'
}

// Get existing spoke1 VNet
resource spokeVnet1 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke1-vnet'
}

// Create public IP for NVA VM
resource nvaPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-nva-pip'
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

// Create network interface for NVA VM
resource nvaNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${environmentPrefix}-spoke1-nva-nic'
  location: location
  tags: tags
  properties: {
    enableIPForwarding: true // Critical for NVA routing
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${spokeVnet1.id}/subnets/NvaSubnet'
          }
          publicIPAddress: {
            id: nvaPublicIp.id
          }
        }
      }
    ]
    // NSG removed - using subnet-level NSG instead
  }
}

// Create NVA VM (Windows Server with RRAS)
resource nvaVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${environmentPrefix}-spoke1-nva-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          storageAccountType: 'Standard_LRS' // 🔥 COST OPTIMIZED: Standard HDD vs Premium SSD (-70%)
        }
        name: '${environmentPrefix}-nva-osdisk'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nvaNic.id
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

// Install and configure RRAS on the NVA VM
resource nvaVmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: nvaVm
  name: 'ConfigureNVA'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "& {Enable-WindowsOptionalFeature -Online -FeatureName RemoteAccess -All; Enable-WindowsOptionalFeature -Online -FeatureName Routing -All; Import-Module RemoteAccess; Install-RemoteAccess -VpnType RoutingOnly; Set-NetIPInterface -InterfaceAlias \\"Ethernet\\" -Forwarding Enabled; netsh int ipv4 set global forwarding=enabled}"'
    }
  }
}

output vmId string = nvaVm.id
output vmName string = nvaVm.name
output privateIp string = nvaNic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIp string = nvaPublicIp.properties.ipAddress

// Phase 3: Spoke 3 Route Server Deployment
// Deploy Route Server in dedicated spoke3 for BGP peering with NVA

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string = ''

@description('Admin password for VMs')
@secure()
param adminPassword string = ''

@description('Deploy Test VM (false if VM already exists)')
param deployTestVm bool = true

@description('VM size for test VM')
param vmSize string = 'Standard_B2s' // Performance optimized: 2 GB RAM for better responsiveness

@description('Tags for all resources')
param tags object = {
  Environment: 'Lab'
  Project: 'VWAN-Demo'
  Purpose: 'Route-Server-BGP-Integration'
}

@description('Deployer public IP for RDP access (optional)')
param deployerPublicIP string = ''

// Get existing spoke 3 VNet
resource spoke3Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke3-vnet'
}

// Create public IP for Spoke 3 Route Server (required for Route Server)
resource routeServerPublicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
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

// Create Spoke 3 Route Server (Azure Virtual Hub in Route Server mode)
// Based on official Microsoft quickstart template structure and using latest API
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

// Create IP configuration for Route Server - this connects Route Server to subnet and public IP
// The public IP must be of Standard SKU (already configured above)
// CRITICAL: Route Server requires public IP address to be specified in the IP configuration
resource routeServerIpConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2024-05-01' = {
  parent: routeServer
  name: 'ipconfig1'
  properties: {
    subnet: {
      id: '${spoke3Vnet.id}/subnets/RouteServerSubnet'
    }
    publicIPAddress: {
      id: routeServerPublicIP.id
    }
  }
}

//Create NSG for test VM subnet - Security Hardened
resource testVmNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-test-nsg'
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

// Create public IP for test VM
resource testVmPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentPrefix}-spoke3-test-vm-pip'
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
resource testVmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = if (deployTestVm) {
  name: '${environmentPrefix}-spoke3-test-vm-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${spoke3Vnet.id}/subnets/VmSubnet'
          }
          publicIPAddress: {
            id: testVmPublicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: testVmNsg.id
    }
  }
}

// Create test VM in spoke3
resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = if (deployTestVm) {
  name: '${environmentPrefix}-spoke3-test-vm'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'spoke3-test'
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
        name: '${environmentPrefix}-spoke3-test-osdisk'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: testVmNic.id
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

output routeServerId string = routeServer.id
output routeServerName string = routeServer.name
output routeServerPublicIpId string = routeServerPublicIP.id
output testVmId string = deployTestVm ? testVm!.id : 'vm-not-deployed'
output testVmPrivateIp string = deployTestVm ? testVmNic!.properties.ipConfigurations[0].properties.privateIPAddress : 'vm-not-deployed'

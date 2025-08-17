// Phase 2: Multi-Region VM Deployments
// Deploys VMs across all spoke networks

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

// VM Configuration
@description('Admin username for all VMs')
param adminUsername string

@description('Admin password for all VMs')
@secure()
param adminPassword string

@description('Linux VM size')
param linuxVmSize string = 'Standard_B1s'

@description('Windows VM size')
param windowsVmSize string = 'Standard_B2s'

// Region Configuration
@description('West US region')
param westUsRegion string = 'West US'
@description('Central US region')
param centralUsRegion string = 'Central US'
@description('Southeast Asia region')
param southeastAsiaRegion string = 'Southeast Asia'

// VNet Names (from Phase 1 outputs)
@description('Spoke 1 VNet name')
param spoke1VnetName string = 'vnet-spoke1-${environmentPrefix}-wus'
@description('Spoke 2 VNet name')
param spoke2VnetName string = 'vnet-spoke2-${environmentPrefix}-sea'
@description('Spoke 3 VNet name')
param spoke3VnetName string = 'vnet-spoke3-${environmentPrefix}-cus'
@description('Spoke 4 VNet name')
param spoke4VnetName string = 'vnet-spoke4-${environmentPrefix}-wus'
@description('Spoke 5 VNet name')
param spoke5VnetName string = 'vnet-spoke5-${environmentPrefix}-wus'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
}

// Deploy Linux VM in Spoke 1 (West US)
module spoke1LinuxVm '../modules/vm-linux.bicep' = {
  name: 'spoke1-linux-vm-deployment'
  params: {
    vmName: 'vm-s1-linux-wus'
    location: westUsRegion
    vmSize: linuxVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: spoke1VnetName
    subnetName: 'VmSubnet'
    tags: tags
  }
}

// Deploy Windows VM in Spoke 1 (West US)
module spoke1WindowsVm '../modules/vm-windows.bicep' = {
  name: 'spoke1-windows-vm-deployment'
  params: {
    vmName: 'vm-s1-win-wus'
    location: westUsRegion
    vmSize: windowsVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: spoke1VnetName
    subnetName: 'VmSubnet'
    tags: tags
  }
}

// Deploy Linux VM in Spoke 2 (Southeast Asia)
module spoke2LinuxVm '../modules/vm-linux.bicep' = {
  name: 'spoke2-linux-vm-deployment'
  params: {
    vmName: 'vm-s2-linux-sea'
    location: southeastAsiaRegion
    vmSize: linuxVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: spoke2VnetName
    subnetName: 'VmSubnet'
    tags: tags
  }
}

// Deploy RRAS VM in Spoke 3 (Central US) for VPN connection
module spoke3RrasVm '../modules/vm-windows-rras.bicep' = {
  name: 'spoke3-rras-vm-deployment'
  params: {
    vmName: 'vm-s3-rras-cus'
    location: centralUsRegion
    vmSize: windowsVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: spoke3VnetName
    subnetName: 'VmSubnet'
    enableIPForwarding: true
    tags: tags
  }
}

// Deploy Linux VM in Spoke 4 (West US)
module spoke4LinuxVm '../modules/vm-linux.bicep' = {
  name: 'spoke4-linux-vm-deployment'
  params: {
    vmName: 'vm-s4-linux-wus'
    location: westUsRegion
    vmSize: linuxVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: spoke4VnetName
    subnetName: 'VmSubnet'
    tags: tags
  }
}

// Deploy Linux VM in Spoke 5 (West US)
module spoke5LinuxVm '../modules/vm-linux.bicep' = {
  name: 'spoke5-linux-vm-deployment'
  params: {
    vmName: 'vm-s5-linux-wus'
    location: westUsRegion
    vmSize: linuxVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: spoke5VnetName
    subnetName: 'VmSubnet'
    tags: tags
  }
}

// Outputs
output spoke1LinuxVmId string = spoke1LinuxVm.outputs.vmId
output spoke1WindowsVmId string = spoke1WindowsVm.outputs.vmId
output spoke2LinuxVmId string = spoke2LinuxVm.outputs.vmId
output spoke3RrasVmId string = spoke3RrasVm.outputs.vmId
output spoke4LinuxVmId string = spoke4LinuxVm.outputs.vmId
output spoke5LinuxVmId string = spoke5LinuxVm.outputs.vmId

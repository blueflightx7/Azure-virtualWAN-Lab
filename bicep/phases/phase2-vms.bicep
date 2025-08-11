// Phase 2: Virtual Machines
// Deploy VMs after VNet infrastructure is ready

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('Primary region')
param primaryRegion string = 'East US'

@description('Admin username for VMs')
param adminUsername string = ''

@description('Admin password for VMs')
@secure()
param adminPassword string = ''

@description('Deploy NVA VM (false if VM already exists)')
param deployNvaVm bool = true

@description('Deploy Test VM (false if VM already exists)')
param deployTestVm bool = true

@description('VM size for NVA and test VMs')
param vmSize string = 'Standard_B2s' // Performance optimized: 2 GB RAM for RRAS/BGP

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab'
  Project: 'VWAN-BGP-Lab'
  CreatedBy: 'Bicep'
}

// Deploy NVA VM to Spoke1 (this will be the only VM in spoke1)
module nvaVm '../modules/vm-nva.bicep' = if (deployNvaVm) {
  name: 'nva-vm-deployment'
  params: {
    environmentPrefix: environmentPrefix
    location: primaryRegion
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    tags: tags
  }
}

// Deploy Test VM to Spoke2 (this is what vm-test.bicep was designed for)
module testVm '../modules/vm-test.bicep' = if (deployTestVm) {
  name: 'test-vm-deployment'
  params: {
    environmentPrefix: environmentPrefix
    location: primaryRegion
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    tags: tags
  }
}

// Outputs
output nvaVmName string = deployNvaVm ? nvaVm!.outputs.vmName : 'vwanlab-spoke1-nva-vm'
output testVmName string = deployTestVm ? testVm!.outputs.vmName : 'vwanlab-spoke2-test-vm'

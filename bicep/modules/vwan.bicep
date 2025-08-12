// Virtual WAN and Hub deployment module

@description('Virtual WAN name')
param vwanName string

@description('VWAN hub name')
param vwanHubName string

@description('VWAN hub address prefix')
param vwanHubAddressPrefix string

@description('Location for the resources')
param location string

@description('Tags to apply to resources')
param tags object

// Deploy Virtual WAN
// Standard type required for advanced features like Route Server integration
resource virtualWan 'Microsoft.Network/virtualWans@2024-05-01' = {
  name: vwanName
  location: location
  tags: tags
  properties: {
    disableVpnEncryption: false // ✅ SECURITY: Keep encryption enabled
    allowBranchToBranchTraffic: true // ✅ BEST PRACTICE: Enable for hub-and-spoke
    type: 'Standard' // ✅ REQUIRED: Standard type for Route Server integration
  }
}

// Deploy Virtual WAN Hub
// Hub provides central connectivity and routing for all spokes
// Uses small dedicated address space, routes are advertised separately
resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: vwanHubName
  location: location
  tags: tags
  properties: {
    virtualWan: {
      id: virtualWan.id
    }
    addressPrefix: vwanHubAddressPrefix // ✅ CORRECT: Small /24 for hub infrastructure only
    sku: 'Standard' // ✅ REQUIRED: Standard SKU for advanced routing
    hubRoutingPreference: 'VpnGateway' // ✅ BEST PRACTICE: Optimize for VPN traffic
    allowBranchToBranchTraffic: true // ✅ TRANSIT: Enable hub as transit point
  }
}

// Enable hub routing
resource hubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' = {
  parent: virtualHub
  name: 'defaultRouteTable'
  properties: {
    labels: [
      'default'
    ]
    routes: []
  }
}

// Output values
output vwanId string = virtualWan.id
output vwanHubId string = virtualHub.id
output vwanHubName string = virtualHub.name

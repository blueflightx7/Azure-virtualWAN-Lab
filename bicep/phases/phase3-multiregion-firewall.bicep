// Phase 3: Azure Firewall Deployment
// Deploys Azure Firewall Premium in Spoke 1 (West US)

targetScope = 'resourceGroup'

@description('Environment prefix for resource naming')
param environmentPrefix string = 'vwanlab'

@description('West US region')
param westUsRegion string = 'West US'

@description('Spoke 1 VNet name')
param spoke1VnetName string = 'vnet-spoke1-${environmentPrefix}-wus'

@description('Azure Firewall name')
param firewallName string = 'afw-${environmentPrefix}-wus'

@description('Azure Firewall Policy name')
param firewallPolicyName string = 'afwp-${environmentPrefix}-wus'

@description('Azure Firewall SKU')
param firewallSku string = 'Premium'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab-MultiRegion'
  Project: 'VWAN-BGP-Firewall-Lab'
  CreatedBy: 'Bicep'
}

// Get existing Spoke 1 VNet
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spoke1VnetName
}

// Create public IP for Azure Firewall
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${firewallName}-pip'
  location: westUsRegion
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

// Create public IP for Azure Firewall Management
resource firewallMgmtPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${firewallName}-mgmt-pip'
  location: westUsRegion
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

// Create Azure Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: firewallPolicyName
  location: westUsRegion
  tags: tags
  properties: {
    sku: {
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
    // Allow all traffic for initial testing
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }
}

// Create Firewall Policy Rule Collection Group
resource firewallPolicyRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 1000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowAllNetworkRules'
        priority: 1000
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAllTraffic'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowAllApplicationRules'
        priority: 1100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowAllWeb'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: [
              '*'
            ]
            targetFqdns: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

// Deploy Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: firewallName
  location: westUsRegion
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'AzureFirewallIpConfiguration'
        properties: {
          publicIPAddress: {
            id: firewallPublicIp.id
          }
          subnet: {
            id: '${spoke1Vnet.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'AzureFirewallMgmtIpConfiguration'
      properties: {
        publicIPAddress: {
          id: firewallMgmtPublicIp.id
        }
        subnet: {
          id: '${spoke1Vnet.id}/subnets/AzureFirewallManagementSubnet'
        }
      }
    }
  }
  dependsOn: [
    firewallPolicyRuleCollectionGroup
  ]
}

// Outputs
output firewallId string = firewall.id
output firewallName string = firewall.name
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = firewallPublicIp.properties.ipAddress
output firewallPolicyId string = firewallPolicy.id

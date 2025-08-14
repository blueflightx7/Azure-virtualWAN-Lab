# Multi-Region Azure VWAN Lab Architecture

## Overview

This document describes the comprehensive multi-region Azure VWAN lab environment with Azure Firewall, VPN connectivity, and advanced routing configurations.

## Architecture Summary

### 🌐 **Multi-Region Topology**

**3 VWAN Hubs:**
- **West US Hub**: `10.200.0.0/24` - Hub infrastructure (routes to 10.0.0.0/12 regional block)
- **Central US Hub**: `10.201.0.0/24` - Hub infrastructure (routes to 10.16.0.0/12 regional block)
- **Southeast Asia Hub**: `10.202.0.0/24` - Hub infrastructure (routes to 10.32.0.0/12 regional block)

**5 Spoke Networks:**
- **Spoke 1** (West US): `10.0.1.0/24` - Azure Firewall hub + Windows + Linux VMs
- **Spoke 2** (Southeast Asia): `10.32.1.0/26` - Linux VM, direct VWAN connection
- **Spoke 3** (Central US): `10.16.1.0/26` - RRAS VM, VPN connection to VWAN
- **Spoke 4** (West US): `10.0.2.0/26` - Linux VM, routes via Firewall
- **Spoke 5** (West US): `10.0.3.0/26` - Linux VM, routes via Firewall

### 🔥 **Azure Firewall Configuration**

**Location**: Spoke 1 (West US)
**SKU**: Premium (all features available)
**Subnets in Spoke 1**:
- `10.0.1.0/26` - VM subnet
- `10.0.1.64/26` - AzureFirewallSubnet
- `10.0.1.128/26` - AzureFirewallManagementSubnet

**Traffic Flow**:
- Spoke 4 & 5 have default route (0.0.0.0/0) → Azure Firewall
- All inter-spoke traffic in West US region flows through Firewall

### 🔐 **VPN Connectivity**

**Spoke 3 Connection**:
- RRAS VM in Central US establishes IPSec VPN tunnel
- Connects to VPN Gateway in Central US VWAN Hub
- BGP enabled for dynamic routing
- Shared key: `VwanLabSharedKey123!`

### 🖥️ **Virtual Machine Deployment**

**Spoke 1 (West US)**:
- 1x Windows VM (`Standard_B2s`) - 2 core, 4GB RAM
- 1x Linux VM (`Standard_B1s`) - 1 core, 1GB RAM

**Spoke 2 (Southeast Asia)**:
- 1x Linux VM (`Standard_B1s`)

**Spoke 3 (Central US)**:
- 1x Windows RRAS VM (`Standard_B2s`) with routing capabilities

**Spoke 4 & 5 (West US)**:
- 1x Linux VM each (`Standard_B1s`)

### 🛣️ **Routing Configuration**

**Default Routes**:
- Spoke 4 & 5: `0.0.0.0/0` → Azure Firewall private IP
- Cross-region traffic via VWAN hub-to-hub connectivity

**Static Routes** (User Defined Routes):
- Spoke 4 → Spoke 1, Spoke 5 via Firewall
- Spoke 5 → Spoke 1, Spoke 4 via Firewall

## Deployment Architecture

### 📋 **6-Phase Deployment Strategy**

**Phase 1: Core Infrastructure**
- Deploy 3 VWAN hubs across regions
- Create 5 spoke VNets with appropriate subnetting
- Establish basic NSG rules

**Phase 2: Virtual Machines**
- Deploy Linux VMs in all spokes
- Deploy Windows VM in Spoke 1
- Deploy RRAS VM in Spoke 3 with routing features

**Phase 3: Azure Firewall**
- Deploy Azure Firewall Standard in Spoke 1
- Create firewall policy with allow-all rules
- Configure management and data plane subnets

**Phase 4: VPN Gateway**
- Deploy VPN Gateway in Central US hub
- Create VPN site for Spoke 3 connection
- Configure BGP settings for dynamic routing

**Phase 5: VWAN Connections**
- Connect Spoke 1, 4, 5 to West US hub
- Connect Spoke 2 to Southeast Asia hub
- Enable internet security and transit

**Phase 6: Routing Configuration**
- Create route tables for Spoke 4 & 5
- Configure default routes to Azure Firewall
- Associate route tables with VM subnets

### 🚀 **Deployment Commands**

**Full Multi-Region Lab**:
```powershell
.\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-multiregion"
```

**Infrastructure Only**:
```powershell
.\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-mr" -DeploymentMode InfrastructureOnly
```

**Specific Phase**:
```powershell
.\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-mr" -Phase 3
```

**What-If Analysis**:
```powershell
.\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-mr" -WhatIf
```

## Connectivity Patterns

### 🔄 **Traffic Flow Scenarios**

**Spoke 4 → Internet**:
1. Spoke 4 VM → Azure Firewall (via UDR)
2. Azure Firewall → Internet (via VWAN hub)

**Spoke 2 → Spoke 1**:
1. Spoke 2 (SEA) → Southeast Asia hub
2. SEA hub → West US hub (hub-to-hub)
3. West US hub → Spoke 1

**Spoke 3 → Any Spoke**:
1. Spoke 3 → RRAS VM
2. RRAS VM → VPN tunnel → Central US hub
3. Central US hub → destination hub → target spoke

**Cross-Region Communication**:
- Automatic hub-to-hub connectivity in VWAN
- No additional configuration required
- Optimal routing via Azure backbone

### 🎯 **Testing Scenarios**

**Connectivity Tests**:
1. Spoke 1 Windows VM → All other spokes
2. Spoke 2 Linux VM → Cross-region connectivity
3. Spoke 4/5 → Internet via Firewall
4. Spoke 3 VPN tunnel functionality

**Security Tests**:
1. Azure Firewall logs for Spoke 4/5 traffic
2. NSG effective rules validation
3. JIT access functionality (if enabled)

**Performance Tests**:
1. Inter-region latency measurements
2. Firewall throughput testing
3. VPN tunnel performance

## Security Features

### 🛡️ **Network Security Groups**

**VM Subnets**:
- SSH (22) from deployer IP and VirtualNetwork
- RDP (3389) from deployer IP (Windows VMs)
- ICMP within VirtualNetwork
- BGP (179) within VirtualNetwork

**Firewall Subnets**:
- No NSG (not supported on AzureFirewallSubnet)
- Azure Firewall manages traffic filtering

### 🔒 **Azure Firewall Rules**

**Network Rules**:
- Allow all traffic (lab environment)
- Logging enabled for monitoring

**Application Rules**:
- Allow HTTP/HTTPS to any FQDN
- DNS proxy enabled

### 🚨 **Secure Future Initiative (SFI)**

**JIT Access** (Optional):
- Just-In-Time VM access via Defender for Cloud
- Fallback to restrictive NSG rules
- Enhanced security posture

**Auto-Shutdown**:
- Cost optimization feature
- Configurable shutdown schedules

## Cost Optimization

### 💰 **Resource Costs** (Updated January 2025)

**Complete Multi-Region Architecture**:
- **Core Networking**: $2,857.90/month (69.4%)
  - 3x VWAN Hubs: $547.50
  - Azure Firewall Standard: $693.75
  - Hub Connections & Gateways: $907.90
- **Compute Resources**: $400.76/month (9.7%)
  - Mixed VM sizes across regions
- **Storage & Security**: $715.57/month (16.4%)
  - VM disks, monitoring, security services
- **Additional Services**: $367.03/month (8.5%)
  - Bastion, private endpoints, supporting services

**Total Estimated**: ~$4,341.26/month

> 📊 **Detailed Cost Analysis**: See [multiregion-cost-analysis-2025.md](./multiregion-cost-analysis-2025.md) for comprehensive breakdown

### 📉 **Cost Reduction Strategies**

1. **Development Environment**: Remove Azure Firewall Standard → Save $693.75 (21% reduction)
2. **Lab/Training**: Use Spot VMs and basic storage → Save $1,967.50 (45% reduction)
3. **Proof of Concept**: Single region deployment → Save $2,755.30 (63% reduction)
4. **Auto-Shutdown**: Use `-EnableAutoShutdown` parameter → Save 50% on compute costs
5. **Reserved Instances**: 1-year commitment → Save 30-60% on compute and networking

## Troubleshooting

### 🔧 **Common Issues**

**Deployment Timeouts**:
- Use phased deployment approach
- Individual phase deployment if needed

**Connectivity Issues**:
- Verify effective routes with `az network nic show-effective-route-table`
- Check firewall logs for blocked traffic
- Validate NSG rules

**VPN Connectivity**:
- Verify RRAS configuration on Spoke 3 VM
- Check VPN gateway BGP status
- Validate shared keys and IP addresses

### 📊 **Monitoring Commands**

**Check VWAN Hub Status**:
```powershell
Get-AzVirtualHub -ResourceGroupName $rgName
```

**Verify VM Connectivity**:
```powershell
Test-NetConnection -ComputerName <target-ip> -Port 22
```

**Check Firewall Logs**:
```powershell
Get-AzOperationalInsightsWorkspace | Get-AzOperationalInsightsQuery
```

## Next Steps

### 🚀 **Advanced Configurations**

1. **BGP Peering**: Configure BGP between RRAS and VWAN hub
2. **Custom Routes**: Add specific routing policies
3. **Monitoring**: Set up Log Analytics and monitoring dashboards
4. **Security**: Implement custom firewall rules
5. **Automation**: Create management scripts for common tasks

### 📚 **Learning Opportunities**

- Azure networking concepts
- BGP routing protocols
- Firewall rule management
- VPN troubleshooting
- Cross-region connectivity patterns

---

**Version**: 2.0 Multi-Region Architecture  
**Last Updated**: August 11, 2025  
**Author**: Azure VWAN Lab Team

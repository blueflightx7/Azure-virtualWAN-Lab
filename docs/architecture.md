# Azure Virtual WAN Multi-Region Lab Architecture

This document describes the multi-region Azure Virtual WAN lab environment designed to demonstrate advanced networking concepts including hub-to-hub connectivity, Azure Firewall Standard, VPN gateway integration, and cross-region routing.

## Overview

The lab environment consists of:

1. **Three Azure Virtual WAN Hubs** - Multi-region central routing
2. **Five Spoke VNets** - Distributed across three regions  
3. **Azure Firewall Standard** - Network security and routing
4. **VPN Gateway Integration** - IPSec connectivity for hybrid scenarios
5. **Cross-Region Connectivity** - Global network architecture

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Azure Virtual WAN                                 │
│                                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │   West US Hub   │────│ Central US Hub  │────│ SE Asia Hub     │            │
│  │  10.200.0.0/24  │    │  10.201.0.0/24  │    │  10.202.0.0/24  │            │
│  │                 │    │                 │    │                 │            │
│  │ Routes:         │    │ Routes:         │    │ Routes:         │            │
│  │ 10.0.0.0/12     │    │ 10.16.0.0/12    │    │ 10.32.0.0/12    │            │
│  └─────┬───┬───┬───┘    └────────┬────────┘    └────────┬────────┘            │
└────────┼───┼───┼─────────────────┼─────────────────────┼─────────────────────┘
         │   │   │                 │                     │
         │   │   │                 │                     │
    ┌────▼┐ ┌▼─┐ ┌▼──┐         ┌───▼────┐           ┌────▼────┐
    │Spk1 │ │S4│ │S5 │         │ Spk3   │           │ Spk2    │
    │Fire │ │  │ │   │         │ VPN    │           │ Linux   │
    │wall │ │  │ │   │         │ RRAS   │           │ VMs     │
    └─────┘ └──┘ └───┘         └────────┘           └─────────┘
   
West US Region          Central US Region        SE Asia Region
10.0.0.0/12            10.16.0.0/12             10.32.0.0/12
```

## Regional Architecture

### West US Region (10.0.0.0/12)

**VWAN Hub**: `10.200.0.0/24` (Infrastructure)  
**Regional Block**: `10.0.0.0/12` (Advertised to spokes)

#### Spoke 1 - Azure Firewall Hub (10.0.1.0/24)
- **VmSubnet**: `10.0.1.0/26` - Virtual machines
- **AzureFirewallSubnet**: `10.0.1.64/26` - Azure Firewall Standard
- **AzureFirewallManagementSubnet**: `10.0.1.128/26` - Firewall management

#### Spoke 4 - Protected Workload (10.0.2.0/26)
- **VmSubnet**: `10.0.2.0/26` - Routes via Azure Firewall

#### Spoke 5 - Protected Workload (10.0.3.0/26)  
- **VmSubnet**: `10.0.3.0/26` - Routes via Azure Firewall

### Central US Region (10.16.0.0/12)

**VWAN Hub**: `10.201.0.0/24` (Infrastructure)  
**Regional Block**: `10.16.0.0/12` (Advertised to spokes)

#### Spoke 3 - VPN Gateway (10.16.1.0/25)
- **VmSubnet**: `10.16.1.0/27` - RRAS VM for VPN termination
- **GatewaySubnet**: `10.16.1.32/27` - VPN Gateway subnet

### Southeast Asia Region (10.32.0.0/12)

**VWAN Hub**: `10.202.0.0/24` (Infrastructure)  
**Regional Block**: `10.32.0.0/12` (Advertised to spokes)

#### Spoke 2 - Linux Environment (10.32.1.0/26)
- **VmSubnet**: `10.32.1.0/26` - Linux test VMs

## Key Architectural Principles

### Address Space Separation

**Critical Design**: VWAN hub infrastructure addresses are completely separate from regional spoke allocations to prevent routing conflicts.

- **Hub Infrastructure**: `10.200.0.0/22` block (10.200.0.0 - 10.203.255.255)
  - Each hub uses `/24` for internal routing infrastructure
  - Never overlaps with spoke network ranges
  
- **Regional Spoke Allocations**: Large `/12` blocks for regional growth
  - Each region's spokes deployed within their regional `/12` 
  - Advertised via VWAN hub route tables to spokes in that region

### Azure Firewall Integration

#### Firewall Standard Features
- **TLS Inspection**: Deep packet inspection with certificate validation
- **IDPS**: Intrusion Detection and Prevention System
- **URL Filtering**: Category-based web filtering
- **Application Rules**: FQDN-based filtering

#### Traffic Flow via Firewall
1. **Spoke 4 & 5** → Default route (0.0.0.0/0) → **Azure Firewall**
2. **Azure Firewall** → Security inspection → **Destination**
3. **Return Traffic** → **Azure Firewall** → **Source spoke**

### VPN Gateway Integration

#### IPSec Connectivity
- **Local Network Gateway**: Defines on-premises address space
- **VPN Connection**: IPSec tunnel between Azure and on-premises
- **BGP Over IPSec**: Dynamic routing via BGP protocol
- **RRAS VM**: Windows RRAS for VPN termination testing

### Cross-Region Routing

#### Hub-to-Hub Connectivity
- **Automatic**: VWAN provides automatic hub-to-hub connectivity  
- **Global Transit**: Traffic can flow between any regions
- **Route Propagation**: Routes automatically shared between hubs

#### Route Advertisement Strategy
```
West US Hub Route Table:
├── Local: 10.200.0.0/24 (hub infrastructure)
├── Advertised: 10.0.0.0/12 (regional summary)
└── Learned: 10.16.0.0/12, 10.32.0.0/12 (from other hubs)

Central US Hub Route Table:  
├── Local: 10.201.0.0/24 (hub infrastructure)
├── Advertised: 10.16.0.0/12 (regional summary)
└── Learned: 10.0.0.0/12, 10.32.0.0/12 (from other hubs)

SE Asia Hub Route Table:
├── Local: 10.202.0.0/24 (hub infrastructure) 
├── Advertised: 10.32.0.0/12 (regional summary)
└── Learned: 10.0.0.0/12, 10.16.0.0/12 (from other hubs)
```

## Network Security Groups

### Regional NSG Configurations

#### West US Spokes (Firewall Protected)
```
Priority 1000: AllowRDPFromDeployer (TCP 3389 from deployer IP)
Priority 1001: AllowSSHFromDeployer (TCP 22 from deployer IP)
Priority 1100: AllowBGPFromVirtualNetwork (TCP 179 from VirtualNetwork)
Priority 1200: AllowICMPFromVirtualNetwork (ICMP from VirtualNetwork)
Priority 1300: AllowSSHFromVirtualNetwork (TCP 22 from VirtualNetwork)
```

#### Central US Spoke (VPN)
```
Priority 1000: AllowRDPFromDeployer (TCP 3389 from deployer IP)
Priority 1100: AllowBGPFromVirtualNetwork (TCP 179 from VirtualNetwork)  
Priority 1200: AllowICMPFromVirtualNetwork (ICMP from VirtualNetwork)
Priority 1500: AllowIPSecFromInternet (UDP 500, 4500 from Internet)
```

#### Southeast Asia Spoke (Direct)
```
Priority 1000: AllowSSHFromDeployer (TCP 22 from deployer IP)
Priority 1200: AllowICMPFromVirtualNetwork (ICMP from VirtualNetwork)
Priority 1300: AllowSSHFromVirtualNetwork (TCP 22 from VirtualNetwork)
```

## Traffic Flow Examples

### Cross-Region Communication

#### Spoke 1 (West US) to Spoke 2 (SE Asia)
```
Source: VM in Spoke 1 (10.0.1.x)
Path: Spoke 1 → West US Hub → SE Asia Hub → Spoke 2  
Destination: VM in Spoke 2 (10.32.1.x)
Route: Automatic via VWAN global transit
```

#### Spoke 4 (West US) to Spoke 3 (Central US)
```
Source: VM in Spoke 4 (10.0.2.x)
Path: Spoke 4 → Azure Firewall → West US Hub → Central US Hub → Spoke 3
Destination: VM in Spoke 3 (10.16.1.x) 
Security: Inspected by Azure Firewall Standard
```

### VPN Traffic Flow

#### On-Premises to Azure (via VPN)
```
Source: On-premises network (192.168.x.x)
Path: Internet → VPN Gateway → Spoke 3 → Central US Hub → Other spokes
Protocol: IPSec with BGP routing
Encryption: AES-256, SHA-256
```

## High Availability & Redundancy

### Multi-Region Resilience
- **Geographic Distribution**: Three regions provide fault tolerance
- **Automatic Failover**: VWAN provides automatic hub failover
- **Zone Redundancy**: Components deployed across availability zones

### Azure Firewall HA
- **Zone Redundancy**: Firewall deployed across multiple zones
- **Health Monitoring**: Automatic detection and failover
- **Session Persistence**: Stateful connection tracking

### VPN Gateway Redundancy
- **Active-Standby**: Automatic failover between gateway instances
- **BGP Routing**: Dynamic route updates during failover
- **Connection Monitoring**: Continuous tunnel health checking

## Security Architecture

### Defense in Depth

#### Network Layer Security
- **NSGs**: Subnet-level traffic filtering
- **Azure Firewall**: Application-layer inspection
- **Private Endpoints**: Secure service connectivity

#### Identity & Access
- **Just-In-Time VM Access**: Time-limited administrative access
- **Azure AD Integration**: Centralized identity management  
- **RBAC**: Role-based access controls

#### Data Protection
- **Encryption in Transit**: All inter-region traffic encrypted
- **Disk Encryption**: VM disks encrypted at rest
- **Key Management**: Azure Key Vault integration

### Compliance Considerations
- **Network Segmentation**: Isolated environments per region
- **Audit Logging**: Comprehensive logging and monitoring
- **Data Residency**: Regional data placement controls

## Scalability & Performance

### Horizontal Scaling
- **Additional Spokes**: Easy addition of new spoke VNets
- **New Regions**: Simple deployment of additional hubs
- **Workload Distribution**: Regional workload placement

### Performance Optimization
- **Regional Proximity**: Workloads placed near users
- **Direct Connectivity**: Minimal hop count between spokes
- **Bandwidth Allocation**: Right-sized connections for workloads

### Growth Planning
- **Address Space**: Large `/12` blocks allow massive growth
- **Hub Capacity**: Standard hubs support enterprise scale
- **Route Limits**: Designed within Azure platform limits

## Use Cases & Scenarios

### Enterprise Multi-Region Deployment
- **Global Applications**: Applications distributed across regions
- **Disaster Recovery**: Cross-region backup and failover
- **Compliance**: Regional data placement requirements

### Hybrid Cloud Connectivity  
- **Site-to-Site VPN**: Secure connection to on-premises
- **ExpressRoute Integration**: High-bandwidth private connectivity
- **Multi-Cloud**: Integration with other cloud providers

### Advanced Security Scenarios
- **Zero Trust**: Comprehensive traffic inspection
- **Micro-Segmentation**: Granular network isolation
- **Threat Detection**: Advanced security monitoring

### Development & Testing
- **Environment Isolation**: Separate dev/test/prod environments
- **Cross-Region Testing**: Multi-region application testing
- **Performance Testing**: Network latency and throughput validation

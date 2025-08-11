# Azure Virtual WAN Lab Architecture

This document describes the architecture of the Azure Virtual WAN lab environment designed to demonstrate advanced networking concepts including BGP peering, Network Virtual Appliances (NVAs), and Azure Route Server integration.

## Overview

The lab environment consists of:

1. **Azure Virtual WAN Hub** - Central routing hub
2. **Spoke VNet with NVA and Azure Route Server** - Advanced routing scenarios
3. **Direct Spoke VNet** - Simple VWAN connectivity
4. **Test VMs** - Connectivity validation

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Virtual WAN                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 VWAN Hub                                │    │
│  │              (10.0.0.0/16)                              │    │
│  │                                                         │    │
│  └─────────────────┬───────────────────┬───────────────────┘    │
└────────────────────┼───────────────────┼────────────────────────┘
                     │                   │
          ┌──────────▼──────────┐       ┌▼──────────────────┐
          │     Spoke VNet 1    │       │   Spoke VNet 2    │
          │   (10.1.0.0/16)     │       │  (10.2.0.0/16)    │
          │                     │       │                   │
          │ ┌─────────────────┐ │       │ ┌───────────────┐ │
          │ │ GatewaySubnet   │ │       │ │   VmSubnet    │ │
          │ │ (10.1.0.0/24)   │ │       │ │ (10.2.0.0/24) │ │
          │ │                 │ │       │ │               │ │
          │ │ ┌─────────────┐ │ │       │ │ ┌───────────┐ │ │
          │ │ │   NVA VM    │ │ │       │ │ │ Test VM 2 │ │ │
          │ │ │   (RRAS)    │ │ │       │ │ │           │ │ │
          │ │ └─────────────┘ │ │       │ │ └───────────┘ │ │
          │ └─────────────────┘ │       │ └───────────────┘ │
          │                     │       └───────────────────┘
          │ ┌─────────────────┐ │
          │ │RouteServerSubnet│ │
          │ │ (10.1.1.0/24)   │ │
          │ │                 │ │
          │ │ ┌─────────────┐ │ │
          │ │ │Azure Route  │ │ │
          │ │ │   Server    │ │ │◄──── BGP Peering
          │ │ └─────────────┘ │ │
          │ └─────────────────┘ │
          │                     │
          │ ┌─────────────────┐ │
          │ │   VmSubnet      │ │
          │ │ (10.1.2.0/24)   │ │
          │ │                 │ │
          │ │ ┌─────────────┐ │ │
          │ │ │ Test VM 1   │ │ │
          │ │ │             │ │ │
          │ │ └─────────────┘ │ │
          │ └─────────────────┘ │
          └─────────────────────┘
```

## Component Details

### Azure Virtual WAN Hub

- **Address Space**: 10.0.0.0/16
- **Type**: Standard VWAN Hub
- **Features**:
  - Branch-to-branch connectivity enabled
  - ExpressRoute routing preference
  - Default route table for propagation

### Spoke VNet 1 (Advanced Routing)

- **Address Space**: 10.1.0.0/16
- **Subnets**:
  - **GatewaySubnet** (10.1.0.0/24): Hosts the NVA VM
  - **RouteServerSubnet** (10.1.1.0/24): Hosts Azure Route Server
  - **VmSubnet** (10.1.2.0/24): Hosts test VMs

#### Network Virtual Appliance (NVA)

- **VM Type**: Windows Server 2022
- **Role**: RRAS-enabled router for BGP peering
- **IP Forwarding**: Enabled
- **BGP Configuration**:
  - Local ASN: 65001
  - Peers with Azure Route Server
  - Propagates routes to VWAN Hub

#### Azure Route Server

- **Purpose**: Enable BGP peering between NVA and Azure
- **Configuration**:
  - Branch-to-branch traffic: Enabled
  - BGP peering with NVA VM
  - Route propagation to VNet and VWAN Hub

### Spoke VNet 2 (Direct Connection)

- **Address Space**: 10.2.0.0/16
- **Subnets**:
  - **VmSubnet** (10.2.0.0/24): Hosts test VM
- **Connection**: Direct to VWAN Hub
- **Purpose**: Validate automatic route propagation

### Network Security Groups

#### Spoke 1 NSG Rules

1. **AllowRDP** (Priority 1000): TCP 3389 inbound
2. **AllowBGP** (Priority 1100): TCP 179 inbound
3. **AllowICMP** (Priority 1200): ICMP inbound

#### Spoke 2 NSG Rules

1. **AllowRDP** (Priority 1000): TCP 3389 inbound
2. **AllowICMP** (Priority 1200): ICMP inbound

## Routing Flow

### BGP Route Propagation

1. **NVA VM** learns routes from Azure Route Server
2. **Azure Route Server** propagates routes to:
   - Connected VNet (Spoke VNet 1)
   - VWAN Hub (via VNet connection)
3. **VWAN Hub** distributes routes to:
   - All connected spoke VNets
   - Other VWAN components

### Traffic Flow Examples

#### Test VM 1 to Test VM 2

1. **Source**: Test VM 1 (10.1.2.x)
2. **Route**: Via VWAN Hub
3. **Destination**: Test VM 2 (10.2.0.x)
4. **Path**: Spoke VNet 1 → VWAN Hub → Spoke VNet 2

#### External Route Advertisement

1. **NVA VM** can advertise custom routes via BGP
2. **Azure Route Server** propagates to Azure infrastructure
3. **VWAN Hub** distributes to all connected networks

## High Availability Considerations

### Redundancy Options

- **Multiple NVAs**: Deploy NVAs in different availability zones
- **Load Balancing**: Use Azure Load Balancer for NVA redundancy
- **Route Server**: Automatically provides HA with multiple instances

### Monitoring

- **Azure Monitor**: Track BGP session status
- **Network Watcher**: Monitor connectivity and routing
- **Custom Scripts**: Automated connectivity testing

## Security Considerations

### Network Segmentation

- **NSGs**: Control traffic between subnets
- **Route Filtering**: Control route advertisement
- **Firewall Integration**: Can be added to VWAN Hub

### Access Control

- **VM Access**: Secured via NSGs and public key authentication
- **Management**: Separate management subnet for administrative access
- **BGP Security**: MD5 authentication for BGP sessions (optional)

## Scalability

### Expansion Options

- **Additional Spokes**: Easy to add more spoke VNets
- **Multi-Region**: Deploy additional VWAN Hubs in other regions
- **Hybrid Connectivity**: Add VPN or ExpressRoute connections

### Performance Considerations

- **VM Sizing**: Scale NVA VMs based on throughput requirements
- **Route Server Limits**: Consider route advertisement limits
- **VWAN Throughput**: Monitor hub throughput utilization

## Use Cases

### Primary Scenarios

1. **Hybrid Cloud Connectivity**: Connect on-premises networks via NVA
2. **Advanced Routing**: Custom routing policies via BGP
3. **Network Function Virtualization**: Deploy network services in Azure
4. **Multi-Cloud Connectivity**: Connect to other cloud providers

### Testing Scenarios

1. **Route Propagation**: Verify automatic route learning
2. **Failover Testing**: Test NVA redundancy
3. **Performance Testing**: Measure throughput and latency
4. **Security Testing**: Validate traffic filtering and isolation

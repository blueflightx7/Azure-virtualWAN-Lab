# Azure VWAN Lab - Virtual Machine Deployment Analysis

## 📊 **Total VM Count: 4 Virtual Machines**

### **🖥️ VM Breakdown by Spoke**

| **VM Name** | **Location** | **Purpose** | **VM Size** | **OS** |
|-------------|--------------|-------------|-------------|--------|
| **vwanlab-nva-vm** | Spoke 1 | Network Virtual Appliance (RRAS/BGP) | Standard_B2s | Windows Server 2022 |
| **TestVM-Spoke1** | Spoke 1 | Connectivity Testing | Standard_B1s | Windows Server 2022 |
| **TestVM-Spoke2** | Spoke 2 | Connectivity Testing | Standard_B1s | Windows Server 2022 |
| **TestVM-Spoke3** | Spoke 3 | Connectivity Testing | Standard_B1s | Windows Server 2022 |

### **🏗️ Deployment Architecture**

#### **Spoke 1 - NVA Hub (2 VMs)**
```
Spoke 1 VNet (10.1.0.0/16)
├── NVA Subnet (10.1.0.0/26)
│   └── vwanlab-nva-vm (Standard_B2s)
│       ├── Role: Windows RRAS + BGP Router
│       ├── Connections: VWAN Hub, Spoke 3 Route Server
│       └── Features: Internet Gateway, BGP Peering
└── VM Subnet (10.1.0.128/26)  
    └── TestVM-Spoke1 (Standard_B1s)
        └── Role: Connectivity Testing
```

#### **Spoke 2 - Direct VWAN (1 VM)**
```
Spoke 2 VNet (10.2.0.0/16)
└── VM Subnet (10.2.0.128/26)
    └── TestVM-Spoke2 (Standard_B1s)
        ├── Role: Connectivity Testing
        └── Connection: Direct to VWAN Hub
```

#### **Spoke 3 - Route Server (1 VM)**
```
Spoke 3 VNet (10.3.0.0/16)
├── RouteServerSubnet (10.3.0.0/26)
│   └── spoke3-route-server (Azure Route Server)
│       └── Role: BGP Route Exchange with NVA
└── VM Subnet (10.3.64.0/26)
    └── TestVM-Spoke3 (Standard_B1s)
        └── Role: Connectivity Testing
```

### **💰 VM Cost Analysis (Monthly)**

| **VM** | **Size** | **Monthly Cost** | **Purpose Justification** |
|--------|----------|------------------|---------------------------|
| **vwanlab-nva-vm** | Standard_B2s | $29.93 | **HIGH**: RRAS + BGP requires 2GB RAM |
| **TestVM-Spoke1** | Standard_B1s | $10.22 | **LOW**: Basic connectivity testing |
| **TestVM-Spoke2** | Standard_B1s | $10.22 | **LOW**: Basic connectivity testing |
| **TestVM-Spoke3** | Standard_B1s | $10.22 | **LOW**: Basic connectivity testing |
| **Total VM Costs** | | **$60.59** | **Mixed sizing optimized** |

### **🔧 VM Specifications**

#### **NVA VM (Production-Grade)**
```yaml
VM Size: Standard_B2s
vCPUs: 2
RAM: 4 GB  
Storage: 128 GB Standard_LRS
Network: Premium networking for BGP
OS: Windows Server 2022 Datacenter
Special Features:
  - IP Forwarding Enabled
  - RRAS Role Installed
  - BGP Configuration
  - Multiple Network Interfaces
```

#### **Test VMs (Cost-Optimized)**
```yaml
VM Size: Standard_B1s  
vCPUs: 1
RAM: 1 GB
Storage: 128 GB Standard_LRS
Network: Standard networking
OS: Windows Server 2022 Datacenter
Special Features:
  - Basic connectivity tools
  - Remote access via RDP
  - Network diagnostics
```

### **📍 VM Network Assignments**

| **VM** | **VNet** | **Subnet** | **Private IP** | **Public IP** |
|--------|----------|------------|----------------|---------------|
| **vwanlab-nva-vm** | spoke1-vnet | NvaSubnet | Dynamic | Standard PIP |
| **TestVM-Spoke1** | spoke1-vnet | VmSubnet | Dynamic | Standard PIP |
| **TestVM-Spoke2** | spoke2-vnet | VmSubnet | Dynamic | Standard PIP |
| **TestVM-Spoke3** | spoke3-vnet | VmSubnet | Dynamic | Standard PIP |

### **🚀 Deployment Phases**

#### **Phase 1**: Core Infrastructure
- VNets and subnets created
- **No VMs deployed**

#### **Phase 2**: Virtual Machines  
- **vwanlab-nva-vm** deployed
- **TestVM-Spoke1** deployed
- NVA configuration applied

#### **Phase 3**: Route Server + Test VM
- Azure Route Server deployed
- **TestVM-Spoke3** deployed  
- VM configuration applied

#### **Phase 4**: VWAN Connections
- Spoke1 → VWAN Hub connection
- Spoke2 → VWAN Hub connection
- **TestVM-Spoke2** deployed as part of Spoke2 module

### **⚙️ VM Configuration Features**

#### **All VMs Include:**
- ✅ **Boot Diagnostics** enabled
- ✅ **Auto-Updates** enabled  
- ✅ **VM Agent** installed
- ✅ **RDP Access** (deployer IP only)
- ✅ **Standard_LRS** disks (cost optimized)
- ✅ **Managed Identity** support

#### **NVA VM Additional Features:**
- ✅ **IP Forwarding** enabled
- ✅ **RRAS Role** auto-installed
- ✅ **BGP Configuration** applied
- ✅ **Multiple NICs** supported
- ✅ **Custom Script Extension** for configuration

### **🔒 Security Configuration**

#### **Network Security Groups:**
- **spoke1-nsg**: Allows RDP (deployer IP), BGP (port 179), ICMP
- **spoke2-nsg**: Allows RDP (deployer IP), ICMP  
- **spoke3-nsg**: Allows RDP (deployer IP), BGP (port 179), ICMP

#### **Access Control:**
- **RDP Access**: Restricted to deployer public IP only
- **Admin Credentials**: Prompted securely during deployment
- **Public IPs**: Standard SKU with static allocation

### **📊 Resource Utilization**

#### **By Resource Type:**
- **Total VMs**: 4
- **Total NICs**: 4  
- **Total Public IPs**: 4
- **Total Disks**: 4 (OS disks)
- **Total NSGs**: 3 (shared where possible)

#### **By Performance Tier:**
- **High Performance**: 1 VM (NVA - Standard_B2s)
- **Standard Performance**: 3 VMs (Test VMs - Standard_B1s)

### **🎯 Optimization Notes**

#### **Current Optimizations:**
1. **Mixed VM Sizing**: High-spec NVA, cost-effective test VMs
2. **Standard Storage**: LRS disks for cost savings
3. **Shared NSGs**: Where network requirements align
4. **Minimal Public IPs**: Only where required for access

#### **Further Optimization Options:**
1. **Auto-Shutdown**: Schedule VMs for non-business hours (-25% cost)
2. **Spot Instances**: For test VMs only (-60-90% cost)
3. **Reserved Instances**: For long-term deployments (-40% cost)

---

**Summary**: The Azure VWAN Lab deploys **4 virtual machines** across 3 spoke VNets, with 1 production-grade NVA and 3 cost-optimized test VMs, totaling $60.59/month in VM costs.

*Updated: July 27, 2025*

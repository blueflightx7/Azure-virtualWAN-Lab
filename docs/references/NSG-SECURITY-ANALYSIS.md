# 🔒 Network Security Groups (NSG) Analysis - Azure VWAN Lab

## 📋 **Overview**

This document provides the **CORRECTED** analysis of NSG rules actually deployed. **CRITICAL SECURITY ISSUE FOUND AND FIXED**: The phased deployment was using insecure NSG rules.

### **� SECURITY ISSUE IDENTIFIED:**
The `spoke-vnet-infrastructure-only.bicep` file (used in phased deployments) contained **INSECURE** rules:
- `AllowSSH` from `*` to `*` (Port 22)
- `AllowRDP` from `*` to `*` (Port 3389)  
- `AllowHTTP` from `*` to `*` (Port 80)
- `AllowBGP` from `*` to `*` (Port 179)
- `AllowICMP` from `*` to `*` (All ICMP)

### **✅ SECURITY ISSUE FIXED:**
Updated `spoke-vnet-infrastructure-only.bicep` to use the same secure Zero Trust model as other templates.

---

## 🚀 **ROOT CAUSE ANALYSIS - Why You Saw Insecure Rules**

### **❌ The Problem:**
1. **`Deploy-VwanLab.ps1` ONLY uses phased deployment** - there is NO "general deploy"
2. **Phase 1 always deploys `phase1-core.bicep`**
3. **`phase1-core.bicep` always calls `spoke-vnet-infrastructure-only.bicep`**  
4. **`spoke-vnet-infrastructure-only.bicep` had INSECURE rules** (now fixed)

### **🔄 Template Synchronization Nightmare:**
```
Current Problematic Structure:
├── main.bicep → spoke-vnet-with-nva.bicep (SECURE)
├── phase1-core.bicep → spoke-vnet-infrastructure-only.bicep (WAS INSECURE)
├── spoke-vnet-with-nva.bicep (SECURE NSG rules)
├── spoke-vnet-direct.bicep (SECURE NSG rules)  
└── spoke-vnet-infrastructure-only.bicep (HAD INSECURE NSG rules) ⚠️
```

### **✅ FIXED:**
- Updated `spoke-vnet-infrastructure-only.bicep` to use same secure NSG rules
- All templates now have consistent Zero Trust security model

---

## 🌐 **Subnet-Level NSGs (Primary Security Enforcement)**

### **NSG 1: Spoke1 VNet Security Group**
**Resource**: `vwanlab-spoke1-nsg`  
**Location**: Applied to **VmSubnet** in Spoke1 VNet (NVA VM resides here)  
**Purpose**: Zero Trust security for all VMs in Spoke1 subnet  
**File**: `spoke-vnet-with-nva.bicep`

#### **🔧 Static Rules (Bicep Template)**
| Rule Name | Protocol | Port | Source | Destination | Priority | Direction | Status |
|-----------|----------|------|--------|-------------|----------|-----------|--------|
| `AllowBGPFromVirtualNetwork` | TCP | 179 | `VirtualNetwork` | `*` | 1100 | Inbound | ✅ **SECURE** |
| `AllowICMPFromVirtualNetwork` | ICMP | `*` | `VirtualNetwork` | `*` | 1200 | Inbound | ✅ **SECURE** |
| `DenyAllOtherInbound` | `*` | `*` | `*` | `*` | 4096 | Inbound | ✅ **DENY ALL** |

### **NSG 2: Spoke2 VNet Security Group**
**Resource**: `vwanlab-spoke2-nsg`  
**Location**: Applied to **VmSubnet** in Spoke2 VNet (Test VM resides here)  
**Purpose**: Zero Trust security for all VMs in Spoke2 subnet  
**File**: `spoke-vnet-direct.bicep`

#### **🔧 Static Rules (Bicep Template)**
| Rule Name | Protocol | Port | Source | Destination | Priority | Direction | Status |
|-----------|----------|------|--------|-------------|----------|-----------|--------|
| `AllowBGPFromVirtualNetwork` | TCP | 179 | `VirtualNetwork` | `*` | 1100 | Inbound | ✅ **SECURE** |
| `AllowICMPFromVirtualNetwork` | ICMP | `*` | `VirtualNetwork` | `*` | 1200 | Inbound | ✅ **SECURE** |
| `DenyAllOtherInbound` | `*` | `*` | `*` | `*` | 4096 | Inbound | ✅ **DENY ALL** |

### **NSG 3: Route Server Test VM Security Group**
**Resource**: `vwanlab-spoke3-test-nsg`  
**Location**: Applied to **Route Server Test VM NIC** in Spoke3 VNet  
**Purpose**: Zero Trust security for Route Server test VM  
**File**: `phase3-routeserver.bicep`

#### **🔧 Static Rules (Bicep Template)**
| Rule Name | Protocol | Port | Source | Destination | Priority | Direction | Status |
|-----------|----------|------|--------|-------------|----------|-----------|--------|
| `AllowBGPFromVirtualNetwork` | TCP | 179 | `VirtualNetwork` | `*` | 1100 | Inbound | ✅ **SECURE** |
| `AllowICMPFromVirtualNetwork` | ICMP | `*` | `VirtualNetwork` | `*` | 1200 | Inbound | ✅ **SECURE** |
| `DenyAllOtherInbound` | `*` | `*` | `*` | `*` | 4096 | Inbound | ✅ **DENY ALL** |

---

## 🔧 **Dynamic Security Rules (PowerShell Script)**

### **VM-Specific RDP Access Configuration**
The deployment script (`Deploy-VwanLab.ps1`) automatically adds **VM-specific** secure access rules to NSGs.

#### **🔧 Dynamic Rules Added Per VM**
| Rule Name Pattern | Protocol | Port | Source | Destination | Priority | Direction | Purpose |
|-----------|----------|------|--------|-------------|----------|-----------|---------|
| `Allow-RDP-From-Deployer-To-{VMName}-{IP}` | TCP | 3389 | `{DeployerIP}/32` | `{VMPrivateIP}/32` | 1000+ | Inbound | **VM-Specific RDP** |
| `Allow-ICMP-From-Deployer-To-{VMName}-{IP}` | ICMP | `*` | `{DeployerIP}/32` | `{VMPrivateIP}/32` | 1000+ | Inbound | **VM-Specific Ping** |

#### **🔧 Example Dynamic Rules**
```
# For NVA VM (10.1.0.128) from deployer IP 203.0.113.45:
Rule Name: "Allow-RDP-From-Deployer-To-nvavwanlabvm-203-0-113-45"
Source: 203.0.113.45/32 → Destination: 10.1.0.128/32 (Port 3389)

Rule Name: "Allow-ICMP-From-Deployer-To-nvavwanlabvm-203-0-113-45"  
Source: 203.0.113.45/32 → Destination: 10.1.0.128/32 (ICMP)
```

---

## 📊 **Security Architecture Analysis**

### **✅ What's Working Correctly**
1. **No VM-level NSGs**: All VMs rely on subnet-level security (Azure best practice)
2. **Zero Trust Implementation**: Explicit deny-all rules at priority 4096
3. **VirtualNetwork Scoping**: Internal traffic limited to VNet address space only
4. **VM-Specific Dynamic RDP**: Each VM gets targeted access rules to its private IP
5. **BGP Security**: BGP port 179 limited to VirtualNetwork scope only
6. **Deployer-IP Restriction**: RDP access restricted to deployer's public IP only

### **🏗️ Architecture Model**
```
Internet → [Deployer IP] → [Subnet NSG] → [VM Private IP]
                              ↓
                         Static Rules:
                         • BGP: VirtualNetwork → *
                         • ICMP: VirtualNetwork → *  
                         • Deny All: * → *
                              ↓
                         Dynamic Rules:
                         • RDP: DeployerIP/32 → VMPrivateIP/32
                         • ICMP: DeployerIP/32 → VMPrivateIP/32
```

---

## 🎯 **VM to NSG Mapping**

| VM Name | VM Private IP | NSG Resource | NSG Attachment | Security Model |
|---------|---------------|--------------|----------------|----------------|
| `vwanlab-nva-vm` | 10.1.0.128 | `vwanlab-spoke1-nsg` | Spoke1 VmSubnet | ✅ **Subnet-Level** |
| `vwanlab-test-vm` | 10.2.0.X | `vwanlab-spoke2-nsg` | Spoke2 VmSubnet | ✅ **Subnet-Level** |  
| `vwanlab-test-routeserver-vm` | 10.3.0.X | `vwanlab-spoke3-test-nsg` | Route Server Test VM NIC | ✅ **NIC-Level** |

### **❓ Questions for Clarification:**

1. **Route Server VM NSG**: Should the Route Server test VM NSG be moved to subnet-level for consistency?
2. **BGP Rule on Spoke2**: Is BGP rule needed on Spoke2 NSG if no BGP peers are expected there?
3. **Additional Security**: Do you want to add any application-specific rules (HTTP, HTTPS, etc.)?

---

## 🚀 **Recommendations**

### **✅ Current Implementation is Secure and Follows Best Practices**
1. **Subnet-level NSGs** provide efficient security management
2. **VM-specific destination rules** ensure granular access control  
3. **Zero Trust model** with explicit deny-all is implemented correctly
4. **Dynamic deployer-IP rules** provide secure temporary access

### **🔧 Optional Enhancements**
1. **Consistent NSG Placement**: Move Route Server test VM NSG to subnet-level
2. **Rule Optimization**: Remove BGP rule from Spoke2 if not needed
3. **Monitoring**: Enable NSG flow logs for security auditing
4. **Automation**: Add NSG rule cleanup function for old deployer IPs

### **✅ No Critical Issues Found**
The current implementation correctly follows Azure NSG best practices and provides robust security.

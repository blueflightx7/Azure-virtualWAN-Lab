# Spoke 3 Naming Convention Update Summary

## 📋 **Overview**

This document summarizes the comprehensive renaming of Route Server resources to use "Spoke 3" naming convention, making the architecture more consistent and intuitive.

## 🔄 **Changes Made**

### **1. Parameter Name Changes**

#### **main.bicep**
| Old Parameter | New Parameter | Description |
|---------------|---------------|-------------|
| `routeServerVnetName` | `spoke3VnetName` | Spoke 3 VNet name |
| `routeServerVnetAddressSpace` | `spoke3VnetAddressSpace` | Spoke 3 VNet address space |

#### **bicep/parameters/lab.bicepparam**
```bicep
// OLD
param routeServerVnetName = 'vnet-route-server-${environmentPrefix}'
param routeServerVnetAddressSpace = '10.3.0.0/16'

// NEW
param spoke3VnetName = 'vnet-spoke3-${environmentPrefix}'
param spoke3VnetAddressSpace = '10.3.0.0/16'
```

### **2. Module Name Changes**

#### **main.bicep**
```bicep
// OLD
module routeServerSpoke 'modules/spoke-vnet-route-server.bicep' = {
  name: 'route-server-spoke-deployment'

// NEW
module spoke3 'modules/spoke-vnet-route-server.bicep' = {
  name: 'spoke3-deployment'
```

#### **phases/phase1-core.bicep**
```bicep
// OLD
module routeServerVnet '../modules/spoke-vnet-infrastructure-only.bicep' = {
  name: 'route-server-vnet-infrastructure'

// NEW
module spoke3Vnet '../modules/spoke-vnet-infrastructure-only.bicep' = {
  name: 'spoke3-vnet-infrastructure'
```

### **3. Resource Name Changes**

#### **Azure Resource Names**
| Resource Type | Old Name | New Name |
|---------------|----------|----------|
| **VNet** | `{env}-route-server-vnet` | `{env}-spoke3-vnet` |
| **Route Server** | `{env}-route-server` | `{env}-spoke3-route-server` |
| **Route Server PIP** | `{env}-ars-pip` | `{env}-spoke3-route-server-pip` |
| **Test VM** | `{env}-test-routeserver-vm` | `{env}-spoke3-test-vm` |
| **Test VM NIC** | `{env}-test-routeserver-nic` | `{env}-spoke3-test-vm-nic` |
| **Test VM PIP** | `{env}-test3-pip` | `{env}-spoke3-test-vm-pip` |

### **4. Output Name Changes**

#### **main.bicep**
```bicep
// OLD
output routeServerVnetId string = routeServerSpoke.outputs.vnetId
output azureRouteServerId string = routeServerSpoke.outputs.routeServerId
output routeServerIpAddress string = routeServerSpoke.outputs.routeServerIpAddress

// NEW
output spoke3VnetId string = spoke3.outputs.vnetId
output spoke3RouteServerId string = spoke3.outputs.routeServerId
output spoke3RouteServerIpAddress string = spoke3.outputs.routeServerIpAddress
```

### **5. PowerShell Script Updates**

#### **Deploy-VwanLab.ps1**
```powershell
# OLD
$routeServerVmExists = Test-VmExists -ResourceGroupName $ResourceGroupName -VmName "vwanlab-test-routeserver-vm"
$allExpectedVms += @("vwanlab-test-routeserver-vm")

# NEW
$spoke3VmExists = Test-VmExists -ResourceGroupName $ResourceGroupName -VmName "vwanlab-spoke3-test-vm"
$allExpectedVms += @("vwanlab-spoke3-test-vm")
```

#### **Configure-NvaVm.ps1 & Configure-NvaBgp.ps1**
```powershell
# OLD
$routeServers = Get-AzResource | Where-Object { $_.Name -like "*route-server*" }

# NEW
$routeServers = Get-AzResource | Where-Object { $_.Name -like "*spoke3-route-server*" }
```

### **6. Documentation Updates**

#### **README.md**
- Updated "Proper BGP Architecture" descriptions
- Changed "Route Server VNet" to "Spoke 3 VNet"
- Updated flowchart references
- Clarified architecture descriptions

#### **Phase Descriptions**
- Phase 3: "Route Server" → "Spoke 3 Route Server"
- Updated all BGP peering references
- Clarified VM naming conventions

## 🎯 **Naming Convention Summary**

### **New Consistent Pattern**
```
Environment Prefix: vwanlab
├── Spoke 1: vwanlab-spoke1-* (NVA and test VM)
├── Spoke 2: vwanlab-spoke2-* (Direct VWAN connection)
└── Spoke 3: vwanlab-spoke3-* (Route Server and test VM)
```

### **Spoke 3 Resource Naming**
```
VNet:           vwanlab-spoke3-vnet
Route Server:   vwanlab-spoke3-route-server
Route Server IP: vwanlab-spoke3-route-server-pip
Test VM:        vwanlab-spoke3-test-vm
Test VM NIC:    vwanlab-spoke3-test-vm-nic
Test VM IP:     vwanlab-spoke3-test-vm-pip
NSG:            vwanlab-spoke3-nsg
```

## ✅ **Validation Completed**

All Bicep templates successfully compile:
- ✅ `az bicep build --file .\bicep\main.bicep`
- ✅ `az bicep build --file .\bicep\modules\spoke-vnet-route-server.bicep`
- ✅ `az bicep build --file .\bicep\phases\phase1-core.bicep`
- ✅ `az bicep build --file .\bicep\phases\phase3-routeserver.bicep`

## 🔧 **Impact Assessment**

### **Breaking Changes**
- ⚠️ **Existing deployments**: Will create new resources with new names
- ⚠️ **Parameters**: Old parameter names no longer valid
- ⚠️ **Scripts**: Updated VM name detection logic

### **Non-Breaking Changes**
- ✅ **Network topology**: No changes to IP addressing or architecture
- ✅ **Functionality**: BGP peering logic remains identical
- ✅ **Phase deployment**: Deployment phases unchanged

## 📅 **Migration Considerations**

### **For Existing Deployments**
1. **Option 1**: Clean deployment with new naming
2. **Option 2**: Manual resource renaming (complex)
3. **Option 3**: Parallel deployment and migration

### **Recommended Approach**
Deploy fresh lab environment with new naming convention for clean, consistent resource names.

---

*Updated: July 27, 2025*  
*Changes apply to: All Bicep templates, PowerShell scripts, and documentation*

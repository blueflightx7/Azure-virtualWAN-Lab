# Comparison: spoke-vnet-with-nva.bicep vs vm-nva.bicep

## Purpose & Architecture

### `spoke-vnet-with-nva.bicep` (Full Deployment Module)
- **Purpose**: Complete Spoke 1 VNet creation with embedded NVA and test VM
- **Scope**: Creates entire VNet infrastructure + VMs in one module
- **Use Case**: Full deployment scenario (non-phased)

### `vm-nva.bicep` (Phased Deployment Module)  
- **Purpose**: NVA VM only for existing VNet
- **Scope**: Creates only the NVA VM in pre-existing Spoke 1 VNet
- **Use Case**: Phased deployment (Phase 2)

## Key Differences

### 1. **Infrastructure Scope**

| Aspect | spoke-vnet-with-nva.bicep | vm-nva.bicep |
|--------|---------------------------|--------------|
| **VNet Creation** | ✅ Creates entire VNet | ❌ Uses existing VNet |
| **Subnets** | ✅ Creates NvaSubnet, VmSubnet | ❌ Uses existing subnets |
| **NSG** | ✅ Creates NSG with security rules | ❌ Uses existing NSG |
| **VMs Created** | 2 VMs (NVA + Test) | 1 VM (NVA only) |

### 2. **VM Configuration**

| Aspect | spoke-vnet-with-nva.bicep | vm-nva.bicep |
|--------|---------------------------|--------------|
| **NVA VM Name** | `${environmentPrefix}-spoke1-nva-vm` | `${environmentPrefix}-spoke1-nva-vm` |
| **NVA Computer Name** | `spoke1-nva-vm` | `spoke1-nva-vm` |
| **NVA NIC Name** | `${environmentPrefix}-nva-nic` | `${environmentPrefix}-spoke1-nva-nic` |
| **Test VM** | ✅ Includes test VM | ❌ No test VM |
| **Storage Type** | Premium_LRS (NVA), Standard_LRS (Test) | Standard_LRS (Cost optimized) |

### 3. **Network Configuration**

| Aspect | spoke-vnet-with-nva.bicep | vm-nva.bicep |
|--------|---------------------------|--------------|
| **IP Assignment** | Static IP (10.x.x.10) | Dynamic IP |
| **Subnet Reference** | Creates and references | References existing subnet |
| **Public IP Names** | `${environmentPrefix}-nva-pip`, `${environmentPrefix}-test1-pip` | `${environmentPrefix}-nva-pip` |

### 4. **Automation & Extensions**

| Aspect | spoke-vnet-with-nva.bicep | vm-nva.bicep |
|--------|---------------------------|--------------|
| **RRAS Installation** | ❌ Manual configuration required | ✅ Automated via VM extension |
| **Boot Diagnostics** | ❌ Not configured | ✅ Enabled with managed storage |
| **IP Forwarding** | ✅ Enabled on NIC | ✅ Enabled on NIC + OS level |

### 5. **Resource Dependencies**

#### spoke-vnet-with-nva.bicep Dependencies:
- Creates everything from scratch
- No external dependencies

#### vm-nva.bicep Dependencies:
- Requires existing `${environmentPrefix}-spoke1-vnet`
- Requires existing `NvaSubnet` in the VNet
- Assumes Phase 1 infrastructure is deployed

## Current Usage in Codebase

### spoke-vnet-with-nva.bicep Usage:
```bicep
// Referenced in main.bicep (line 89) - Full deployment
module spoke1 'modules/spoke-vnet-with-nva.bicep' = {
  name: 'spoke1-deployment'
  params: {
    vnetName: '${environmentPrefix}-spoke1-vnet'
    // ... other params
  }
}
```

### vm-nva.bicep Usage:
```bicep
// Referenced in phase2-vms.bicep (line 34) - Phased deployment
module nvaVm 'modules/vm-nva.bicep' = if (deployNvaVm) {
  name: 'nva-vm-deployment'
  params: {
    environmentPrefix: environmentPrefix
    // ... other params
  }
}
```

## Recommendation for Phased-Only Approach

Since you want **ONLY phased deployment**, here's what should happen:

### ✅ Keep: vm-nva.bicep
- **Reason**: Used in Phase 2 deployment
- **Purpose**: Creates NVA VM in existing Spoke 1 VNet
- **Naming**: Already uses spoke1 naming convention
- **Features**: Has automated RRAS installation via extension

### 🗂️ Archive: spoke-vnet-with-nva.bicep  
- **Reason**: Only used in full deployment (main.bicep)
- **Conflict**: Creates duplicate infrastructure
- **Issue**: No automated RRAS installation
- **Status**: Should be moved to archive/ folder

## Phase 2 Architecture (Current Phased Approach)

```
Phase 2: VM Deployment
├── vm-nva.bicep → Creates: vwanlab-spoke1-nva-vm (in Spoke 1)
└── vm-test.bicep → Creates: vwanlab-spoke2-test-vm (in Spoke 2)
```

## Conclusion

The `vm-nva.bicep` module is more appropriate for phased deployment because:
1. ✅ Works with existing VNet infrastructure  
2. ✅ Includes automated RRAS configuration
3. ✅ Cost-optimized storage settings
4. ✅ Proper boot diagnostics
5. ✅ Uses spoke1 naming convention

The `spoke-vnet-with-nva.bicep` module should be archived since it's designed for full deployment scenarios that you're no longer using.

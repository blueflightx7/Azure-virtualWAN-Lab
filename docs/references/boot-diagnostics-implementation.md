# Boot Diagnostics Implementation Summary

## Overview

Boot diagnostics has been enabled across all VM templates and deployment scripts using the latest Azure best practices with managed storage accounts.

## Changes Made

### 1. Bicep Template Updates

Updated the following templates to include boot diagnostics with managed storage:

- **`bicep/modules/vm-nva.bicep`** - NVA VM template
- **`bicep/modules/vm-test.bicep`** - Test VM template  
- **`bicep/phases/phase3-routeserver.bicep`** - Route Server test VM

**Configuration Added:**
```bicep
diagnosticsProfile: {
  bootDiagnostics: {
    enabled: true
    // storageUri omitted to use managed storage (Azure best practice)
  }
}
```

### 2. PowerShell Script Enhancements

**Deploy-VwanLab.ps1 Updates:**
- Added `Enable-VmBootDiagnostics` function
- Integrated boot diagnostics enablement in Phase 2 and Phase 3 post-deployment configuration
- Automatic enablement for both new and existing VMs

**New Standalone Script:**
- **`scripts/Enable-BootDiagnostics.ps1`** - Dedicated script to enable boot diagnostics on existing VMs

## Technical Implementation

### Azure Best Practices Used

1. **API Version**: Uses `Microsoft.Compute/virtualMachines@2024-07-01` (latest)
2. **Managed Storage**: No `storageUri` specified - Azure automatically provides managed storage
3. **Cost Optimization**: ~$0.05/GB per month for diagnostic data only
4. **Security**: Managed storage accounts are automatically secured by Azure

### Supported Since

- **ARM/Bicep**: API version 2020-06-01 and later
- **Azure CLI**: Version 2.12.0 and later  
- **Azure PowerShell**: Version 6.6.0 and later

### Benefits

1. **Troubleshooting**: Console output and screenshots for VM boot issues
2. **Cost Effective**: Only pay for actual diagnostic data stored
3. **Automatic Management**: No storage account configuration required
4. **Performance**: Faster VM deployment (no storage account dependency)
5. **Security**: Azure-managed storage with automatic security controls

## Usage

### For New Deployments

Boot diagnostics is automatically enabled when deploying VMs using:
```powershell
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### For Existing VMs

Use the dedicated script to enable boot diagnostics on existing infrastructure:
```powershell
# Enable on all VMs in resource group
.\scripts\Enable-BootDiagnostics.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Enable on specific VM
.\scripts\Enable-BootDiagnostics.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-nva-vm"
```

### Azure Portal Access

1. Navigate to Virtual Machine in Azure Portal
2. Go to **Help** → **Boot diagnostics**
3. View console logs and screenshots
4. Download diagnostic data if needed

## Cost Impact

- **Storage Cost**: ~$0.05/GB per month for diagnostic data only
- **No Additional Charges**: No compute or transaction costs
- **Automatic Cleanup**: Logs overwritten when total size exceeds 1GB
- **Billing**: Costs appear on VM resource, not separate storage account

## Validation

All Bicep templates have been validated and compile successfully:
```bash
az bicep build --file bicep/modules/vm-nva.bicep
az bicep build --file bicep/modules/vm-test.bicep  
az bicep build --file bicep/phases/phase3-routeserver.bicep
```

## Limitations

1. **Premium Storage**: Not supported for boot diagnostics storage
2. **Zone Redundant Storage**: Not supported for boot diagnostics
3. **Custom Retention**: No configurable retention period (automatic 1GB limit)
4. **ARM Only**: Only available for Azure Resource Manager VMs (not classic)

## References

- [Azure Boot Diagnostics Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/boot-diagnostics)
- [ARM Template Best Practices](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/best-practices)
- [Azure VM Troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/windows/boot-diagnostics)

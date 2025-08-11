# VM Naming Standardization Summary

## Overview
This document summarizes the comprehensive VM naming standardization implemented across all Azure VWAN Lab resources to provide consistent, spoke-based naming conventions.

## VM Naming Convention Changes

### Previous Naming Patterns
- **Inconsistent**: Mix of generic names (`vwanlab-nva-vm`, `vwanlab-test-vm`) and spoke-specific names (`TestVM-Spoke1`, `TestVM-Spoke2`, `TestVM-Spoke3`)
- **Confusing**: No clear pattern indicating which spoke each VM belongs to
- **Maintenance Issues**: Scripts and templates used different naming schemes

### New Standardized Naming Convention
- **Pattern**: `{environmentPrefix}-{spoke}-{role}-vm`
- **Consistent**: All VMs follow the same pattern
- **Clear**: Each VM name clearly indicates its spoke and role

## Updated VM Names

| Old VM Name | New VM Name | Spoke | Role | Location |
|-------------|-------------|-------|------|----------|
| `vwanlab-nva-vm` | `vwanlab-spoke1-nva-vm` | Spoke 1 | NVA (Network Virtual Appliance) | spoke-vnet-with-nva.bicep |
| `TestVM-Spoke1` | `vwanlab-spoke1-test-vm` | Spoke 1 | Test VM | spoke-vnet-with-nva.bicep |
| `TestVM-Spoke2` | `vwanlab-spoke2-test-vm` | Spoke 2 | Test VM | spoke-vnet-direct.bicep / vm-test.bicep |
| `TestVM-Spoke3` | `vwanlab-spoke3-test-vm` | Spoke 3 | Test VM | spoke-vnet-route-server.bicep |

## Computer Names (Internal OS Names)

| VM Name | Computer Name |
|---------|---------------|
| `vwanlab-spoke1-nva-vm` | `spoke1-nva-vm` |
| `vwanlab-spoke1-test-vm` | `spoke1-test-vm` |
| `vwanlab-spoke2-test-vm` | `spoke2-test-vm` |
| `vwanlab-spoke3-test-vm` | `spoke3-test-vm` |

## Files Updated

### Bicep Templates
- **bicep/modules/spoke-vnet-with-nva.bicep**
  - Updated NVA VM name: `${environmentPrefix}-spoke1-nva-vm`
  - Updated NVA computer name: `spoke1-nva-vm`
  - Updated Test VM name: `${environmentPrefix}-spoke1-test-vm`
  - Updated Test VM computer name: `spoke1-test-vm`

- **bicep/modules/spoke-vnet-direct.bicep**
  - Updated Test VM name: `${environmentPrefix}-spoke2-test-vm`
  - Updated Test VM computer name: `spoke2-test-vm`

- **bicep/modules/spoke-vnet-route-server.bicep**
  - Updated Test VM name: `${environmentPrefix}-spoke3-test-vm`
  - Updated Test VM computer name: `spoke3-test-vm`

- **bicep/modules/vm-test.bicep**
  - Updated VM name: `${environmentPrefix}-spoke2-test-vm`
  - Updated computer name: `spoke2-test-vm`

- **bicep/phases/phase2-vms.bicep**
  - Updated output names to reflect new naming convention

### PowerShell Scripts
- **scripts/Deploy-VwanLab.ps1**
  - Updated all VM references to use new naming convention
  - Updated expected VM lists for deployment validation
  - Updated conditional deployment logic

- **scripts/Configure-NvaBgp.ps1**
  - Updated default VM name parameter
  - Updated documentation examples

- **scripts/Configure-NvaVm.ps1**
  - Updated documentation examples

- **scripts/Enable-BootDiagnostics.ps1**
  - Updated documentation examples

- **scripts/Fix-RrasService.ps1**
  - Updated documentation examples

- **scripts/Get-BgpStatus.ps1**
  - Updated default VM name parameter
  - Updated documentation

- **scripts/Validate-RrasConfiguration.ps1**
  - Updated documentation examples

## VM Deployment Summary

| Spoke | VMs Count | VM Names | VM Size | RAM | Purpose |
|-------|-----------|----------|---------|-----|---------|
| Spoke 1 | 2 | `vwanlab-spoke1-nva-vm`<br>`vwanlab-spoke1-test-vm` | Standard_B2s<br>Standard_B1s | 2GB<br>1GB | NVA + Test |
| Spoke 2 | 1 | `vwanlab-spoke2-test-vm` | Standard_B1s | 1GB | Test |
| Spoke 3 | 1 | `vwanlab-spoke3-test-vm` | Standard_B1s | 1GB | Test |
| **Total** | **4** | | | **5GB** | |

## Deployment Architecture

### Phase-Based Deployment
- **Phase 1**: Core infrastructure (VWAN Hub, VNets)
- **Phase 2**: VMs (Spoke 1: NVA + Test, Spoke 2: Test)
- **Phase 3**: Route Server and Spoke 3 Test VM
- **Phase 4**: VWAN connections and peering
- **Phase 5**: BGP configuration

### VM Distribution by Phase
- **Phase 2**: `vwanlab-spoke1-nva-vm`, `vwanlab-spoke1-test-vm`, `vwanlab-spoke2-test-vm`
- **Phase 3**: `vwanlab-spoke3-test-vm`

## Benefits of Standardization

1. **Clarity**: Each VM name clearly indicates its spoke and role
2. **Consistency**: All VMs follow the same naming pattern
3. **Maintainability**: Scripts and templates use consistent references
4. **Scalability**: Pattern can easily accommodate additional spokes
5. **Documentation**: Names are self-documenting

## Validation

All Bicep templates compile successfully with the new naming convention:
- ✅ Main template (main.bicep)
- ✅ All spoke modules
- ✅ All phase templates
- ✅ VM modules

## Cost Impact

No cost impact - this is purely a naming standardization that doesn't change:
- VM sizes or specifications
- Number of VMs deployed
- Resource configuration
- Network topology

**Total Monthly Cost Remains**: ~$91.51/month (with current 2025 pricing)

---
*Updated: January 2025*
*Part of Azure VWAN Lab maintenance and standardization effort*

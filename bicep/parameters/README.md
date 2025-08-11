# Bicep Parameter Files - Usage Guide

## Overview

The VWAN Lab uses **phased deployment** with different parameter files for different scenarios:

## 🚨 Important Notes

- **Deploy-VwanLab.ps1 script** builds parameters dynamically - it does NOT use .bicepparam files
- **Parameter files are for manual deployment** and reference purposes only
- **main.bicep is empty** - use phase-specific templates for manual deployment

## Parameter Files

### 1. `lab.bicepparam` (Phase 1 - Core Infrastructure)
```bash
# Deploy core infrastructure manually
az deployment group create \
  --resource-group "rg-vwanlab" \
  --template-file "./bicep/phases/phase1-core.bicep" \
  --parameters "./bicep/parameters/lab.bicepparam"
```

**Contains:**
- Environment prefix and region
- VWAN and VNet configurations
- Network address spaces
- Tags and optional deployer IP

### 2. `lab-phase2-vms.bicepparam` (Phase 2 - Virtual Machines)
```bash
# Deploy VMs manually
az deployment group create \
  --resource-group "rg-vwanlab" \
  --template-file "./bicep/phases/phase2-vms.bicep" \
  --parameters "./bicep/parameters/lab-phase2-vms.bicepparam"
```

**Contains:**
- VM credentials (adminUsername/adminPassword)
- Conditional deployment flags (deployNvaVm/deployTestVm)
- VM size configuration

### 3. `lab-phase3-routeserver.bicepparam` (Phase 3 - Route Server)
```bash
# Deploy Route Server manually
az deployment group create \
  --resource-group "rg-vwanlab" \
  --template-file "./bicep/phases/phase3-routeserver.bicep" \
  --parameters "./bicep/parameters/lab-phase3-routeserver.bicepparam"
```

**Contains:**
- Route Server configuration
- Spoke3 Test VM settings
- Security configuration

## Recommended Usage

### ✅ **Use the PowerShell Script (Recommended)**
```powershell
# Automated phased deployment with dynamic parameters
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab"
```

### 🔧 **Manual Deployment (Advanced)**
```bash
# Deploy phases individually with parameter files
az deployment group create --template-file "./bicep/phases/phase1-core.bicep" --parameters "./bicep/parameters/lab.bicepparam"
az deployment group create --template-file "./bicep/phases/phase2-vms.bicep" --parameters "./bicep/parameters/lab-phase2-vms.bicepparam"
# ... etc
```

## Parameter Architecture

```
Deploy-VwanLab.ps1 Script Flow:
├── Builds $baseParameters dynamically
├── Checks VM existence for conditional deployment  
├── Passes parameters via --parameters flags
└── Deploys each phase with appropriate parameters

Manual Deployment Flow:
├── Choose phase-specific .bicepparam file
├── Edit parameters for your environment
└── Deploy with az deployment group create
```

## Security Notes

- **Change default passwords** in production
- **Set deployerPublicIP** to your IP for secure RDP access
- **VM credentials** are only needed when creating new VMs (deployXxxVm = true)

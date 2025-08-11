# Legacy Components Archive

This folder contains legacy scripts and templates that have been consolidated into the unified deployment approach. These components are preserved for reference and backward compatibility.

## Archive Structure

```
archive/
├── legacy-scripts/              # Consolidated deployment scripts
│   ├── Deploy-VwanLab.ps1      # Original deployment script
│   ├── Deploy-VwanLab-Enhanced.ps1    # Enhanced deployment with cleanup
│   ├── Deploy-VwanLab-Phased.ps1      # Phased deployment approach  
│   ├── Cleanup-ResourceGroups.ps1     # Standalone cleanup system
│   ├── Manage-Cleanup.ps1             # Cleanup management wrapper
│   └── Manage-Cleanup-Legacy.ps1      # Legacy cleanup functionality
└── legacy-templates/           # ARM template support
    └── arm-templates/          # ARM templates (replaced by Bicep)
        ├── main.json
        └── parameters/
            └── lab.parameters.json
```

## What Was Consolidated

### **Multiple Deployment Scripts → Single Unified Script**

**Before (Multiple Scripts):**
- `Deploy-VwanLab.ps1` - Basic deployment
- `Deploy-VwanLab-Enhanced.ps1` - Enhanced with cleanup
- `Deploy-VwanLab-Phased.ps1` - Timeout-resistant phased deployment
- `Deploy-Optimized-Demo.ps1` - Cost-optimized deployment

**After (Unified Script):**
- `scripts/Deploy-VwanLab.ps1` - Single script with all features:
  - Phased deployment (timeout-resistant)
  - Cost optimization modes (Standard/Optimized/Minimal)
  - Automatic cleanup integration
  - Enhanced error handling
  - Flexible IP schema selection

### **ARM Template Support → Bicep-First Approach**

**Before:**
- ARM templates (`arm-templates/main.json`) 
- Bicep templates (`bicep/main.bicep`)
- Dual maintenance and documentation

**After:**
- Bicep-first approach with automatic ARM compilation
- Single source of truth for infrastructure
- Simplified maintenance and updates

### **Cleanup Script Proliferation → Integrated Management**

**Before:**
- `Cleanup-ResourceGroups.ps1` - Standalone cleanup
- `Manage-Cleanup.ps1` - Cleanup management
- `Manage-Cleanup-Legacy.ps1` - Legacy support

**After:**
- Cleanup integrated into main deployment script
- .NET automation suite handles advanced cleanup scenarios
- Simplified user experience

## Migration Guide

### **From Legacy Scripts to Unified Deployment**

#### **Old Approach:**
```powershell
# Multiple scripts for different scenarios
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-test" -CleanupResourceGroup "rg-old"
.\scripts\Deploy-VwanLab-Phased.ps1 -ResourceGroupName "rg-prod" -Phase 1
.\scripts\Deploy-Optimized-Demo.ps1 -ResourceGroupName "rg-demo" -ShowCostAnalysis
```

#### **New Approach:**
```powershell
# Single script with all features
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-test" -DeploymentMode "Optimized" -CleanupOldResourceGroup "rg-old"
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-prod" -Phase 1
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-demo" -DeploymentMode "Optimized" -WhatIf
```

#### **Migration Command Reference:**

| Legacy Command | New Unified Command |
|----------------|-------------------|
| `Deploy-VwanLab.ps1 -ParameterFile lab.bicepparam` | `Deploy-VwanLab.ps1 -ResourceGroupName "rg-name" -DeploymentMode "Standard"` |
| `Deploy-VwanLab-Enhanced.ps1 -IpSchema "enterprise"` | `Deploy-VwanLab.ps1 -ResourceGroupName "rg-name" -IpSchema "enterprise"` |
| `Deploy-VwanLab-Phased.ps1 -Phase 2` | `Deploy-VwanLab.ps1 -ResourceGroupName "rg-name" -Phase 2` |
| `Deploy-Optimized-Demo.ps1 -ShowCostAnalysis` | `Deploy-VwanLab.ps1 -ResourceGroupName "rg-name" -DeploymentMode "Optimized"` |
| `Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-old"` | `Deploy-VwanLab.ps1 -ResourceGroupName "rg-new" -CleanupOldResourceGroup "rg-old"` |

### **From ARM Templates to Bicep**

#### **Old Approach:**
```powershell
.\scripts\Deploy-VwanLab.ps1 -TemplateFile .\arm-templates\main.json -ParameterFile .\arm-templates\parameters\lab.parameters.json
```

#### **New Approach:**
```powershell
# Bicep templates are used automatically
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-name" -DeploymentMode "Standard"
```

## Why These Changes Were Made

### **1. User Experience Simplification**
- **Before:** Users needed to choose between 4+ different scripts
- **After:** Single script with intuitive parameters
- **Benefit:** Reduced learning curve and decision fatigue

### **2. Maintenance Overhead Reduction**
- **Before:** Multiple scripts with duplicated logic
- **After:** Single script with consolidated features
- **Benefit:** Easier maintenance, testing, and documentation

### **3. Feature Consistency**
- **Before:** Features scattered across different scripts
- **After:** All features available in every deployment
- **Benefit:** Users get best practices by default

### **4. Error Handling Improvement**
- **Before:** Inconsistent error handling across scripts
- **After:** Unified error handling and recovery
- **Benefit:** More reliable deployments

## Backward Compatibility

### **Legacy Script Support**
All legacy scripts in the archive folder remain functional:

```powershell
# Legacy scripts still work
.\archive\legacy-scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-test"
.\archive\legacy-scripts\Deploy-VwanLab-Phased.ps1 -ResourceGroupName "rg-prod"
```

### **ARM Template Support**
ARM templates are preserved and can still be used:

```powershell
# ARM templates still supported via legacy scripts
.\archive\legacy-scripts\Deploy-VwanLab.ps1 -TemplateFile .\archive\legacy-templates\arm-templates\main.json
```

### **Parameter File Compatibility**
Existing parameter files continue to work:

```powershell
# Legacy parameter files supported
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-name" -DeploymentMode "Standard"
# Automatically uses .\bicep\parameters\lab.bicepparam
```

## When to Use Legacy Components

### **Use Legacy Scripts When:**
- 🔄 **Existing automation** relies on specific script names
- 📚 **Training materials** reference old script names
- 🔧 **Custom modifications** were made to legacy scripts
- ⏰ **Migration timeline** doesn't allow immediate updates

### **Use New Unified Approach When:**
- ✅ **New deployments** or fresh automation
- ✅ **Simplified workflows** are desired
- ✅ **Latest features** and improvements are needed
- ✅ **Maintenance overhead** should be minimized

## Archive Maintenance

### **Preservation Policy**
- Legacy scripts are preserved for **12 months** from consolidation date
- Critical bug fixes will be applied to both legacy and new scripts
- New features will only be added to the unified script
- Documentation will focus on the new unified approach

### **Support Timeline**
- **Phase 1 (Months 1-3):** Full support for both legacy and new scripts
- **Phase 2 (Months 4-9):** Legacy scripts receive bug fixes only
- **Phase 3 (Months 10-12):** Legacy scripts receive critical security fixes only
- **Phase 4 (12+ months):** Legacy scripts are unsupported but preserved for reference

### **Migration Assistance**
For help migrating from legacy scripts to the unified approach:

1. **Review the migration guide** above
2. **Test new commands** in development environments
3. **Update automation scripts** gradually
4. **Contact the team** if specific legacy functionality is missing

## Benefits of Consolidation

### **For Users**
- 🎯 **Single command to learn** instead of multiple scripts
- 🚀 **Faster deployment** with optimized code paths
- 🛡️ **Better error handling** and recovery
- 📊 **Consistent cost analysis** across all deployment modes
- 🔧 **Unified troubleshooting** experience

### **For Maintainers**
- 📝 **Reduced documentation** maintenance
- 🧪 **Simplified testing** with single code path
- 🐛 **Easier bug fixes** applied once
- 🔄 **Faster feature development** 
- 📈 **Better code quality** through consolidation

### **For Enterprise**
- 🏢 **Standardized deployments** across teams
- 📋 **Simplified compliance** and auditing
- 🎓 **Reduced training** requirements
- 🔒 **Consistent security** practices
- 💰 **Lower maintenance** costs

---

**Note:** This archive represents the evolution of the Azure VWAN lab from multiple specialized scripts to a unified, enterprise-ready deployment solution. The consolidation maintains all functionality while significantly improving user experience and maintainability.

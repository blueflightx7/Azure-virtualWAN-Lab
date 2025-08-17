# Azure Firewall SKU and Password Handling Updates

## Summary of Changes Made

### 1. Azure Firewall SKU Changed from Premium to Standard

#### Bicep Templates Updated:
- **`bicep/phases/phase3-multiregion-firewall.bicep`**
  - Changed default `firewallSku` parameter from `'Premium'` to `'Standard'`
  - Updated comments to reflect Standard SKU deployment

#### Scripts Updated:
- **`scripts/Deploy-VwanLab.ps1`**
  - Updated description and comments to reference Firewall Standard
  - Updated phase descriptions and architecture references
- **`scripts/Deploy-VwanLab-MultiRegion.ps1`**
  - Updated all references from Premium to Standard
  - Changed `firewallSku = 'Standard'` in deployment parameters

#### Documentation Updated:
- **`.github/copilot-instructions.md`** - Updated architecture references
- **`README.md`** - Updated main description, features list, and cost analysis
- **`docs/architecture.md`** - Updated architectural description and features
- **`docs/developer-guide.md`** - Updated component references
- **`docs/multiregion-architecture.md`** - Updated deployment descriptions and cost analysis
- **`docs/multiregion-cost-analysis-2025.md`** - Updated cost calculations and optimization recommendations
- **`docs/troubleshooting.md`** - Updated troubleshooting sections

### 2. Enhanced Password Handling

#### New Functions Added:
- **`Test-PhaseNeedsVmCredentials`** - Determines if a specific phase requires VM credentials
  - Returns `true` for Phase 2 (Virtual Machines deployment)
  - Returns `false` for all other phases

#### Enhanced `Get-VmCredentials` Function:
- **Password Confirmation** - Now requires password to be entered twice and validates they match
- **Contextual Messaging** - Shows which phase requires the credentials
- **Parameter Support** - Added `RequiredForPhase` parameter for better user feedback

#### Updated Deployment Logic:
- **Lazy Credential Collection** - Credentials are only collected when actually needed
- **Phase-Specific Prompting** - Only prompts for credentials when deploying phases that require VMs
- **Cached Credentials** - Once collected, credentials are reused for subsequent phases

### 3. Cost Savings

The change from Azure Firewall Premium to Standard provides significant cost savings:

| Component | Premium Cost | Standard Cost | Monthly Savings |
|-----------|-------------|---------------|-----------------|
| **Azure Firewall** | $1,402.50 | $693.75 | **$708.75** |
| **Total Lab Cost** | ~$3,500 | ~$2,791.25 | **$708.75 (20% reduction)** |

### 4. Benefits of Changes

#### Azure Firewall Standard Benefits:
- **Cost Optimization**: 50% reduction in firewall costs
- **Sufficient Features**: Provides network filtering, application rules, and NAT rules
- **Lab Appropriate**: Standard tier is perfect for learning and demonstration scenarios
- **Easier Management**: Simpler configuration suitable for educational purposes

#### Password Handling Benefits:
- **Better Security**: Password confirmation prevents typos
- **Improved UX**: Only prompts when actually needed
- **Reduced Friction**: Infrastructure-only deployments don't require VM credentials
- **Flexible Usage**: Supports both parameter-based and interactive credential collection

### 5. Backward Compatibility

All changes maintain backward compatibility:
- **Parameter Support**: AdminUsername and AdminPassword parameters still work as before
- **Infrastructure Mode**: DeploymentMode 'InfrastructureOnly' continues to skip credential collection
- **Phase Deployment**: Specific phase deployment (e.g., `-Phase 1`) works without credential prompts unless VMs are involved

### 6. Testing Recommendations

To test the enhanced password handling:

```powershell
# Test Phase 1 deployment (should not prompt for credentials)
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-test-firewall" -Phase 1 -WhatIf

# Test Phase 2 deployment (should prompt for credentials with confirmation)
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-test-firewall" -Phase 2 -WhatIf

# Test full deployment with provided credentials (should not prompt)
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-test-firewall" -AdminUsername "azureuser" -AdminPassword (ConvertTo-SecureString "SecurePassword123!" -AsPlainText -Force) -WhatIf
```

### 7. Files Modified

#### Bicep Templates:
- `bicep/phases/phase3-multiregion-firewall.bicep`

#### PowerShell Scripts:
- `scripts/Deploy-VwanLab.ps1`
- `scripts/Deploy-VwanLab-MultiRegion.ps1`

#### Documentation:
- `.github/copilot-instructions.md`
- `README.md`
- `docs/architecture.md`
- `docs/developer-guide.md`
- `docs/multiregion-architecture.md`
- `docs/multiregion-cost-analysis-2025.md`
- `docs/troubleshooting.md`

All changes have been implemented and are ready for testing and deployment.

# Azure Virtual WAN Lab - Enhanced Troubleshooting Guide

This comprehensive guide covers all common issues and their solutions encountered during Azure Virtual WAN lab deployment, including the **new unified deployment system** with automated VM configuration and security features.

## 🆕 **What's New in This Guide**

### ✅ **Enhanced Troubleshooting Coverage**
- **Unified Deployment System Issues**: Troubleshooting for enhanced Deploy-VwanLab.ps1 script
- **Automatic VM Configuration Problems**: Solutions for RDP and RRAS setup issues
- **Credential Validation Issues**: Resolving username and password complexity problems
- **Security Configuration Issues**: Troubleshooting automatic NSG and firewall setup
- **Cleanup System Problems**: Solutions for background cleanup and job management
- **IP Schema Conflicts**: Resolving addressing scheme issues

### ✅ **Automated Diagnostic Tools**
- **Enhanced Troubleshooting Script**: Advanced diagnostic capabilities
- **Real-time Monitoring**: Live status checking and issue detection
- **Automated Recovery**: Self-healing mechanisms for common problems
- **RRAS Installation Logging**: Detailed logs for NVA configuration troubleshooting

## Table of Contents

1. [🚀 Unified Deployment System Issues](#-unified-deployment-system-issues) - **NEW**
2. [🔐 Credential and Security Issues](#-credential-and-security-issues) - **NEW**
3. [🖥️ Automatic VM Configuration Issues](#️-automatic-vm-configuration-issues) - **NEW**
4. [🧹 Cleanup System Troubleshooting](#-cleanup-system-troubleshooting) - **ENHANCED**
5. [🌐 IP Schema and Networking Issues](#-ip-schema-and-networking-issues) - **ENHANCED**
6. [Prerequisites and Setup Issues](#prerequisites-and-setup-issues)
7. [Bicep and Azure CLI Issues](#bicep-and-azure-cli-issues) - **UPDATED**
8. [Template Compilation and Validation Issues](#template-compilation-and-validation-issues) - **ENHANCED**
9. [Deployment Scope Issues](#deployment-scope-issues)
10. [Parameter and Path Issues](#parameter-and-path-issues)
11. [PowerShell Script Issues](#powershell-script-issues) - **ENHANCED**
12. [Authentication and Permissions](#authentication-and-permissions)
13. [🤖 Automated Troubleshooting Tools](#-automated-troubleshooting-tools) - **ENHANCED**

---

## 🚀 **Unified Deployment System Issues**

### Issue: Enhanced Deploy-VwanLab.ps1 Script Issues
**Symptoms:**
- Script fails during credential collection
- Automatic RDP configuration not working
- RRAS installation fails

**Solution:**
```powershell
# Verify script exists and has latest enhancements
Test-Path ".\scripts\Deploy-VwanLab.ps1"

# Check script version (should include new functions)
Get-Content ".\scripts\Deploy-VwanLab.ps1" | Select-String "Test-PasswordComplexity|Get-UserCredentials|Enable-VmRdpAccess"

# If missing enhancements, ensure you have the latest version
git pull origin main

# Run with enhanced logging
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-test" -Verbose
```

### Issue: Credential Validation Failures
**Symptoms:**
- "Password does not meet complexity requirements"
- "Username not allowed"
- Deployment stops at credential validation

**Solution:**
```powershell
# Test password complexity manually
function Test-Password {
    param([string]$password)
    
    $hasLower = $password -cmatch '[a-z]'
    $hasUpper = $password -cmatch '[A-Z]'
    $hasDigit = $password -match '\d'
    $hasSpecial = $password -match '[^a-zA-Z0-9]'
    
    $complexityCount = @($hasLower, $hasUpper, $hasDigit, $hasSpecial) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    
    Write-Host "Password analysis:"
    Write-Host "  Length: $($password.Length) (needs 8-123)"
    Write-Host "  Has lowercase: $hasLower"
    Write-Host "  Has uppercase: $hasUpper"
    Write-Host "  Has digit: $hasDigit"
    Write-Host "  Has special: $hasSpecial"
    Write-Host "  Complexity count: $complexityCount (needs 3)"
    
    return ($password.Length -ge 8 -and $password.Length -le 123 -and $complexityCount -ge 3)
}

# Example valid password
Test-Password "MySecureP@ssw0rd!"
```

---

## 🔐 **Credential and Security Issues**

### Issue: Interactive Credential Prompts Not Working
**Symptoms:**
- Script hangs during credential collection
- SecureString conversion errors
- Credential prompts not appearing

**Solution:**
```powershell
# Test credential collection manually
$creds = Get-Credential -Message "Test credential prompt"
if ($creds) {
    Write-Host "Username: $($creds.UserName)"
    Write-Host "Password received: $($creds.Password.Length -gt 0)"
}

# Alternative: Use pre-specified credentials
$securePassword = ConvertTo-SecureString "YourP@ssw0rd!" -AsPlainText -Force
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-test" -VmUsername "azureuser" -VmPassword $securePassword
```

### Issue: NSG RDP Rule Creation Fails
**Symptoms:**
- "Cannot detect deployer IP"
- "Failed to create NSG rule"
- RDP access not working after deployment

**Solution:**
```powershell
# Manually check deployer IP detection
$deployerIP = (Invoke-RestMethod -Uri "https://ipinfo.io/ip" -TimeoutSec 10).Trim()
Write-Host "Detected IP: $deployerIP"

# Verify NSG rules after deployment
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-vwanlab-demo" -Name "*nsg*"
$nsg.SecurityRules | Where-Object { $_.Name -like "*RDP*" } | Format-Table Name, SourceAddressPrefix, DestinationPortRange

# Manually add RDP rule if needed
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-vwanlab-demo" -Name "your-nsg-name"
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-RDP-Manual" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix "$deployerIP/32" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$nsg | Set-AzNetworkSecurityGroup
```

---

## 🖥️ **Automatic VM Configuration Issues**

### Issue: RDP Access Not Working After Deployment
**Symptoms:**
- Cannot connect via RDP to VMs
- "Remote Desktop can't connect to the remote computer"
- Connection timeout errors

**Diagnostic Steps:**
```powershell
# Check if VMs are running
Get-AzVM -ResourceGroupName "rg-vwanlab-demo" -Status | Format-Table Name, PowerState, Location

# Check NSG rules
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-vwanlab-demo"
$nsg.SecurityRules | Where-Object { $_.DestinationPortRange -eq "3389" } | Format-Table Name, Access, SourceAddressPrefix

# Test network connectivity
Test-NetConnection -ComputerName "vm-public-ip" -Port 3389

# Check Windows Firewall status on VM (if you can access via serial console)
# Run this on the VM itself:
netsh advfirewall firewall show rule name="Remote Desktop*"
```

**Solution:**
```powershell
# Re-run RDP configuration manually
.\scripts\Configure-NvaVm.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-nva-vm"

# Or use the enhanced deployment script's RDP function
# (This requires the latest script with Enable-VmRdpAccess function)
```

### Issue: RRAS Installation Fails
**Symptoms:**
- BGP routing not working
- NVA cannot reach Azure Route Server
- RRAS service not running

**Diagnostic Steps:**
```powershell
# Check RRAS installation logs on the VM
# Connect to the NVA VM and check:
Get-Content "C:\Windows\Temp\rras-install.log"

# Check if RRAS features are installed
Get-WindowsFeature -Name "*RemoteAccess*", "*Routing*"

# Check RRAS service status
Get-Service -Name "RemoteAccess", "RasMan"

# Check BGP configuration
netsh routing ip bgp show router
```

**Solution:**
```powershell
# Re-run RRAS installation manually on the VM
Install-WindowsFeature -Name RemoteAccess -IncludeManagementTools
Install-WindowsFeature -Name RSAT-RemoteAccess-PowerShell
Install-WindowsFeature -Name Routing

# Enable IP forwarding
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 1

# Restart the VM
Restart-Computer -Force

# Or use the automated configuration script
.\scripts\Configure-NvaBgp.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-nva-vm"
```

### Issue: Cannot Access VM Serial Console
**Symptoms:**
- Need to troubleshoot VM but RDP not working
- Cannot run commands on the VM

**Solution:**
```powershell
# Enable boot diagnostics if not already enabled
$vm = Get-AzVM -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-nva-vm"
$vm.DiagnosticsProfile.BootDiagnostics.Enabled = $true
$vm | Update-AzVM

# Access serial console via Azure portal
# Navigate to: VM -> Support + troubleshooting -> Serial console

# Or run commands via Run Command
Invoke-AzVMRunCommand -ResourceGroupName "rg-vwanlab-demo" -VMName "vwanlab-nva-vm" -CommandId 'RunPowerShellScript' -ScriptString 'Get-Service -Name "RemoteAccess"'
```

---

## 🧹 **Cleanup System Troubleshooting**

### Issue: Background Cleanup Jobs Stuck
**Symptoms:**
- Cleanup jobs running for extended periods
- Resource groups not being deleted
- Memory usage from stuck PowerShell jobs
# Should be in the vwanlab root directory
```

### Issue: IP Schema Selection Fails
**Symptoms:**
- `Invalid IP schema specified`
- `Custom IP ranges not accepted`

**Solution:**
```powershell
# Check available schemas
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "test" -WhatIf

# Use valid schema names
$validSchemas = @("default", "enterprise", "lab", "custom")

# For custom schema, ensure CIDR ranges don't overlap
# Use IP range calculators to verify non-overlapping ranges
```

### Issue: Background Cleanup Integration Problems
**Symptoms:**
- `Cleanup job failed to start during deployment`
- `Cannot monitor cleanup progress`

**Solution:**
```powershell
# Check if cleanup script exists
Test-Path ".\scripts\Cleanup-ResourceGroups.ps1"

# Verify PowerShell job support
Get-Job | Format-Table

# Manual cleanup if needed
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "problematic-rg" -Force

# Check job status
.\scripts\Cleanup-ResourceGroups.ps1 -ListJobs
```

---

## 🧹 **Cleanup System Troubleshooting**

### Issue: Cleanup Jobs Stuck in Running State
**Symptoms:**
- `Job shows "Running" but no progress for hours`
- `Resource group still exists after extended time`

**Diagnostic Steps:**
```powershell
# Check job details
.\scripts\Cleanup-ResourceGroups.ps1 -CheckJob -JobId <job-id>

# Check Azure portal for actual resource state
az group show --name "problematic-rg"

# Check if resources are locked
az lock list --resource-group "problematic-rg"
```

**Solution:**
```powershell
# Stop stuck job and restart
Stop-Job -Id <job-id>
Remove-Job -Id <job-id>

# Restart cleanup with extended timeout
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "problematic-rg" -Force -WaitForCompletion -Timeout 180

# Manual cleanup if needed
az group delete --name "problematic-rg" --yes --force-deletion-types Microsoft.Compute/virtualMachines,Microsoft.Network/networkInterfaces
```

### Issue: Multiple Resource Groups Fail to Delete
**Symptoms:**
- `Some RGs delete successfully, others fail`
- `Mixed results in bulk cleanup operations`

**Solution:**
```powershell
# Check individual RG status
$rgs = @("rg-1", "rg-2", "rg-3")
foreach ($rg in $rgs) {
    $status = az group show --name $rg 2>$null
    if ($status) {
        Write-Host "❌ $rg still exists" -ForegroundColor Red
        # Check resources in problematic RGs
        az resource list --resource-group $rg --output table
    } else {
        Write-Host "✅ $rg deleted" -ForegroundColor Green
    }
}

# Retry failed deletions individually
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "failed-rg" -Force -WaitForCompletion
```

### Issue: Cleanup Script Not Found or Permissions
**Symptoms:**
- `Cannot access Cleanup-ResourceGroups.ps1`
- `Execution policy prevents script running`

**Solution:**
```powershell
# Check script existence
Test-Path ".\scripts\Cleanup-ResourceGroups.ps1"

# Check execution policy
Get-ExecutionPolicy

# Set execution policy if needed (run as administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run with bypass if needed
PowerShell.exe -ExecutionPolicy Bypass -File ".\scripts\Cleanup-ResourceGroups.ps1" -ResourceGroupName "test-rg" -Force
```

---

## 🌐 **IP Schema and Networking Issues**

### Issue: CIDR Range Conflicts
**Symptoms:**
- `Address space overlaps with existing networks`
- `Subnet creation fails due to address conflicts`

**Enhanced Diagnostic:**
```powershell
# Check for existing networks in subscription
az network vnet list --query "[].{Name:name, ResourceGroup:resourceGroup, AddressSpace:addressSpace.addressPrefixes}" --output table

# Use different IP schema
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-vwanlab" -IpSchema "enterprise"

# Or use custom ranges
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-vwanlab" -IpSchema "custom"
```

### Issue: Gateway Subnet Naming (Fixed)
**Symptoms:**
- `Subnet name 'GatewaySubnet' is reserved`
- `Cannot create subnet with reserved name`

**Status:** ✅ **RESOLVED** - Updated templates use 'NvaSubnet' instead

**Verification:**
```powershell
# Verify fix in templates
Select-String -Path ".\bicep\modules\*.bicep" -Pattern "GatewaySubnet"
# Should return no results

# Check for NvaSubnet instead
Select-String -Path ".\bicep\modules\*.bicep" -Pattern "NvaSubnet"
# Should show updated references
```

---

## Prerequisites and Setup Issues

### Issue: Azure CLI Not Installed
**Symptoms:**
- `az: The term 'az' is not recognized`
- `Cannot find Azure CLI`

**Enhanced Solution:**
```powershell
# Install Azure CLI using winget (recommended)
winget install -e --id Microsoft.AzureCLI --silent

# Verify installation
az --version

# Update to latest version
az upgrade

# Alternative installation methods
# Download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
```

### Issue: Bicep CLI Not Available
**Symptoms:**
- `Bicep CLI not found. Install it now by running "az bicep install"`
- `Cannot retrieve the dynamic parameters for the cmdlet`

**Enhanced Solution:**
```powershell
# Install Bicep CLI
az bicep install

# Verify installation and version
az bicep version

# Update Bicep to latest
az bicep upgrade

# Manual installation if needed
# Download from: https://github.com/Azure/bicep/releases
```

### Issue: PowerShell Modules Missing
**Symptoms:**
- `The specified module 'Az.Accounts' was not loaded`
- `Module not found errors`

**Enhanced Solution:**
```powershell
# Install required Azure PowerShell modules
Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

# Install specific modules if needed
Install-Module -Name Az.Accounts, Az.Resources, Az.Network -Force

# Update existing modules
Update-Module -Name Az

# Verify installations
Get-Module -Name Az.* -ListAvailable | Select-Object Name, Version
```

**Solution:**
```powershell
# Install required Azure PowerShell modules
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Network')
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
}
```

## Bicep and Azure CLI Issues

### Issue: Bicep Build Command Missing --file Flag
**Symptoms:**
- `the following arguments are required: --file/-f`

**Solution:**
Update VS Code tasks.json:
```json
{
    "label": "Build Bicep Templates",
    "type": "shell",
    "command": "az",
    "args": [
        "bicep",
        "build",
        "--file",
        "./bicep/main.bicep"
    ]
}
```

### Issue: Bicep Compilation Warnings
**Symptoms:**
- `Warning no-unnecessary-dependson: Remove unnecessary dependsOn entry`

**Solution:**
Remove unnecessary dependencies in Bicep templates:
```bicep
// Remove unnecessary dependsOn entries
module vnetConnections 'modules/vwan-connections.bicep' = {
  name: 'vnet-connections-deployment'
  params: {
    // ... parameters
  }
  dependsOn: [
    vwan  // Only keep necessary dependencies
    // Remove: spokeVnet1, spokeVnet2 (automatically handled by output references)
  ]
}
```

## Template Compilation and Validation Issues

### Issue: Template Validation Fails with Nested Deployment Warnings
**Symptoms:**
- `A nested deployment got short-circuited and all its resources got skipped from validation`
- `NestedDeploymentShortCircuited warning`

**Solution:**
This is a normal warning for complex templates with nested deployments. Not a blocking error.

### Issue: Invalid Template Deployment Error
**Symptoms:**
- `The template deployment 'xxx' is not valid according to the validation procedure`

**Investigation Steps:**
1. Use Azure CLI for detailed validation:
```bash
az deployment group validate --resource-group "your-rg" --template-file "./bicep/main.json" --parameters "./arm-templates/parameters/lab.parameters.json" --verbose
```

2. Check for specific error details in the validation output.

## Deployment Scope Issues

### Issue: Resources Must Be Deployed at Resource Group Scope
**Symptoms:**
- `The request contains resources that must be deployed at a resource group scope but a different scope was found`

**Root Cause:**
Template was configured for subscription-level deployment but contains resource group-scoped resources.

**Solution:**
1. Change Bicep template scope:
```bicep
// Change from:
targetScope = 'subscription'

// To:
targetScope = 'resourceGroup'
```

2. Remove resource group creation from template:
```bicep
// Remove this section:
// resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
//   name: resourceGroupName
//   location: location
// }
```

3. Update PowerShell deployment commands:
```powershell
# Change from:
New-AzSubscriptionDeployment -Location $Location

# To:
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName
```

4. Update parameter files to remove `resourceGroupName` parameter.

## CIDR and Networking Issues

### Issue: Invalid CIDR Notation
**Symptoms:**
- `The address prefix 10.1.0.1/24 has an invalid CIDR notation. For the given prefix length, the address prefix should be 10.1.0.0/24`
- `InvalidCIDRNotation error`

**Root Cause:**
Subnet calculations were producing invalid network addresses (e.g., 10.1.0.1/24 instead of 10.1.0.0/24).

**Solution:**
Fix subnet calculation logic in Bicep modules:
```bicep
// Wrong approach:
var routeServerSubnetPrefix = '${substring(vnetPrefix, 0, lastIndexOf(vnetPrefix, '.'))}.1/${vnetMask + 8}'

// Correct approach:
var vnetPrefix = split(vnetAddressSpace, '/')[0]
var baseOctets = split(vnetPrefix, '.')
var baseNetwork = '${baseOctets[0]}.${baseOctets[1]}.${baseOctets[2]}'
var gatewaySubnetPrefix = '${baseNetwork}.0/26'     // 10.1.0.0/26   (64 addresses)
var routeServerSubnetPrefix = '${baseNetwork}.64/26' // 10.1.0.64/26  (64 addresses)
var vmSubnetPrefix = '${baseNetwork}.128/26'         // 10.1.0.128/26 (64 addresses)
```

### Issue: Subnet Overlap or Incorrect Sizing
**Solution:**
Use proper CIDR subnetting with /26 networks for adequate address space:
- Gateway Subnet: `10.1.0.0/26` (64 addresses)
- Route Server Subnet: `10.1.0.64/26` (64 addresses) 
- VM Subnet: `10.1.0.128/26` (64 addresses)

## Parameter and Path Issues

### Issue: Parameter Not Declared in Bicep File
**Symptoms:**
- `The parameter "resourceGroupName" is assigned in the params file without being declared in the Bicep file`

**Solution:**
Remove the parameter from the .bicepparam file:
```bicep
// Remove this line:
// param resourceGroupName = 'rg-vwanlab-demo'
```

### Issue: Path Conversion Failures
**Symptoms:**
- `Cannot find path 'C:\...\bicep\parameters\lab.json' because it does not exist`
- Wrong ARM template paths

**Solution:**
Implement robust path conversion function:
```powershell
function Convert-BicepToArmPath {
    param([string]$BicepPath)
    
    if ($BicepPath.EndsWith('.bicep')) {
        # Convert template path: bicep/main.bicep -> arm-templates/main.json
        $armPath = $BicepPath.Replace('.bicep', '.json')
        $armPath = $armPath -replace 'bicep[\\\/]', 'arm-templates\'
        return $armPath
    }
    elseif ($BicepPath.EndsWith('.bicepparam')) {
        # Convert parameter path: bicep/parameters/lab.bicepparam -> arm-templates/parameters/lab.parameters.json
        $armPath = $BicepPath.Replace('.bicepparam', '.parameters.json')
        $armPath = $armPath -replace 'bicep[\\\/]parameters[\\\/]', 'arm-templates\parameters\'
        return $armPath
    }
    
    return $BicepPath
}
```

## PowerShell Script Issues

### Issue: WhatIf Parameter Conflicts
**Symptoms:**
- `A parameter with the name 'WhatIf' was defined multiple times`

**Solution:**
Remove explicit WhatIf parameter declaration and use `$WhatIfPreference`:
```powershell
# Don't declare WhatIf parameter explicitly
# [CmdletBinding(SupportsShouldProcess)] handles this automatically

# Use built-in preference variable
if ($WhatIfPreference) {
    # What-if logic
}
```

### Issue: Bicep Compilation Attempted on ARM Templates
**Solution:**
Add conditional check:
```powershell
# Only compile Bicep if it's available and template is .bicep
if ($TemplateFile.EndsWith('.bicep') -and (Test-BicepAvailability)) {
    # Compile Bicep
} else {
    # Use ARM template fallback
}
```

## Authentication and Permissions

### Issue: Not Logged into Azure
**Symptoms:**
- `Please run 'az login' to setup account`
- `No Azure context found`

**Solution:**
```powershell
# Check if logged in
$context = Get-AzContext
if ($null -eq $context) {
    Connect-AzAccount
}

# For Azure CLI
az login
```

### Issue: Resource Group Not Found
**Solution:**
Create resource group if it doesn't exist:
```powershell
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}
```

## Common Error Messages and Solutions

| Error Message | Issue | Solution |
|---------------|-------|----------|
| `Bicep CLI not found` | Bicep not installed | Run `az bicep install` |
| `InvalidCIDRNotation` | Invalid subnet addressing | Fix subnet calculation logic |
| `parameter was defined multiple times` | WhatIf parameter conflict | Remove explicit WhatIf parameter |
| `resources must be deployed at resource group scope` | Wrong deployment scope | Change targetScope to 'resourceGroup' |
| `Cannot find path` | Incorrect file paths | Fix path conversion logic |
| `NestedDeploymentShortCircuited` | Validation warning | Normal for complex templates, not an error |

## Best Practices

1. **Always validate templates before deployment:**
   ```bash
   az deployment group validate --resource-group "rg-name" --template-file "template.json"
   ```

2. **Use proper CIDR subnetting** with aligned network addresses.

3. **Implement robust error handling** in PowerShell scripts.

4. **Use ARM template fallbacks** when Bicep is not available.

5. **Test with What-If analysis** before actual deployment:
   ```bash
   az deployment group create --what-if --resource-group "rg-name" --template-file "template.json"
   ```

## Troubleshooting Checklist

- [ ] Azure CLI installed and logged in
- [ ] Bicep CLI installed and working
- [ ] PowerShell modules (Az.Accounts, Az.Resources, Az.Network) installed
- [ ] Resource group exists
- [ ] Template scope set to 'resourceGroup'
- [ ] Subnet CIDR notation is valid
- [ ] Parameter files don't contain invalid parameters
- [ ] Path conversion logic is working
- [ ] Template validation passes

## Getting Help

If you encounter issues not covered in this guide:

1. **Check Azure Activity Log** for detailed error messages
2. **Use verbose output** with Azure CLI commands
3. **Review deployment logs** in Azure Portal
4. **Run the automated troubleshooting script** (see next section)

For additional support, refer to:
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Virtual WAN Documentation](https://docs.microsoft.com/en-us/azure/virtual-wan/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)

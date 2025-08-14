# Azure Virtual WAN Lab - Comprehensive Troubleshooting Guide

This comprehensive guide covers all common issues and their solutions encountered during Azure Virtual WAN lab deployment, including **multi-region architecture**, **Just-In-Time (JIT) access**, **automated security features**, and **enterprise automation tools**.

## 🆕 **What's New in This Guide**

### ✅ **Multi-Region Architecture Support**
- **3-Region VWAN Deployment**: West US, Central US, Southeast Asia
- **Azure Firewall Premium Integration**: Security hub troubleshooting
- **VPN Site-to-Site Connectivity**: RRAS and VPN gateway issues
- **Cross-Region Routing**: Hub-to-hub connectivity problems

### ✅ **Enhanced Security Features (SFI)**
- **Just-In-Time (JIT) VM Access**: Troubleshooting JIT policy creation and access requests
- **Auto-Shutdown Configuration**: VM scheduling and cost optimization issues
- **NSG Security Hardening**: Network security group configuration problems
- **Microsoft Defender Integration**: Security center and compliance issues

### ✅ **Automated Diagnostic Tools**
- **Real-Time Monitoring**: .NET automation suite troubleshooting
- **BGP Status Checking**: Route Server and VWAN BGP peering issues
- **Connectivity Testing**: Automated testing and validation problems
- **Resource Cleanup**: Intelligent cleanup and dependency management

## Table of Contents

1. [🌐 Multi-Region Deployment Issues](#-multi-region-deployment-issues) - **NEW**
2. [🔐 JIT Access and Security Issues](#-jit-access-and-security-issues) - **NEW**
3. [🤖 .NET Automation Suite Issues](#-net-automation-suite-issues) - **NEW**
4. [🔄 BGP and Routing Issues](#-bgp-and-routing-issues) - **ENHANCED**
5. [🖥️ VM Configuration Issues](#️-vm-configuration-issues) - **ENHANCED**
6. [🧹 Resource Management Issues](#-resource-management-issues) - **ENHANCED**
7. [Prerequisites and Setup Issues](#prerequisites-and-setup-issues)
8. [Bicep Template Issues](#bicep-template-issues) - **UPDATED**
9. [PowerShell Script Issues](#powershell-script-issues) - **ENHANCED**
10. [Authentication and Permissions](#authentication-and-permissions)
11. [Connectivity and Networking](#connectivity-and-networking) - **ENHANCED**
12. [🛠️ Automated Troubleshooting Tools](#️-automated-troubleshooting-tools) - **NEW**

---

## 🌐 **Multi-Region Deployment Issues**

### Issue: Multi-Region Script Not Found
**Symptoms:**
- `Deploy-VwanLab-MultiRegion.ps1` not found
- Multi-region parameter files missing

**Solution:**
```powershell
# Verify multi-region script exists
Test-Path ".\scripts\Deploy-VwanLab-MultiRegion.ps1"

# Use enhanced deployment script instead
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-vwanlab-mr" -MultiRegion

# OR use phased deployment
.\scripts\Deploy-VwanLab-Phased.ps1 -ResourceGroupName "rg-vwanlab-mr"
```

### Issue: Azure Firewall Premium Deployment Fails
**Symptoms:**
- Firewall policy creation errors
- Premium features not available
- High cost warnings

**Solution:**
```powershell
# Check firewall availability in region
az provider show --namespace Microsoft.Network --query "resourceTypes[?resourceType=='azureFirewalls'].locations" -o table

# Verify SKU availability
az vm list-skus --location "westus" --resource-type "azureFirewalls" --query "[].name" -o table

# Use Standard firewall for testing
.\scripts\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-test" -FirewallSku "Standard"
```

### Issue: Cross-Region Connectivity Problems
**Symptoms:**
- Hub-to-hub connections failing
- Cross-region routing not working
- VPN tunnel establishment issues

**Solution:**
```powershell
# Check hub connectivity status
az network vhub connection list --vhub-name "vhub-vwanlab-wus" --resource-group "rg-vwanlab-mr"

# Validate cross-region routing
.\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-mr" -CrossRegion

# Check BGP peering across hubs
.\scripts\Get-BgpStatus.ps1 -ResourceGroupName "rg-vwanlab-mr" -MultiRegion
```

---

## 🔐 **JIT Access and Security Issues**

### Issue: JIT Access Script Not Working
**Symptoms:**
- `Set-VmJitAccess.ps1` fails to find VMs
- JIT policies not created
- Access requests timing out

**Solution:**
```powershell
# Check if VMs exist and are running
az vm list -g "rg-vwanlab-demo" --query "[].{Name:name, PowerState:powerState}" -o table

# Run JIT script with correct parameters
.\scripts\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-demo" -SfiEnable

# Request access for all VMs
.\scripts\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-demo" -RequestAccess

# Check JIT policy status
az security jit-policy list --resource-group "rg-vwanlab-demo"
```

### Issue: Microsoft Defender for Cloud Not Available
**Symptoms:**
- JIT policy creation fails with defender errors
- Security center not configured
- Fallback NSG rules not working

**Solution:**
```powershell
# Check Defender for Cloud status
az security auto-provisioning-setting list

# Enable Microsoft Defender if needed
az security auto-provisioning-setting update --name "default" --auto-provision "On"

# Use NSG fallback mode
.\scripts\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-demo" -Force

# Test SFI display
.\scripts\test-sfi-display.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### Issue: IP Address Detection Fails
**Symptoms:**
- Deployer IP detection returns 0.0.0.0
- JIT access requests fail with IP errors
- NSG rules not created properly

**Solution:**
```powershell
# Manually detect your public IP
$myIp = (Invoke-RestMethod -Uri "https://ipinfo.io/ip").Trim()
Write-Host "Your public IP: $myIp"

# Configure JIT with manual IP
.\scripts\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-demo" -SourceIp $myIp -RequestAccess

# Verify NSG rules
az network nsg rule list --nsg-name "nsg-spoke1" --resource-group "rg-vwanlab-demo"
```

---

## 🤖 **.NET Automation Suite Issues**

### Issue: .NET Application Won't Build
**Symptoms:**
- Build errors in VwanLabAutomation project
- Missing dependencies
- Runtime errors

**Solution:**
```bash
# Verify .NET 8 SDK is installed
dotnet --version

# Restore packages
cd src/VwanLabAutomation
dotnet restore

# Clean and rebuild
dotnet clean
dotnet build

# Run with verbose output
dotnet run -- status --resource-group "rg-vwanlab-demo" --verbose
```

### Issue: Automation Tools Can't Find Resources
**Symptoms:**
- "No resources found" errors
- Authentication failures
- Subscription access issues

**Solution:**
```bash
# Check Azure authentication
az account show

# Set correct subscription
az account set --subscription "your-subscription-id"

# Run automation with debug output
dotnet run --project ./src/VwanLabAutomation/ -- status --resource-group "rg-vwanlab-demo" --debug

# Check application settings
cat ./src/VwanLabAutomation/appsettings.json
```

---

## 🔄 **BGP and Routing Issues**

### Issue: BGP Peering Not Established
**Symptoms:**
- BGP neighbors in idle state
- Routes not being advertised
- RRAS service not running

**Solution:**
```powershell
# Check RRAS service status
.\scripts\Validate-RrasConfiguration.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Fix RRAS service if needed
.\scripts\Fix-RrasService.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Check BGP status
.\scripts\Get-BgpStatus.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Reconfigure BGP peering
.\scripts\Configure-NvaBgp.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Simple BGP configuration for testing
.\scripts\configure-bgp-simple.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### Issue: Route Server Integration Problems
**Symptoms:**
- Route Server not learning routes
- Peering connections failing
- Routes not propagating to VWAN

**Solution:**
```powershell
# Check Route Server status
az network routeserver list --resource-group "rg-vwanlab-demo"

# Validate BGP architecture
.\scripts\Check-VwanBgpArchitecture.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Check learned routes
az network routeserver peering list-learned-routes --name "bgp-nva" --routeserver "rs-spoke3" --resource-group "rg-vwanlab-demo"

# Reset Route Server peering
az network routeserver peering delete --name "bgp-nva" --routeserver "rs-spoke3" --resource-group "rg-vwanlab-demo"
.\scripts\Configure-NvaBgp.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

---

## 🖥️ **VM Configuration Issues**

### Issue: VMs Not Found by Scripts
**Symptoms:**
- "No VMs found" errors
- Scripts can't detect lab VMs
- VM pattern matching fails

**Solution:**
The scripts now use flexible VM pattern matching. If you still get "No VMs found" errors:

```powershell
# Check what VMs exist
az vm list --resource-group "rg-vwanlab-demo" --query "[].{Name:name, Location:location, PowerState:powerState}" --output table

# The scripts now automatically detect VMs with these patterns:
# - *vwanlab* (original pattern)
# - vm-s* (new multi-region pattern)
# - *nva* (NVA VMs)
# - *rras* (RRAS VMs)
# - *spoke* (spoke VMs)

# If your VMs use different naming, update the script pattern
```

### Issue: Auto-Shutdown Not Working
**Symptoms:**
- VMs not shutting down automatically
- Auto-shutdown configuration fails
- Schedule not working

**Solution:**
```powershell
# Configure auto-shutdown
.\scripts\Set-VmAutoShutdown.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Set custom shutdown time
.\scripts\Set-VmAutoShutdown.ps1 -ResourceGroupName "rg-vwanlab-demo" -AutoShutdownTime "18:00"

# Test auto-shutdown configuration
.\scripts\test-autoshutdown.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Check auto-shutdown status via Azure CLI
az vm auto-shutdown show --resource-group "rg-vwanlab-demo" --vm-name "vm-s1-win-wus"
```

### Issue: Boot Diagnostics Problems
**Symptoms:**
- Can't access VM console
- Boot diagnostics not enabled
- Troubleshooting data missing

**Solution:**
```powershell
# Enable boot diagnostics for all VMs
.\scripts\Enable-BootDiagnostics.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Check boot diagnostics status
az vm boot-diagnostics get-boot-log --name "vm-s1-win-wus" --resource-group "rg-vwanlab-demo"

# View screenshot
az vm boot-diagnostics get-boot-log-uris --name "vm-s1-win-wus" --resource-group "rg-vwanlab-demo"
```

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
---

## 🧹 **Resource Management Issues**

### Issue: Resource Cleanup Problems
**Symptoms:**
- Resources not cleaning up properly
- Dependent resources preventing deletion
- Cleanup scripts failing

**Solution:**
```powershell
# Use intelligent cleanup with dependency management
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Use .NET automation for advanced cleanup
dotnet run --project .\src\VwanLabAutomation\ -- cleanup --resource-group "rg-vwanlab-demo"

# Manual cleanup with force delete
az group delete --name "rg-vwanlab-demo" --yes --no-wait

# Check cleanup status
.\scripts\Get-LabStatus.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### Issue: Legacy Script Problems
**Symptoms:**
- Old script names not found
- Deprecated parameter errors
- Legacy cleanup issues

**Solution:**
```powershell
# Use updated scripts instead of legacy ones
# OLD: Manage-Cleanup.ps1
# NEW: Cleanup-ResourceGroups.ps1

# OLD: Manage-Cleanup-Legacy.ps1  
# NEW: .\scripts\Cleanup-ResourceGroups.ps1

# Check available scripts
Get-ChildItem .\scripts\ -Name "*.ps1" | Sort-Object
```

---

## 🛠️ **Automated Troubleshooting Tools**

### Comprehensive Troubleshooting Script
```powershell
# Run comprehensive troubleshooting
.\scripts\Troubleshoot-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Get detailed lab status
.\scripts\Get-LabStatus.ps1 -ResourceGroupName "rg-vwanlab-demo" -Detailed

# Check BGP architecture and status
.\scripts\Check-VwanBgpArchitecture.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### .NET Automation Suite Diagnostics
```bash
# Real-time monitoring dashboard
dotnet run --project .\src\VwanLabAutomation\ -- monitor --resource-group "rg-vwanlab-demo"

# Comprehensive status report
dotnet run --project .\src\VwanLabAutomation\ -- status --resource-group "rg-vwanlab-demo"

# Automated testing suite
dotnet run --project .\src\VwanLabAutomation\ -- test --resource-group "rg-vwanlab-demo"
```

### Network Connectivity Testing
```powershell
# Test connectivity between spokes
.\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-demo" -Detailed

# Test cross-region connectivity (multi-region labs)
.\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-mr" -CrossRegion

# Test VPN connectivity
.\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-demo" -VpnTest
```

### Security and Access Validation
```powershell
# Display SFI security status
.\scripts\test-sfi-display.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Validate RRAS configuration
.\scripts\Validate-RrasConfiguration.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Check auto-shutdown configuration
.\scripts\test-autoshutdown.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

## Common Error Messages and Solutions

| Error Message | Issue | Solution |
|---------------|-------|----------|
| `No VMs found in resource group` | VM pattern matching fails | Use updated scripts with flexible VM detection |
| `JIT policy creation failed` | Microsoft Defender not available | Use `-Force` parameter for NSG fallback |
| `BGP peering not established` | RRAS service issues | Run `Fix-RrasService.ps1` |
| `Bicep CLI not found` | Bicep not installed | Run `az bicep install` |
| `Cannot request JIT access` | IP detection fails | Manually specify `-SourceIp` parameter |
| `Auto-shutdown not configured` | VM scheduling issues | Run `Set-VmAutoShutdown.ps1` |
| `Cross-region connectivity fails` | Hub routing problems | Check VWAN route tables |
| `.NET automation fails` | Authentication issues | Check `az account show` |

## Quick Diagnostic Commands

### Immediate Health Check
```powershell
# Quick status check
az vm list -d -g "rg-vwanlab-demo" --query "[].{Name:name, PowerState:powerState, Location:location}" -o table

# Check resource group contents
az resource list -g "rg-vwanlab-demo" --query "[].{Name:name, Type:type, Location:location}" -o table

# Verify VWAN hub status
az network vhub list -g "rg-vwanlab-demo" --query "[].{Name:name, ProvisioningState:provisioningState}" -o table
```

### Network Validation
```powershell
# Check NSG rules
az network nsg list -g "rg-vwanlab-demo" --query "[].{Name:name, Rules:length(securityRules)}" -o table

# Validate BGP peering
az network routeserver peering list --routeserver "rs-spoke3" -g "rg-vwanlab-demo" --query "[].{Name:name, PeerAsn:peerAsn, PeeringState:peeringState}" -o table

# Check JIT policies
az security jit-policy list -g "rg-vwanlab-demo" --query "[].{Name:name, VMs:length(virtualMachines)}" -o table
```

## Best Practices for Troubleshooting

### 💡 **Systematic Approach**
1. **Start with health check**: Run `Get-LabStatus.ps1` first
2. **Use verbose output**: Add `-Verbose` to PowerShell commands
3. **Check Azure activity logs**: Review recent operations in Azure Portal
4. **Test incrementally**: Isolate issues by testing individual components

### 🔧 **Prevention Strategies**
1. **Use phased deployment**: Avoid timeouts with `Deploy-VwanLab-Phased.ps1`
2. **Enable boot diagnostics**: Always run `Enable-BootDiagnostics.ps1`
3. **Configure auto-shutdown**: Save costs with `Set-VmAutoShutdown.ps1`
4. **Regular monitoring**: Use .NET automation suite for continuous monitoring

### 📊 **Documentation and Logging**
1. **Save deployment logs**: Keep PowerShell transcripts of deployments
2. **Document customizations**: Record any parameter changes
3. **Monitor costs**: Regular review of Azure Cost Management
4. **Update regularly**: Keep scripts and templates current

## Getting Advanced Help

### For Complex Issues
1. **Check detailed logs**: Review Azure Activity Log and deployment history
2. **Use diagnostic tools**: Run comprehensive troubleshooting scripts
3. **Contact support**: Create Azure support tickets for platform issues
4. **Community support**: Use GitHub Issues for project-specific problems

### Additional Resources
- [Azure Virtual WAN Documentation](https://docs.microsoft.com/en-us/azure/virtual-wan/)
- [Azure Route Server Documentation](https://docs.microsoft.com/en-us/azure/route-server/)
- [Azure Firewall Documentation](https://docs.microsoft.com/en-us/azure/firewall/)
- [Microsoft Defender for Cloud Documentation](https://docs.microsoft.com/en-us/azure/defender-for-cloud/)

---

*For additional support, check our [User Guide](user-guide.md) or create an issue on [GitHub](https://github.com/Azure-VWAN-Lab/Azure-VWAN-Lab/issues).*

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Network

<#
.SYNOPSIS
    [DEPRECATED] Multi-Region Azure Virtual WAN Lab Deployment Script

.DESCRIPTION
    🚨 DEPRECATED: This script has been consolidated into Deploy-VwanLab.ps1
    
    Please use: .\Deploy-VwanLab.ps1 -Architecture MultiRegion
    
    This script originally deployed a comprehensive multi-region Azure VWAN lab environment with:
    - 3 VWAN Hubs (West US, Central US, Southeast Asia)
    - 5 Spoke VNets with specialized configurations
    - Azure Firewall Premium in Spoke 1
    - VPN connectivity for Spoke 3 via RRAS
    - Linux and Windows VMs across regions
    - Advanced routing and security configurations

.NOTES
    This file is kept for reference but should not be used for new deployments.
    Use the consolidated Deploy-VwanLab.ps1 script instead.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current context if not specified)

.PARAMETER AdminUsername
    VM administrator username

.PARAMETER AdminPassword
    VM administrator password
    Must meet Azure VM complexity requirements:
    - 8-123 characters
    - Must contain 3 of: lowercase, uppercase, digit, special character

.PARAMETER DeploymentMode
    Deployment type: 'Full', 'InfrastructureOnly'
    - Full: Complete multi-region lab with all VMs and services
    - InfrastructureOnly: Network infrastructure without VMs

.PARAMETER Phase
    Specific phase to deploy (1-6). If not specified, deploys all phases
    - Phase 1: Core infrastructure (3 VWAN hubs, 5 VNets)
    - Phase 2: Virtual machines (Linux + Windows across regions)
    - Phase 3: Azure Firewall Premium
    - Phase 4: VPN Gateway for Spoke 3
    - Phase 5: VWAN hub connections
    - Phase 6: Routing configuration

.PARAMETER WhatIf
    Show what would be deployed without making changes

.PARAMETER SkipPrerequisites
    Skip Azure CLI and module checks

.PARAMETER EnableAutoShutdown
    Enable VM auto-shutdown for cost optimization

.PARAMETER SfiEnable
    Enable Just-In-Time (JIT) VM access (Secure Future Initiative)

.EXAMPLE
    .\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-multiregion"

.EXAMPLE
    .\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-mr" -Phase 1

.EXAMPLE
    .\Deploy-VwanLab-MultiRegion.ps1 -ResourceGroupName "rg-vwanlab-mr" -DeploymentMode InfrastructureOnly

.NOTES
    Requires: PowerShell 7.0+, Az.Accounts, Az.Resources, Az.Network modules
    Author: Azure VWAN Lab Team
    Version: 2.0 Multi-Region Architecture
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $false)]
    [SecureString]$AdminPassword,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Full', 'InfrastructureOnly')]
    [string]$DeploymentMode = 'Full',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 6)]
    [int]$Phase,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisites,

    [Parameter(Mandatory = $false)]
    [switch]$EnableAutoShutdown,

    [Parameter(Mandatory = $false)]
    [switch]$SfiEnable
)

# Script configuration
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'
$ProgressPreference = 'Continue'

# Multi-region configuration
$script:MultiRegionConfig = @{
    EnvironmentPrefix = 'vwanlab'
    WestUsRegion = 'West US'
    CentralUsRegion = 'Central US'
    SoutheastAsiaRegion = 'Southeast Asia'
    
    # VWAN Hub Configuration
    WestUsHubName = 'vhub-vwanlab-wus'
    WestUsHubAddressPrefix = '10.200.0.0/24'
    CentralUsHubName = 'vhub-vwanlab-cus'  
    CentralUsHubAddressPrefix = '10.201.0.0/24'
    SoutheastAsiaHubName = 'vhub-vwanlab-sea'
    SoutheastAsiaHubAddressPrefix = '10.202.0.0/24'    # Spoke Configuration
    Spoke1VnetName = 'vnet-spoke1-vwanlab-wus'
    Spoke1VnetAddressSpace = '10.0.1.0/24'
    Spoke2VnetName = 'vnet-spoke2-vwanlab-sea'
    Spoke2VnetAddressSpace = '10.32.1.0/26'
    Spoke3VnetName = 'vnet-spoke3-vwanlab-cus'
    Spoke3VnetAddressSpace = '10.16.1.0/26'
    Spoke4VnetName = 'vnet-spoke4-vwanlab-wus'
    Spoke4VnetAddressSpace = '10.0.2.0/26'
    Spoke5VnetName = 'vnet-spoke5-vwanlab-wus'
    Spoke5VnetAddressSpace = '10.0.3.0/26'
    
    # Azure Firewall Configuration
    FirewallName = 'afw-vwanlab-wus'
    FirewallPolicyName = 'afwp-vwanlab-wus'
    
    # VPN Configuration
    VpnGatewayName = 'vpngw-vwanlab-cus'
    
    # VM Configuration
    LinuxVmSize = 'Standard_B1s'
    WindowsVmSize = 'Standard_B2s'
}

function Write-PhaseHeader {
    param(
        [int]$PhaseNumber,
        [string]$Description
    )
    
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host "PHASE $PhaseNumber - $Description" -ForegroundColor Cyan
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check Azure CLI
    try {
        $azVersion = az version 2>$null | ConvertFrom-Json
        Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
    }
    catch {
        throw "Azure CLI is not installed or not in PATH. Please install from https://docs.microsoft.com/cli/azure/install-azure-cli"
    }
    
    # Check required modules
    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Network')
    foreach ($module in $requiredModules) {
        $installedModule = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
        if ($installedModule) {
            Write-Host "✅ $module version: $($installedModule.Version)" -ForegroundColor Green
        } else {
            throw "$module is not installed. Run: Install-Module -Name $module -Force"
        }
    }
}

function Connect-AzureAccount {
    param(
        [string]$SubscriptionId
    )
    
    Write-Host "🔐 Checking Azure authentication..." -ForegroundColor Yellow
    
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "No Azure context found. Please sign in..." -ForegroundColor Yellow
            Connect-AzAccount
            $context = Get-AzContext
        }
        
        Write-Host "✅ Connected to Azure as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "✅ Current subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green
        
        if ($SubscriptionId -and $context.Subscription.Id -ne $SubscriptionId) {
            Write-Host "🔄 Switching to subscription: $SubscriptionId" -ForegroundColor Yellow
            Set-AzContext -SubscriptionId $SubscriptionId
        }
    }
    catch {
        throw "Failed to authenticate with Azure: $($_.Exception.Message)"
    }
}

function Get-DeployerPublicIp {
    Write-Host "🌐 Detecting your public IP address..." -ForegroundColor Yellow
    
    try {
        $ipServices = @(
            'https://ipinfo.io/ip',
            'https://api.ipify.org',
            'https://checkip.amazonaws.com'
        )
        
        foreach ($service in $ipServices) {
            try {
                $ip = (Invoke-RestMethod -Uri $service -TimeoutSec 10).Trim()
                if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    Write-Host "✅ Your public IP: $ip" -ForegroundColor Green
                    return $ip
                }
            }
            catch {
                continue
            }
        }
        
        throw "Could not detect public IP from any service"
    }
    catch {
        Write-Warning "Could not detect your public IP address: $($_.Exception.Message)"
        Write-Warning "RDP access rules will not be created automatically"
        return $null
    }
}

function Get-VmCredentials {
    if ($DeploymentMode -eq 'InfrastructureOnly') {
        return @{ Username = $null; Password = $null }
    }
    
    $username = $AdminUsername
    $password = $AdminPassword
    
    if (-not $username) {
        do {
            $username = Read-Host "Enter VM administrator username"
            if (-not $username -or $username.Length -lt 1) {
                Write-Warning "Username cannot be empty"
                $username = $null
            }
        } while (-not $username)
    }
    
    if (-not $password) {
        do {
            $password = Read-Host "Enter VM administrator password" -AsSecureString
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
            
            if ($plainPassword.Length -lt 8 -or $plainPassword.Length -gt 123) {
                Write-Warning "Password must be 8-123 characters long"
                $password = $null
                continue
            }
            
            $complexity = 0
            if ($plainPassword -cmatch '[a-z]') { $complexity++ }
            if ($plainPassword -cmatch '[A-Z]') { $complexity++ }
            if ($plainPassword -cmatch '[0-9]') { $complexity++ }
            if ($plainPassword -cmatch '[^a-zA-Z0-9]') { $complexity++ }
            
            if ($complexity -lt 3) {
                Write-Warning "Password must contain at least 3 of: lowercase, uppercase, digit, special character"
                $password = $null
                continue
            }
            
            if ($plainPassword.ToLower().Contains($username.ToLower())) {
                Write-Warning "Password cannot contain username"
                $password = $null
                continue
            }
            
        } while (-not $password)
    }
    
    return @{
        Username = $username
        Password = $password
    }
}

function Deploy-Phase1 {
    param([string]$DeployerPublicIp)
    
    Write-PhaseHeader -PhaseNumber 1 -Description "Core Infrastructure (3 VWAN Hubs, 5 VNets)"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase1-multiregion-core.bicep"
    $parameters = @{
        environmentPrefix = $script:MultiRegionConfig.EnvironmentPrefix
        westUsRegion = $script:MultiRegionConfig.WestUsRegion
        centralUsRegion = $script:MultiRegionConfig.CentralUsRegion
        southeastAsiaRegion = $script:MultiRegionConfig.SoutheastAsiaRegion
        deployerPublicIP = $DeployerPublicIp
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase 1 with parameters:" -ForegroundColor Yellow
        $parameters | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile `
            -TemplateParameterObject $parameters `
            -Name "Phase1-Core-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose
            
        Write-Host "✅ Phase 1 deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase 1 deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Deploy-Phase2 {
    param([object]$Credentials)
    
    if ($DeploymentMode -eq 'InfrastructureOnly') {
        Write-Host "⏭️ Skipping Phase 2 (Infrastructure Only mode)" -ForegroundColor Yellow
        return @{ Success = $true; Skipped = $true }
    }
    
    Write-PhaseHeader -PhaseNumber 2 -Description "Virtual Machines (Linux + Windows across regions)"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase2-multiregion-vms.bicep"
    $parameters = @{
        environmentPrefix = $script:MultiRegionConfig.EnvironmentPrefix
        adminUsername = $Credentials.Username
        adminPassword = $Credentials.Password
        linuxVmSize = $script:MultiRegionConfig.LinuxVmSize
        windowsVmSize = $script:MultiRegionConfig.WindowsVmSize
        westUsRegion = $script:MultiRegionConfig.WestUsRegion
        centralUsRegion = $script:MultiRegionConfig.CentralUsRegion
        southeastAsiaRegion = $script:MultiRegionConfig.SoutheastAsiaRegion
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase 2 with parameters:" -ForegroundColor Yellow
        $parametersForDisplay = $parameters.Clone()
        $parametersForDisplay.adminPassword = "***REDACTED***"
        $parametersForDisplay | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile `
            -TemplateParameterObject $parameters `
            -Name "Phase2-VMs-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose
            
        Write-Host "✅ Phase 2 deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase 2 deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Deploy-Phase3 {
    Write-PhaseHeader -PhaseNumber 3 -Description "Azure Firewall Premium"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase3-multiregion-firewall.bicep"
    $parameters = @{
        environmentPrefix = $script:MultiRegionConfig.EnvironmentPrefix
        westUsRegion = $script:MultiRegionConfig.WestUsRegion
        firewallName = $script:MultiRegionConfig.FirewallName
        firewallPolicyName = $script:MultiRegionConfig.FirewallPolicyName
        firewallSku = 'Premium'
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase 3 with parameters:" -ForegroundColor Yellow
        $parameters | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile `
            -TemplateParameterObject $parameters `
            -Name "Phase3-Firewall-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose
            
        Write-Host "✅ Phase 3 deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase 3 deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Deploy-Phase4 {
    Write-PhaseHeader -PhaseNumber 4 -Description "VPN Gateway for Spoke 3"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase4-multiregion-vpn.bicep"
    $parameters = @{
        environmentPrefix = $script:MultiRegionConfig.EnvironmentPrefix
        centralUsRegion = $script:MultiRegionConfig.CentralUsRegion
        vpnGatewayName = $script:MultiRegionConfig.VpnGatewayName
        spoke3VnetName = $script:MultiRegionConfig.Spoke3VnetName
        spoke3AddressSpace = $script:MultiRegionConfig.Spoke3VnetAddressSpace
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase 4 with parameters:" -ForegroundColor Yellow
        $parameters | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile `
            -TemplateParameterObject $parameters `
            -Name "Phase4-VPN-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose
            
        Write-Host "✅ Phase 4 deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase 4 deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Deploy-Phase5 {
    Write-PhaseHeader -PhaseNumber 5 -Description "VWAN Hub Connections"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase5-multiregion-connections.bicep"
    $parameters = @{
        environmentPrefix = $script:MultiRegionConfig.EnvironmentPrefix
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase 5 with parameters:" -ForegroundColor Yellow
        $parameters | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile `
            -TemplateParameterObject $parameters `
            -Name "Phase5-Connections-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose
            
        Write-Host "✅ Phase 5 deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase 5 deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Deploy-Phase6 {
    param([string]$FirewallPrivateIp)
    
    Write-PhaseHeader -PhaseNumber 6 -Description "Routing Configuration"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase6-multiregion-routing.bicep"
    $parameters = @{
        environmentPrefix = $script:MultiRegionConfig.EnvironmentPrefix
        azureFirewallPrivateIp = $FirewallPrivateIp
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase 6 with parameters:" -ForegroundColor Yellow
        $parameters | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile `
            -TemplateParameterObject $parameters `
            -Name "Phase6-Routing-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose
            
        Write-Host "✅ Phase 6 deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase 6 deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Show-DeploymentSummary {
    param([hashtable]$Results)
    
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Green
    Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Green
    Write-Host "================================================================================================" -ForegroundColor Green
    
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
    Write-Host "Deployment Mode: $DeploymentMode" -ForegroundColor Cyan
    Write-Host "Deployment Time: $(Get-Date)" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "📊 Phase Results:" -ForegroundColor Yellow
    
    foreach ($phase in $Results.Keys | Sort-Object) {
        $result = $Results[$phase]
        if ($result.Skipped) {
            Write-Host "  Phase $phase - SKIPPED" -ForegroundColor Yellow
        } elseif ($result.Success) {
            Write-Host "  Phase $phase - SUCCESS ✅" -ForegroundColor Green
        } else {
            Write-Host "  Phase $phase - FAILED ❌" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "🌐 Multi-Region Architecture Deployed:" -ForegroundColor Cyan
    Write-Host "  • 3 VWAN Hubs: West US, Central US, Southeast Asia" -ForegroundColor White
    Write-Host "  • 5 Spoke VNets with specialized configurations" -ForegroundColor White
    Write-Host "  • Azure Firewall Premium in Spoke 1 (West US)" -ForegroundColor White
    Write-Host "  • VPN connectivity for Spoke 3 (Central US)" -ForegroundColor White
    Write-Host "  • Cross-region VM connectivity" -ForegroundColor White
    
    if ($DeploymentMode -eq 'Full') {
        Write-Host ""
        Write-Host "🖥️ VMs Deployed:" -ForegroundColor Cyan
        Write-Host "  • Spoke 1: Linux VM + Windows VM (West US)" -ForegroundColor White
        Write-Host "  • Spoke 2: Linux VM (Southeast Asia)" -ForegroundColor White
        Write-Host "  • Spoke 3: RRAS VM for VPN (Central US)" -ForegroundColor White
        Write-Host "  • Spoke 4: Linux VM (West US)" -ForegroundColor White
        Write-Host "  • Spoke 5: Linux VM (West US)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🚀 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Configure VPN connection for Spoke 3 RRAS VM" -ForegroundColor White
    Write-Host "  2. Test connectivity between regions" -ForegroundColor White
    Write-Host "  3. Configure Azure Firewall rules as needed" -ForegroundColor White
    Write-Host "  4. Set up monitoring and logging" -ForegroundColor White
}

# Main execution
try {
    Write-Host ""
    Write-Host "� DEPRECATION WARNING 🚨" -ForegroundColor Red
    Write-Host "This script has been consolidated into Deploy-VwanLab.ps1" -ForegroundColor Yellow
    Write-Host "Please use: .\Deploy-VwanLab.ps1 -Architecture MultiRegion" -ForegroundColor Yellow
    Write-Host ""
    
    $response = Read-Host "Do you want to continue with this deprecated script? (y/N)"
    if ($response -notmatch '^[Yy]$') {
        Write-Host "Deployment cancelled. Use Deploy-VwanLab.ps1 instead." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host ""
    Write-Host "�🚀 Azure VWAN Multi-Region Lab Deployment [DEPRECATED]" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    
    if (-not $SkipPrerequisites) {
        Test-Prerequisites
    }
    
    Connect-AzureAccount -SubscriptionId $SubscriptionId
    $deployerPublicIp = Get-DeployerPublicIp
    $credentials = Get-VmCredentials
    
    # Ensure resource group exists
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "📦 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        New-AzResourceGroup -Name $ResourceGroupName -Location $script:MultiRegionConfig.WestUsRegion
    }
    
    $results = @{}
    $firewallPrivateIp = $null
    
    # Deploy phases
    if (-not $Phase -or $Phase -eq 1) {
        $results[1] = Deploy-Phase1 -DeployerPublicIp $deployerPublicIp
    }
    
    if (-not $Phase -or $Phase -eq 2) {
        $results[2] = Deploy-Phase2 -Credentials $credentials
    }
    
    if (-not $Phase -or $Phase -eq 3) {
        $results[3] = Deploy-Phase3
        if ($results[3].Success -and $results[3].Outputs) {
            $firewallPrivateIp = $results[3].Outputs.firewallPrivateIp.Value
        }
    }
    
    if (-not $Phase -or $Phase -eq 4) {
        $results[4] = Deploy-Phase4
    }
    
    if (-not $Phase -or $Phase -eq 5) {
        $results[5] = Deploy-Phase5
    }
    
    if (-not $Phase -or $Phase -eq 6) {
        if (-not $firewallPrivateIp) {
            # Try to get firewall private IP from existing deployment
            $firewall = Get-AzFirewall -ResourceGroupName $ResourceGroupName -Name $script:MultiRegionConfig.FirewallName -ErrorAction SilentlyContinue
            if ($firewall) {
                $firewallPrivateIp = $firewall.IpConfigurations[0].PrivateIPAddress
            }
        }
        
        if ($firewallPrivateIp) {
            $results[6] = Deploy-Phase6 -FirewallPrivateIp $firewallPrivateIp
        } else {
            Write-Warning "Could not determine Azure Firewall private IP. Skipping routing configuration."
            $results[6] = @{ Success = $false; Error = "Firewall private IP not available" }
        }
    }
    
    Show-DeploymentSummary -Results $results
    
    # Check for any failures
    $failures = $results.Values | Where-Object { $_.Success -eq $false }
    if ($failures) {
        Write-Host ""
        Write-Host "⚠️ Some phases failed. Check the error messages above." -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "🎉 Multi-Region Azure VWAN Lab deployment completed successfully!" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Host ""
    Write-Error "💥 Deployment failed: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

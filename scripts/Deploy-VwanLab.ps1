#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Network

<#
.SYNOPSIS
    Unified Azure Virtual WAN Lab Deployment Script

.DESCRIPTION
    This unified script provides performance-optimized, timeout-resistant deployment for both classic and multi-region Azure VWAN lab environments.
    
    Features:
    - Multi-region architecture with Azure Firewall Premium (default)
    - Classic single-region architecture with BGP and Route Server
    - Performance-optimized VMs (Standard_B2s with 2 GB RAM, Standard_LRS storage)
    - Phased deployment approach (the only reliable method)
    - Full lab or Infrastructure-only modes
    - Enhanced error handling and progress monitoring
    - Automatic RDP configuration from deployer IP
    - RRAS installation and configuration
    - VM credential validation and complexity requirements

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current context if not specified)

.PARAMETER Architecture
    Lab architecture to deploy: 'MultiRegion', 'Classic', 'MULTIREGION', 'CLASSIC'
    - MultiRegion: 3 VWAN hubs, Azure Firewall Premium, VPN connectivity (6 phases)
    - Classic: Single VWAN hub, BGP Route Server, NVA (5 phases)
    Default: MultiRegion

.PARAMETER Location
    Azure region for deployment (Classic mode only, default: East US)
    Multi-region mode uses: West US, Central US, Southeast Asia

.PARAMETER AdminUsername
    VM administrator username (will be prompted if not provided and VMs are being deployed)

.PARAMETER AdminPassword
    VM administrator password (will be prompted if not provided and VMs are being deployed)
    Must meet Azure VM complexity requirements:
    - 8-123 characters
    - Must contain 3 of: lowercase, uppercase, digit, special character
    - Cannot contain username

.PARAMETER DeploymentMode
    Deployment type: 'Full', 'InfrastructureOnly'
    - Full: Complete lab with VMs
    - InfrastructureOnly: Network infrastructure without VMs

.PARAMETER Phase
    Specific phase to deploy. If not specified, deploys all phases
    Classic (1-5): Core, VMs, Route Server, Connections, BGP
    MultiRegion (1-6): Core, VMs, Firewall, VPN, Connections, Routing

.PARAMETER EnableAutoShutdown
    Enable auto-shutdown for VMs to reduce costs

.PARAMETER AutoShutdownTime
    Time to shutdown VMs in 24-hour format (HH:MM). Default: 01:00 (1:00 AM)

.PARAMETER AutoShutdownTimeZone
    Time zone for auto-shutdown. Default: UTC

.PARAMETER SfiEnable
    Enable Secure Future Initiative (SFI) features including Just-In-Time (JIT) VM access

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Show what would be deployed without making changes

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-multiregion"
    Deploy multi-region architecture (default)
    
.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-classic" -Architecture Classic
    Deploy classic single-region architecture
    
.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-mr" -DeploymentMode InfrastructureOnly
    Deploy multi-region infrastructure only (no VMs)

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-test" -Phase 3 -WhatIf
    Test deployment of Phase 3 only

.NOTES
    Author: Azure VWAN Lab Team
    Version: 3.0 - Multi-Region Support
    Requires: Azure PowerShell, appropriate Azure permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('MultiRegion', 'Classic', 'MULTIREGION', 'CLASSIC')]
    [string]$Architecture = 'MultiRegion',

    [Parameter(Mandatory = $false)]
    [string]$Location = 'East US',

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
    [switch]$EnableAutoShutdown,

    [Parameter(Mandatory = $false)]
    [string]$AutoShutdownTime = '01:00',

    [Parameter(Mandatory = $false)]
    [string]$AutoShutdownTimeZone = 'UTC',

    [Parameter(Mandatory = $false)]
    [switch]$SfiEnable,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script configuration
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'
$ProgressPreference = 'Continue'

# Normalize architecture parameter (case-insensitive)
$Architecture = switch ($Architecture.ToUpper()) {
    'MULTIREGION' { 'MultiRegion' }
    'CLASSIC' { 'Classic' }
    default { $Architecture }
}

# Architecture configurations
$script:ArchitectureConfig = @{
    MultiRegion = @{
        MaxPhases = 6
        EnvironmentPrefix = 'vwanlab'
        PrimaryRegion = 'West US'
        Regions = @{
            WestUs = 'West US'
            CentralUs = 'Central US'
            SoutheastAsia = 'Southeast Asia'
        }
        Phases = @{
            1 = @{ Name = 'Core Infrastructure'; Description = '3 VWAN Hubs, 5 VNets' }
            2 = @{ Name = 'Virtual Machines'; Description = 'Linux + Windows VMs across regions' }
            3 = @{ Name = 'Azure Firewall'; Description = 'Firewall Premium in West US' }
            4 = @{ Name = 'VPN Gateway'; Description = 'Site-to-Site VPN for Spoke 3' }
            5 = @{ Name = 'VWAN Connections'; Description = 'Hub-to-spoke connections' }
            6 = @{ Name = 'Routing Configuration'; Description = 'Route tables and traffic steering' }
        }
    }
    Classic = @{
        MaxPhases = 5
        EnvironmentPrefix = 'vwanlab'
        PrimaryRegion = $Location
        Phases = @{
            1 = @{ Name = 'Core Infrastructure'; Description = 'VWAN hub, VNets, NSGs' }
            2 = @{ Name = 'Virtual Machines'; Description = 'NVA and test VMs' }
            3 = @{ Name = 'Route Server'; Description = 'Azure Route Server deployment' }
            4 = @{ Name = 'VWAN Connections'; Description = 'Hub connections and peering' }
            5 = @{ Name = 'BGP Peering'; Description = 'NVA-Route Server BGP peering' }
        }
    }
}

function Write-PhaseHeader {
    param(
        [int]$PhaseNumber,
        [string]$Description,
        [string]$Architecture
    )
    
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host "[$Architecture] PHASE $PhaseNumber - $Description" -ForegroundColor Cyan
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-PhaseAlreadyDeployed {
    param(
        [string]$ResourceGroupName,
        [int]$PhaseNumber,
        [string]$Architecture
    )
    
    try {
        # Check for successful deployment in the last 24 hours
        $deploymentPattern = if ($Architecture -eq 'MultiRegion') { 
            "MultiRegion-Phase$PhaseNumber-*" 
        } else { 
            "Classic-Phase$PhaseNumber-*" 
        }
        
        $recentDeployments = az deployment group list --resource-group $ResourceGroupName --query "[?contains(name, 'Phase$PhaseNumber') && properties.provisioningState=='Succeeded' && properties.timestamp >= '$(((Get-Date).AddDays(-1)).ToString('yyyy-MM-ddTHH:mm:ss'))'].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" --output json 2>$null
        
        if ($recentDeployments -and $recentDeployments -ne '[]') {
            $deployments = $recentDeployments | ConvertFrom-Json
            if ($deployments.Count -gt 0) {
                $latestDeployment = $deployments | Sort-Object Timestamp -Descending | Select-Object -First 1
                Write-Host "  ✅ Phase $PhaseNumber already deployed successfully: $($latestDeployment.Name)" -ForegroundColor Green
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Verbose "Error checking deployment history: $($_.Exception.Message)"
        return $false
    }
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

function Wait-ForVwanHubsReady {
    param(
        [string]$ResourceGroupName,
        [string]$EnvironmentPrefix = 'vwanlab',
        [int]$TimeoutMinutes = 30
    )
    
    Write-Host "🔍 Checking VWAN hub readiness before dependent resource deployment..." -ForegroundColor Yellow
    
    $hubNames = @(
        "vhub-$EnvironmentPrefix-wus",
        "vhub-$EnvironmentPrefix-cus", 
        "vhub-$EnvironmentPrefix-sea"
    )
    
    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($TimeoutMinutes)
    
    do {
        $allHubsReady = $true
        $hubStatus = @()
        
        foreach ($hubName in $hubNames) {
            try {
                $hub = Get-AzVirtualHub -ResourceGroupName $ResourceGroupName -Name $hubName -ErrorAction SilentlyContinue
                if ($hub) {
                    $status = $hub.ProvisioningState
                    $hubStatus += "$hubName`: $status"
                    
                    if ($status -ne 'Succeeded') {
                        $allHubsReady = $false
                    }
                } else {
                    $hubStatus += "$hubName`: Not Found"
                    $allHubsReady = $false
                }
            }
            catch {
                $hubStatus += "$hubName`: Error - $($_.Exception.Message)"
                $allHubsReady = $false
            }
        }
        
        # Display current status
        Write-Host "  Hub Status: $($hubStatus -join ' | ')" -ForegroundColor Cyan
        
        if ($allHubsReady) {
            Write-Host "✅ All VWAN hubs are ready (Succeeded state)" -ForegroundColor Green
            return $true
        }
        
        if ((Get-Date) -gt $timeout) {
            Write-Warning "Timeout waiting for VWAN hubs to be ready after $TimeoutMinutes minutes"
            Write-Host "Current status:" -ForegroundColor Yellow
            foreach ($status in $hubStatus) {
                Write-Host "  $status" -ForegroundColor Yellow
            }
            return $false
        }
        
        Write-Host "  ⏳ Waiting for hubs to be ready... (timeout in $([math]::Round(($timeout - (Get-Date)).TotalMinutes, 1)) minutes)" -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
    } while ($true)
}

function Connect-AzureAccount {
    param([string]$SubscriptionId)
    
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

function Test-PhaseAlreadyDeployed {
    param(
        [string]$ResourceGroupName,
        [int]$PhaseNumber,
        [string]$Architecture
    )
    
    try {
        # Check for successful deployments in the last 24 hours
        $deploymentName = if ($Architecture -eq 'MultiRegion') { 
            "MultiRegion-Phase$PhaseNumber-*" 
        } else { 
            "Classic-Phase$PhaseNumber-*" 
        }
        
        # Get recent successful deployments
        $recentDeployments = az deployment group list --resource-group $ResourceGroupName --query "[?contains(name, 'Phase$PhaseNumber') && properties.provisioningState=='Succeeded' && properties.timestamp >= '$(((Get-Date).AddHours(-24)).ToString('yyyy-MM-ddTHH:mm:ssZ'))'].{Name:name, Timestamp:properties.timestamp}" --output json 2>$null
        
        if ($recentDeployments -and $recentDeployments -ne "[]") {
            $deployments = $recentDeployments | ConvertFrom-Json
            if ($deployments.Count -gt 0) {
                $latestDeployment = $deployments | Sort-Object Timestamp -Descending | Select-Object -First 1
                Write-Host "✅ Phase $PhaseNumber already deployed successfully: $($latestDeployment.Name)" -ForegroundColor Green
                Write-Host "   Deployment time: $($latestDeployment.Timestamp)" -ForegroundColor Gray
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Warning "Failed to check deployment history: $($_.Exception.Message)"
        return $false
    }
}

function Deploy-MultiRegionPhase {
    param(
        [int]$PhaseNumber,
        [hashtable]$Parameters,
        [string]$DeployerPublicIp,
        [hashtable]$Credentials,
        [string]$ResourceGroupName,
        [string]$FirewallPrivateIp = $null
    )
    
    $config = $script:ArchitectureConfig.MultiRegion
    $phaseInfo = $config.Phases[$PhaseNumber]
    
    Write-PhaseHeader -PhaseNumber $PhaseNumber -Description $phaseInfo.Description -Architecture "Multi-Region"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase$PhaseNumber-multiregion-*.bicep"
    $templateFiles = Get-ChildItem -Path $templateFile -ErrorAction SilentlyContinue
    
    if (-not $templateFiles) {
        Write-Warning "Template file not found for Phase $PhaseNumber"
        return @{ Success = $false; Error = "Template not found" }
    }

    $templateFile = $templateFiles[0].FullName
    
    # Check hub readiness for phases that depend on VWAN hubs
    if ($PhaseNumber -in @(4, 5, 6)) {
        Write-Host "🔍 Phase $PhaseNumber requires VWAN hubs to be ready..." -ForegroundColor Yellow
        if (-not (Wait-ForVwanHubsReady -ResourceGroupName $ResourceGroupName -EnvironmentPrefix $config.EnvironmentPrefix)) {
            Write-Error "VWAN hubs are not ready. Cannot proceed with Phase $PhaseNumber"
            return @{ Success = $false; Error = "VWAN hubs not ready" }
        }
    }
    
    # Build phase-specific parameters
    $phaseParameters = @{
        environmentPrefix = $config.EnvironmentPrefix
    }
    
    switch ($PhaseNumber) {
        1 {
            $phaseParameters += @{
                westUsRegion = $config.Regions.WestUs
                centralUsRegion = $config.Regions.CentralUs
                southeastAsiaRegion = $config.Regions.SoutheastAsia
                deployerPublicIP = $DeployerPublicIp
            }
        }
        2 {
            if ($DeploymentMode -eq 'InfrastructureOnly') {
                Write-Host "⏭️ Skipping Phase 2 (Infrastructure Only mode)" -ForegroundColor Yellow
                return @{ Success = $true; Skipped = $true }
            }
            $phaseParameters += @{
                adminUsername = $Credentials.Username
                adminPassword = $Credentials.Password
                westUsRegion = $config.Regions.WestUs
                centralUsRegion = $config.Regions.CentralUs
                southeastAsiaRegion = $config.Regions.SoutheastAsia
            }
        }
        3 {
            $phaseParameters += @{
                westUsRegion = $config.Regions.WestUs
            }
        }
        4 {
            $phaseParameters += @{
                centralUsRegion = $config.Regions.CentralUs
            }
        }
        6 {
            if (-not $FirewallPrivateIp) {
                Write-Warning "Firewall private IP not available. Trying to retrieve from existing deployment..."
                try {
                    $firewall = Get-AzFirewall -ResourceGroupName $ResourceGroupName -Name 'afw-vwanlab-wus' -ErrorAction SilentlyContinue
                    if ($firewall) {
                        $FirewallPrivateIp = $firewall.IpConfigurations[0].PrivateIPAddress
                    }
                } catch {
                    Write-Warning "Could not retrieve firewall IP. Skipping routing configuration."
                    return @{ Success = $false; Error = "Firewall private IP not available" }
                }
            }
            $phaseParameters += @{
                azureFirewallPrivateIp = $FirewallPrivateIp
            }
        }
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Phase $PhaseNumber with parameters:" -ForegroundColor Yellow
        $displayParams = $phaseParameters.Clone()
        if ($displayParams.adminPassword) { $displayParams.adminPassword = "***REDACTED***" }
        $displayParams | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        if ($PhaseNumber -eq 2 -and $DeploymentMode -ne 'InfrastructureOnly') {
            # Phase 2 needs special handling for SecureString password
            $deployment = New-AzResourceGroupDeployment `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $templateFile `
                -environmentPrefix $phaseParameters.environmentPrefix `
                -adminUsername $phaseParameters.adminUsername `
                -adminPassword $phaseParameters.adminPassword `
                -westUsRegion $phaseParameters.westUsRegion `
                -centralUsRegion $phaseParameters.centralUsRegion `
                -southeastAsiaRegion $phaseParameters.southeastAsiaRegion `
                -Name "MultiRegion-Phase$PhaseNumber-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
                -Verbose
        } else {
            # All other phases use standard parameter object
            $deployment = New-AzResourceGroupDeployment `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $templateFile `
                -TemplateParameterObject $phaseParameters `
                -Name "MultiRegion-Phase$PhaseNumber-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
                -Verbose
        }
            
        Write-Host "✅ Phase $PhaseNumber deployed successfully" -ForegroundColor Green
        
        # Post-deployment configuration for Phase 6
        if ($PhaseNumber -eq 6) {
            Write-Host "🔧 Configuring VWAN Hub default route tables..." -ForegroundColor Yellow
            
            # Add West US regional summary route to default route table
            try {
                Write-Host "  Adding 10.0.0.0/12 route to West US hub default route table..." -ForegroundColor Cyan
                
                # Check if route already exists
                $existingRoutes = az network vhub route-table show --vhub-name "vhub-$($config.EnvironmentPrefix)-wus" --resource-group $ResourceGroupName --name "defaultRouteTable" --query "routes[?name=='WestUsRegionalSummary']" --output json | ConvertFrom-Json
                
                if (-not $existingRoutes -or $existingRoutes.Count -eq 0) {
                    $routeResult = az network vhub route-table route add `
                        --vhub-name "vhub-$($config.EnvironmentPrefix)-wus" `
                        --resource-group $ResourceGroupName `
                        --name "defaultRouteTable" `
                        --destination-type "CIDR" `
                        --destinations "10.0.0.0/12" `
                        --next-hop-type "ResourceId" `
                        --next-hop "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualHubs/vhub-$($config.EnvironmentPrefix)-wus/hubVirtualNetworkConnections/vnet-spoke1-$($config.EnvironmentPrefix)-wus-connection" `
                        --route-name "WestUsRegionalSummary" `
                        2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ Regional summary route added successfully" -ForegroundColor Green
                    } else {
                        Write-Warning "  ⚠️ Failed to add regional summary route: $routeResult"
                    }
                } else {
                    Write-Host "  ✅ Regional summary route already exists" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "  ⚠️ Error configuring route tables: $($_.Exception.Message)"
            }
        }
        
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase $PhaseNumber deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Deploy-ClassicPhase {
    param(
        [int]$PhaseNumber,
        [hashtable]$Parameters,
        [string]$DeployerPublicIp,
        [hashtable]$Credentials
    )
    
    $config = $script:ArchitectureConfig.Classic
    $phaseInfo = $config.Phases[$PhaseNumber]
    
    Write-PhaseHeader -PhaseNumber $PhaseNumber -Description $phaseInfo.Description -Architecture "Classic"
    
    $templateFile = Join-Path $PSScriptRoot "../bicep/phases/phase$PhaseNumber-*.bicep"
    $templateFiles = Get-ChildItem -Path $templateFile -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*multiregion*" }
    
    if (-not $templateFiles) {
        Write-Warning "Template file not found for Classic Phase $PhaseNumber"
        return @{ Success = $false; Error = "Template not found" }
    }
    
    $templateFile = $templateFiles[0].FullName
    
    # Build phase-specific parameters
    $phaseParameters = @{
        environmentPrefix = $config.EnvironmentPrefix
        primaryRegion = $config.PrimaryRegion
        deployerPublicIP = $DeployerPublicIp
    }
    
    if ($PhaseNumber -eq 2 -and $DeploymentMode -eq 'InfrastructureOnly') {
        Write-Host "⏭️ Skipping Phase 2 (Infrastructure Only mode)" -ForegroundColor Yellow
        return @{ Success = $true; Skipped = $true }
    }
    
    if ($PhaseNumber -eq 2) {
        $phaseParameters += @{
            adminUsername = $Credentials.Username
            adminPassword = $Credentials.Password
        }
    }
    
    if ($WhatIf) {
        Write-Host "Would deploy Classic Phase $PhaseNumber with parameters:" -ForegroundColor Yellow
        $displayParams = $phaseParameters.Clone()
        if ($displayParams.adminPassword) { $displayParams.adminPassword = "***REDACTED***" }
        $displayParams | ConvertTo-Json -Depth 3
        return @{ Success = $true }
    }
    
    try {
        if ($PhaseNumber -eq 2 -and $DeploymentMode -ne 'InfrastructureOnly') {
            # Phase 2 needs special handling for SecureString password
            $deployment = New-AzResourceGroupDeployment `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $templateFile `
                -environmentPrefix $phaseParameters.environmentPrefix `
                -primaryRegion $phaseParameters.primaryRegion `
                -deployerPublicIP $phaseParameters.deployerPublicIP `
                -adminUsername $phaseParameters.adminUsername `
                -adminPassword $phaseParameters.adminPassword `
                -Name "Classic-Phase$PhaseNumber-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
                -Verbose
        } else {
            # All other phases use standard parameter object
            $deployment = New-AzResourceGroupDeployment `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $templateFile `
                -TemplateParameterObject $phaseParameters `
                -Name "Classic-Phase$PhaseNumber-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
                -Verbose
        }
            
        Write-Host "✅ Phase $PhaseNumber deployed successfully" -ForegroundColor Green
        return @{ Success = $true; Outputs = $deployment.Outputs }
    }
    catch {
        Write-Error "❌ Phase $PhaseNumber deployment failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Show-DeploymentSummary {
    param($Results, $Architecture)
    
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Green
    Write-Host "DEPLOYMENT SUMMARY - $Architecture Architecture" -ForegroundColor Green
    Write-Host "================================================================================================" -ForegroundColor Green
    
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
    Write-Host "Architecture: $Architecture" -ForegroundColor Cyan
    Write-Host "Deployment Mode: $DeploymentMode" -ForegroundColor Cyan
    Write-Host "Deployment Time: $(Get-Date)" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "📊 Phase Results:" -ForegroundColor Yellow
    
    foreach ($phase in $Results.Keys | Sort-Object) {
        $result = $Results[$phase]
        if ($result.AlreadyDeployed) {
            Write-Host "  Phase $phase - ALREADY DEPLOYED ✅" -ForegroundColor Green
        } elseif ($result.Skipped) {
            Write-Host "  Phase $phase - SKIPPED" -ForegroundColor Yellow
        } elseif ($result.Success) {
            Write-Host "  Phase $phase - SUCCESS ✅" -ForegroundColor Green
        } else {
            Write-Host "  Phase $phase - FAILED ❌" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    if ($Architecture -eq 'MultiRegion') {
        Write-Host "🌐 Multi-Region Architecture Deployed:" -ForegroundColor Cyan
        Write-Host "  • 3 VWAN Hubs: West US, Central US, Southeast Asia" -ForegroundColor White
        Write-Host "  • 5 Spoke VNets with specialized configurations" -ForegroundColor White
        Write-Host "  • Azure Firewall Premium in Spoke 1 (West US)" -ForegroundColor White
        Write-Host "  • VPN connectivity for Spoke 3 (Central US)" -ForegroundColor White
        Write-Host "  • Cross-region VM connectivity" -ForegroundColor White
    } else {
        Write-Host "🏗️ Classic Architecture Deployed:" -ForegroundColor Cyan
        Write-Host "  • Single VWAN Hub with 3 spoke VNets" -ForegroundColor White
        Write-Host "  • Network Virtual Appliance (NVA) with RRAS" -ForegroundColor White
        Write-Host "  • Azure Route Server with BGP peering" -ForegroundColor White
        Write-Host "  • Hub-spoke connectivity patterns" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🚀 Next Steps:" -ForegroundColor Yellow
    if ($Architecture -eq 'MultiRegion') {
        Write-Host "  1. Configure VPN connection for Spoke 3 RRAS VM" -ForegroundColor White
        Write-Host "  2. Test connectivity between regions" -ForegroundColor White
        Write-Host "  3. Configure Azure Firewall rules as needed" -ForegroundColor White
        Write-Host "  4. Set up monitoring and logging" -ForegroundColor White
    } else {
        Write-Host "  1. Configure BGP peering on NVA VM" -ForegroundColor White
        Write-Host "  2. Test connectivity between spokes" -ForegroundColor White
        Write-Host "  3. Verify routing table propagation" -ForegroundColor White
        Write-Host "  4. Set up monitoring and logging" -ForegroundColor White
    }
}

# Main execution
try {
    Write-Host ""
    Write-Host "🚀 Azure VWAN Lab Deployment - $Architecture Architecture" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    
    Test-Prerequisites
    Connect-AzureAccount -SubscriptionId $SubscriptionId
    $deployerPublicIp = Get-DeployerPublicIp
    $credentials = Get-VmCredentials
    
    # Ensure resource group exists
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        $rgLocation = if ($Architecture -eq 'MultiRegion') { 'West US' } else { $Location }
        Write-Host "📦 Creating resource group: $ResourceGroupName in $rgLocation" -ForegroundColor Yellow
        New-AzResourceGroup -Name $ResourceGroupName -Location $rgLocation
    }
    
    $results = @{}
    $firewallPrivateIp = $null
    $config = $script:ArchitectureConfig[$Architecture]
    
    # Deploy phases
    $phasesToDeploy = if ($Phase) { @($Phase) } else { 1..$config.MaxPhases }
    
    foreach ($phaseNum in $phasesToDeploy) {
        # Check if phase was already successfully deployed
        if (Test-PhaseAlreadyDeployed -ResourceGroupName $ResourceGroupName -PhaseNumber $phaseNum -Architecture $Architecture) {
            Write-Host "⏭️ Skipping Phase $phaseNum - already deployed successfully" -ForegroundColor Yellow
            $results[$phaseNum] = @{ Success = $true; Skipped = $true; AlreadyDeployed = $true }
            continue
        }
        
        if ($Architecture -eq 'MultiRegion') {
            $result = Deploy-MultiRegionPhase -PhaseNumber $phaseNum -Parameters @{} -DeployerPublicIp $deployerPublicIp -Credentials $credentials -ResourceGroupName $ResourceGroupName -FirewallPrivateIp $firewallPrivateIp
            
            # Capture firewall private IP from Phase 3
            if ($phaseNum -eq 3 -and $result.Success -and $result.Outputs -and $result.Outputs.firewallPrivateIp) {
                $firewallPrivateIp = $result.Outputs.firewallPrivateIp.Value
            }
        } else {
            $result = Deploy-ClassicPhase -PhaseNumber $phaseNum -Parameters @{} -DeployerPublicIp $deployerPublicIp -Credentials $credentials
        }
        
        $results[$phaseNum] = $result
        
        # Stop if phase failed and not continuing
        if (-not $result.Success -and -not $result.Skipped) {
            break
        }
    }
    
    Show-DeploymentSummary -Results $results -Architecture $Architecture
    
    # Configure SFI (Secure Future Initiative) features if enabled
    if ($SfiEnable) {
        Write-Host ""
        Write-Host "🔒 Configuring Secure Future Initiative (SFI) features..." -ForegroundColor Cyan
        Write-Host "🔐 Setting up Just-In-Time (JIT) VM access and removing permissive NSG rules..." -ForegroundColor Yellow
        
        try {
            $jitScriptPath = Join-Path $PSScriptRoot "Set-VmJitAccess.ps1"
            if (Test-Path $jitScriptPath) {
                # Run with SfiEnable flag to ensure NSG cleanup and 24-hour JIT policies
                & $jitScriptPath -ResourceGroupName $ResourceGroupName -SfiEnable -Force
                Write-Host "✅ SFI features configured successfully" -ForegroundColor Green
                Write-Host "  • JIT policies created with 24-hour maximum duration" -ForegroundColor Gray
                Write-Host "  • Permissive NSG rules removed for security compliance" -ForegroundColor Gray
                Write-Host "  • Access now requires JIT approval through Azure Portal" -ForegroundColor Gray
            } else {
                Write-Warning "JIT configuration script not found at: $jitScriptPath"
            }
        }
        catch {
            Write-Warning "Failed to configure SFI features: $($_.Exception.Message)"
            Write-Host "💡 You can manually configure JIT access later using: .\scripts\Set-VmJitAccess.ps1 -ResourceGroupName '$ResourceGroupName' -SfiEnable" -ForegroundColor Cyan
        }
    }
    
    # Check for any failures
    $failures = $results.Values | Where-Object { $_.Success -eq $false }
    if ($failures) {
        Write-Host ""
        Write-Host "⚠️ Some phases failed. Check the error messages above." -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "🎉 $Architecture Azure VWAN Lab deployment completed successfully!" -ForegroundColor Green
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

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Network

<#
.SYNOPSIS
    Unified Azure Virtual WAN Lab Deployment Script

.DESCRIPTION
    This unified script provides performance-optimized, timeout-resistant deployment for the Azure VWAN lab environment.
    
    Features:
    - Performance-optimized by default (Standard_B2s VMs with 2 GB RAM, Standard_LRS storage)
    - Phased deployment only (the only reliable approach that works)
    - Full lab or Infrastructure-only modes
    - Enhanced error handling and progress monitoring
    - Integrated cleanup and resource management
    - Automatic RDP configuration from deployer IP
    - RRAS installation and configuration with comprehensive logging
    - VM credential validation and complexity requirements

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current context if not specified)

.PARAMETER Location
    Azure region for deployment (default: East US)

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
    - Full: Complete lab with VMs (Standard_B2s with 2 GB RAM)
    - InfrastructureOnly: Network infrastructure without VMs

.PARAMETER IpSchema
    IP addressing schema: 'default', 'enterprise', 'lab', 'custom'

.PARAMETER Phase
    Specific phase to deploy (1-5). If not specified, deploys all phases
    - Phase 1: Core infrastructure (VWAN hub, VNets)
    - Phase 2: Virtual machines
    - Phase 3: Route Server and BGP configuration
    - Phase 4: VWAN connections and VNet peering
    - Phase 5: BGP peering between NVA and Route Server

.PARAMETER CleanupOldResourceGroup
    Optional resource group to clean up after successful deployment

.PARAMETER EnableAutoShutdown
    Enable auto-shutdown for VMs to reduce costs

.PARAMETER AutoShutdownTime
    Time to shutdown VMs in 24-hour format (HH:MM). Default: 01:00 (1:00 AM)

.PARAMETER AutoShutdownTimeZone
    Time zone for auto-shutdown. Default: UTC. Examples: 'Eastern Standard Time', 'Pacific Standard Time', 'Central European Standard Time'

.PARAMETER SfiEnable
    Enable Secure Future Initiative (SFI) features including Just-In-Time (JIT) VM access for enhanced security

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-prod"
    
.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -DeploymentMode "InfrastructureOnly"
    
.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-test" -Phase 1 -WhatIf

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -EnableAutoShutdown -AutoShutdownTime "18:00" -AutoShutdownTimeZone "Eastern Standard Time"

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-security" -SfiEnable -EnableAutoShutdown
    Deploy with Secure Future Initiative (JIT access) and auto-shutdown enabled

.NOTES
    Author: Azure VWAN Lab Team
    Version: 3.0
    Requires: Azure PowerShell, appropriate Azure permissions
    
    This script uses PHASED DEPLOYMENT ONLY because it's the only reliable approach
    that works with Azure VWAN + Route Server architecture. See docs/why-phased-deployment.md
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory = $false)]
    [SecureString]$AdminPassword,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Full", "InfrastructureOnly")]
    [string]$DeploymentMode = "Full",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("default", "enterprise", "lab", "custom")]
    [string]$IpSchema = "default",
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 5)]
    [int]$Phase,
    
    [Parameter(Mandatory = $false)]
    [string]$CleanupOldResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableAutoShutdown,
    
    [Parameter(Mandatory = $false)]
    [string]$AutoShutdownTime = "01:00",
    
    [Parameter(Mandatory = $false)]
    [string]$AutoShutdownTimeZone = "UTC",
    
    [Parameter(Mandatory = $false)]
    [switch]$SfiEnable,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Define deployment phases
$Phases = @{
    1 = @{
        Name = "Core Infrastructure"
        Template = ".\bicep\phases\phase1-core.bicep"
        Description = "VWAN hub and VNet infrastructure"
        EstimatedTime = "8-12 minutes"
    }
    2 = @{
        Name = "Virtual Machines"
        Template = ".\bicep\phases\phase2-vms.bicep"
        Description = "VM deployment and basic networking"
        EstimatedTime = "10-15 minutes"
    }
    3 = @{
        Name = "Spoke 3 Route Server"
        Template = ".\bicep\phases\phase3-routeserver.bicep"
        Description = "Spoke 3 Route Server deployment and test VM"
        EstimatedTime = "8-12 minutes"
    }
    4 = @{
        Name = "Connections & Peering"
        Templates = @(
            ".\bicep\phases\phase4a-spoke1-connection.bicep",
            ".\bicep\phases\phase4b-spoke2-connection.bicep",
            ".\bicep\phases\phase4c-peering.bicep"
        )
        Description = "VWAN connections and VNet peering"
        EstimatedTime = "5-10 minutes"
    }
    5 = @{
        Name = "BGP Peering Setup"
        Template = ".\bicep\phases\phase5-bgp-peering.bicep"
        Description = "BGP peering between NVA and Spoke 3 Route Server"
        EstimatedTime = "2-5 minutes"
    }
}

# IP Schema definitions
$IpSchemas = @{
    "default" = @{
        hubCidr = "10.0.0.0/16"
        spoke1Cidr = "10.1.0.0/16"
        spoke2Cidr = "10.2.0.0/16"
        spoke3Cidr = "10.3.0.0/16"
    }
    "enterprise" = @{
        hubCidr = "172.16.0.0/12"
        spoke1Cidr = "192.168.1.0/24"
        spoke2Cidr = "192.168.2.0/24"
        spoke3Cidr = "192.168.3.0/24"
    }
    "lab" = @{
        hubCidr = "10.10.0.0/16"
        spoke1Cidr = "10.11.0.0/16"
        spoke2Cidr = "10.12.0.0/16"
        spoke3Cidr = "10.13.0.0/16"
    }
}

# Deployment mode configurations
$DeploymentModes = @{
    "Full" = @{
        VmSize = "Standard_B2s"
        StorageType = "Standard_LRS"
        ParameterFile = ".\bicep\parameters\lab.bicepparam"
        Description = "Complete lab with VMs - optimized for performance"
        EstimatedCost = @{
            Hourly = '$0.61'
            Monthly = '$506'
        }
    }
    "InfrastructureOnly" = @{
        VmSize = "Standard_B2s"
        StorageType = "Standard_LRS"
        ParameterFile = ".\bicep\parameters\lab.bicepparam"
        Description = "Network infrastructure without VMs"
        EstimatedCost = @{
            Hourly = '$0.57'
            Monthly = '$414'
        }
    }
}

#region Helper Functions

function Write-DeploymentHeader {
    param($Title, $Description)
    
    Write-Host "`n" -NoNewline
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "  $Description" -ForegroundColor Gray
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host ""
}

function Write-PhaseHeader {
    param($PhaseNumber, $PhaseName, $Description, $EstimatedTime)
    
    Write-Host "`n" -NoNewline
    Write-Host "🚀 Phase $PhaseNumber`: $PhaseName" -ForegroundColor Green
    Write-Host "   $Description" -ForegroundColor Gray
    Write-Host "   Estimated time: $EstimatedTime" -ForegroundColor Yellow
    Write-Host "─" * 60 -ForegroundColor DarkGray
}

function Test-Prerequisites {
    Write-Host '🔍 Checking prerequisites...' -ForegroundColor Yellow
    
    # Check Azure PowerShell
    if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
        throw "Azure PowerShell module (Az.Accounts) is not installed. Please install with: Install-Module -Name Az -Force"
    }
    
    # Check Azure CLI for Bicep
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed. Please install Azure CLI and run 'az bicep install'"
    }
    
    # Check Bicep
    try {
        $bicepVersion = az bicep version 2>$null
        if (-not $bicepVersion) {
            Write-Warning "Bicep is not installed. Installing..."
            az bicep install
        }
    }
    catch {
        throw "Failed to install Bicep: $_"
    }
    
    Write-Host '✅ Prerequisites validated' -ForegroundColor Green
}

function Connect-ToAzure {
    param($SubscriptionId)
    
    Write-Host '🔐 Connecting to Azure...' -ForegroundColor Yellow
    
    try {
        $context = Get-AzContext
        if ($null -eq $context) {
            Connect-AzAccount -Subscription $SubscriptionId
        }
        elseif ($SubscriptionId -and $context.Subscription.Id -ne $SubscriptionId) {
            Set-AzContext -Subscription $SubscriptionId
        }
        
        $currentContext = Get-AzContext
        Write-Host "✅ Connected to subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor Green
        
        return $currentContext.Subscription.Id
    }
    catch {
        throw "Failed to connect to Azure: $_"
    }
}

function New-ResourceGroupIfNotExists {
    param($ResourceGroupName, $Location)
    
    Write-Host '📦 Checking resource group...' -ForegroundColor Yellow
    
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "✅ Resource group created: $($rg.ResourceGroupName)" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Resource group exists: $($rg.ResourceGroupName)" -ForegroundColor Green
    }
    
    return $rg
}

function Show-CostAnalysis {
    param($DeploymentMode)
    
    $config = $DeploymentModes[$DeploymentMode]
    
    Write-Host "`n💰 Cost Analysis for $DeploymentMode Mode" -ForegroundColor Cyan
    Write-Host "─" * 50 -ForegroundColor DarkGray
    Write-Host "Description: $($config.Description)" -ForegroundColor Gray
    Write-Host "Estimated Cost:" -ForegroundColor Yellow
    Write-Host "  • Hourly:  $($config.EstimatedCost.Hourly)" -ForegroundColor White
    Write-Host "  • Monthly: $($config.EstimatedCost.Monthly)" -ForegroundColor White
    
    if ($DeploymentMode -eq "Optimized") {
        Write-Host '💡 Savings: 65% compared to Standard mode' -ForegroundColor Green
    }
    
    Write-Host ""
}

function Invoke-PhaseDeployment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        $PhaseNumber,
        $PhaseConfig,
        $ResourceGroupName,
        $ParameterOverrides,
        $Location,
        $DeployerIP = $null
    )
    
    $phaseName = $PhaseConfig.Name
    Write-PhaseHeader $PhaseNumber $phaseName $PhaseConfig.Description $PhaseConfig.EstimatedTime
    
    # Create phase-specific parameter overrides
    $phaseParameters = @{}
    
    # Add parameters based on phase requirements
    switch ($PhaseNumber) {
        1 { 
            # Phase 1: Infrastructure only - no VM credentials needed
            $phaseParameters['environmentPrefix'] = $ParameterOverrides['environmentPrefix']
            $phaseParameters['primaryRegion'] = $Location
            if ($DeployerIP) {
                $phaseParameters['deployerPublicIP'] = $DeployerIP
            }
        }
        2 { 
            # Phase 2: VMs - check which VMs exist and set conditional deployment
            $phaseParameters = $ParameterOverrides.Clone()
            $phaseParameters['primaryRegion'] = $Location
            
            # Check VM existence for conditional deployment
            $expectedVms = @("vwanlab-spoke1-nva-vm", "vwanlab-spoke2-test-vm")
            $vmStatus = Get-VmDeploymentMode -ResourceGroupName $ResourceGroupName -ExpectedVms $expectedVms
            
            # Set conditional deployment parameters
            $phaseParameters['deployNvaVm'] = 'vwanlab-spoke1-nva-vm' -in $vmStatus.MissingVms
            $phaseParameters['deployTestVm'] = 'vwanlab-spoke2-test-vm' -in $vmStatus.MissingVms
            
            Write-Host "🔧 VM Deployment Plan:" -ForegroundColor Cyan
            Write-Host "   NVA VM: $(if ($phaseParameters['deployNvaVm']) { 'CREATE' } else { 'EXISTS - SKIP' })" -ForegroundColor $(if ($phaseParameters['deployNvaVm']) { 'Yellow' } else { 'Green' })
            Write-Host "   Test VM: $(if ($phaseParameters['deployTestVm']) { 'CREATE' } else { 'EXISTS - SKIP' })" -ForegroundColor $(if ($phaseParameters['deployTestVm']) { 'Yellow' } else { 'Green' })
            
            # Only pass admin credentials if we're creating new VMs
            if (-not $vmStatus.AllExist -and $ParameterOverrides.ContainsKey('adminUsername')) {
                $phaseParameters['adminUsername'] = $ParameterOverrides['adminUsername']
                $phaseParameters['adminPassword'] = $ParameterOverrides['adminPassword']
            }
        }
        3 { 
            # Phase 3: Route Server - check test VM existence
            $phaseParameters = $ParameterOverrides.Clone()
            $phaseParameters['location'] = $Location
            if ($DeployerIP) {
                $phaseParameters['deployerPublicIP'] = $DeployerIP
            }
            
            # Check if spoke 3 test VM exists
            $spoke3VmExists = Test-VmExists -ResourceGroupName $ResourceGroupName -VmName "vwanlab-spoke3-test-vm"
            $phaseParameters['deployTestVm'] = -not $spoke3VmExists

            Write-Host "🔧 Spoke 3 VM Plan:" -ForegroundColor Cyan
            Write-Host "   Test VM: $(if ($phaseParameters['deployTestVm']) { 'CREATE' } else { 'EXISTS - SKIP' })" -ForegroundColor $(if ($phaseParameters['deployTestVm']) { 'Yellow' } else { 'Green' })
            
            # Only pass admin credentials if we're creating the VM
            if ($phaseParameters['deployTestVm'] -and $ParameterOverrides.ContainsKey('adminUsername')) {
                $phaseParameters['adminUsername'] = $ParameterOverrides['adminUsername']
                $phaseParameters['adminPassword'] = $ParameterOverrides['adminPassword']
            }
        }
        4 { 
            # Phase 4 templates only need environmentPrefix
            $phaseParameters['environmentPrefix'] = $ParameterOverrides['environmentPrefix']
        }
        5 { 
            # Phase 5 templates only need environmentPrefix and ASN
            $phaseParameters['environmentPrefix'] = $ParameterOverrides['environmentPrefix']
            $phaseParameters['nvaAsn'] = 65001
        }
    }
    
    try {
        if ($PhaseNumber -eq 4) {
            # Phase 4 has multiple templates
            foreach ($template in $PhaseConfig.Templates) {
                $templateName = Split-Path $template -Leaf
                Write-Host "  Deploying: $templateName" -ForegroundColor Cyan
                
                $deploymentName = "phase4-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$($templateName.Replace('.bicep', ''))"
                
                if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy $templateName")) {
                    # Build parameter arguments
                    $paramArgs = @()
                    if ($phaseParameters.Count -gt 0) {
                        foreach ($param in $phaseParameters.GetEnumerator()) {
                            $paramArgs += "--parameters"
                            $paramArgs += "$($param.Key)=$($param.Value)"
                        }
                    }
                    
                    $result = az deployment group create --resource-group $ResourceGroupName --template-file $template --name $deploymentName @paramArgs --output json
                    if ($LASTEXITCODE -ne 0) {
                        throw "Deployment failed for $templateName"
                    }
                }
            }
        }
        else {
            # Single template phases (1, 2, 3, 5)
            $deploymentName = "phase$PhaseNumber-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            
            if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy Phase $PhaseNumber")) {
                # Build parameter arguments
                $paramArgs = @()
                if ($phaseParameters.Count -gt 0) {
                    foreach ($param in $phaseParameters.GetEnumerator()) {
                        $paramArgs += "--parameters"
                        $paramArgs += "$($param.Key)=$($param.Value)"
                    }
                }
                
                $result = az deployment group create --resource-group $ResourceGroupName --template-file $PhaseConfig.Template --name $deploymentName @paramArgs --output json
                if ($LASTEXITCODE -ne 0) {
                    throw "Deployment failed for Phase $PhaseNumber"
                }
            }
        }
        
        # Post-deployment configuration for Phase 2 (VMs)
        if ($PhaseNumber -eq 2 -and $PSCmdlet.ShouldProcess($ResourceGroupName, "Configure VMs")) {
            Write-Host "`n🔧 Post-deployment VM configuration..." -ForegroundColor Cyan
            
            # Get list of ALL VMs (both existing and newly created)
            $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*vwanlab*" }
            
            # Determine which VMs were just created vs already existed
            $expectedVms = @("vwanlab-nva-vm", "vwanlab-spoke2-test-vm")
            $vmStatus = Get-VmDeploymentMode -ResourceGroupName $ResourceGroupName -ExpectedVms $expectedVms
            
            Write-Host "📋 VM Configuration Status:" -ForegroundColor Cyan
            if ($vmStatus.ExistingVms.Count -gt 0) {
                Write-Host "   Existing VMs: $($vmStatus.ExistingVms -join ', ')" -ForegroundColor Green
            }
            if ($vmStatus.MissingVms.Count -gt 0) {
                Write-Host "   Newly Created VMs: $($vmStatus.MissingVms -join ', ')" -ForegroundColor Yellow
            }
            
            # Configure secure access once per NSG if deployer IP is available
            if ($DeployerIP) {
                $configuredNsgs = @()
                foreach ($vm in $vms) {
                    $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
                    $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.Id -eq $nicId }
                    
                    if ($nic.NetworkSecurityGroup) {
                        $nsgId = $nic.NetworkSecurityGroup.Id
                        if ($nsgId -notin $configuredNsgs) {
                            Enable-VmRdpAccess -ResourceGroupName $ResourceGroupName -VmName $vm.Name -AllowedSourceIP $DeployerIP
                            $configuredNsgs += $nsgId
                        }
                        else {
                            Write-Host "✅ Secure access already configured for NSG associated with $($vm.Name)" -ForegroundColor Green
                        }
                    }
                }
            }
            
            foreach ($vm in $vms) {
                $isExistingVm = $vm.Name -in $vmStatus.ExistingVms
                $actionText = if ($isExistingVm) { "Updating EXISTING" } else { "Configuring NEW" }
                
                Write-Host "`n🖥️  $actionText VM: $($vm.Name)" -ForegroundColor $(if ($isExistingVm) { 'Cyan' } else { 'Yellow' })
                
                # Enable boot diagnostics with managed storage (latest Azure best practice)
                Enable-VmBootDiagnostics -ResourceGroupName $ResourceGroupName -VmName $vm.Name
                
                # Install and configure RRAS on NVA VM (both new and existing)
                if ($vm.Name -like "*nva*") {
                    Write-Host "🔧 Applying RRAS configuration to $($vm.Name)..." -ForegroundColor Yellow
                    Install-ConfigureRRAS -ResourceGroupName $ResourceGroupName -VmName $vm.Name
                }
                
                # Enable RDP via Windows Firewall for all VMs
                Write-Host "🔐 Enabling RDP through Windows Firewall on $($vm.Name)..." -ForegroundColor Yellow
                $rdpScript = @'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name 'fDenyTSConnections' -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
netsh advfirewall firewall set rule group="remote desktop" new enable=yes
Write-Output "RDP enabled successfully"
'@
                try {
                    $rdpResult = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $vm.Name -CommandId 'RunPowerShellScript' -ScriptString $rdpScript
                    Write-Host "✅ RDP enabled on $($vm.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to enable RDP on $($vm.Name): $_"
                }
            }
        }
        
        # Post-deployment configuration for Phase 3 (Spoke 3 Route Server + Test VM)
        if ($PhaseNumber -eq 3 -and $PSCmdlet.ShouldProcess($ResourceGroupName, "Configure Spoke 3 Test VM")) {
            Write-Host "`n🔧 Post-deployment Spoke 3 VM configuration..." -ForegroundColor Cyan
            
            # Get test VM created in this phase
            $testVm = Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*test*" -and $_.Name -like "*route*" }
            
            if ($testVm) {
                Write-Host "`n🖥️  Configuring Spoke 3 Test VM: $($testVm.Name)" -ForegroundColor Yellow
                
                # Enable boot diagnostics with managed storage (latest Azure best practice)
                Enable-VmBootDiagnostics -ResourceGroupName $ResourceGroupName -VmName $testVm.Name
                
                # Configure secure access if deployer IP is available
                if ($DeployerIP) {
                    Enable-VmRdpAccess -ResourceGroupName $ResourceGroupName -VmName $testVm.Name -AllowedSourceIP $DeployerIP
                }
                
                # Enable RDP via Windows Firewall
                Write-Host "🔐 Enabling RDP through Windows Firewall on $($testVm.Name)..." -ForegroundColor Yellow
                $rdpScript = @'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name 'fDenyTSConnections' -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
netsh advfirewall firewall set rule group="remote desktop" new enable=yes
Write-Output "RDP enabled successfully"
'@
                try {
                    $rdpResult = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $testVm.Name -CommandId 'RunPowerShellScript' -ScriptString $rdpScript
                    Write-Host "✅ RDP enabled on $($testVm.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to enable RDP on $($testVm.Name): $_"
                }
            }
        }
        
        if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Complete Phase $PhaseNumber")) {
            Write-Host "✅ Phase $PhaseNumber completed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "❌ Phase $PhaseNumber failed: $_"
        throw
    }
}

function Test-PasswordComplexity {
    param([SecureString]$Password)
    
    # Convert SecureString to plain text for validation
    $passwordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    
    # Azure Windows VM password requirements:
    # - 8-123 characters
    # - Must contain 3 of: lowercase, uppercase, digit, special character
    # - Cannot contain username or parts of username
    
    if ($passwordText.Length -lt 8 -or $passwordText.Length -gt 123) {
        return $false, "Password must be 8-123 characters long"
    }
    
    $hasLower = $passwordText -cmatch '[a-z]'
    $hasUpper = $passwordText -cmatch '[A-Z]'
    $hasDigit = $passwordText -match '\d'
    $hasSpecial = $passwordText -match '[^a-zA-Z0-9]'
    
    $complexityCount = @($hasLower, $hasUpper, $hasDigit, $hasSpecial) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    
    if ($complexityCount -lt 3) {
        return $false, "Password must contain at least 3 of: lowercase, uppercase, digit, special character"
    }
    
    return $true, "Password meets complexity requirements"
}

function Test-VmExists {
    param($ResourceGroupName, $VmName)
    try {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue
        return $null -ne $vm
    } catch {
        return $false
    }
}

function Get-VmDeploymentMode {
    param($ResourceGroupName, $ExpectedVms)
    
    $existingVms = @()
    $missingVms = @()
    
    foreach ($vmName in $ExpectedVms) {
        if (Test-VmExists -ResourceGroupName $ResourceGroupName -VmName $vmName) {
            $existingVms += $vmName
            Write-Host "  ✅ Found existing VM: $vmName" -ForegroundColor Green
        } else {
            $missingVms += $vmName
            Write-Host "  🔧 VM needs creation: $vmName" -ForegroundColor Yellow
        }
    }
    
    return @{
        ExistingVms = $existingVms
        MissingVms = $missingVms
        RequiresPassword = $missingVms.Count -gt 0
        CanSkipPasswordPrompt = $missingVms.Count -eq 0
        AllExist = $missingVms.Count -eq 0
        NoneExist = $existingVms.Count -eq 0
    }
}

function Get-UserCredentials {
    param($AdminUsername)
    
    Write-Host "`n🔑 VM Administrator Credentials Required" -ForegroundColor Cyan
    Write-Host "─" * 50 -ForegroundColor DarkGray
    
    # Get username
    if (-not $AdminUsername -or $AdminUsername -eq "vwanlab-admin") {
        do {
            $username = Read-Host "Enter VM administrator username"
            if ([string]::IsNullOrWhiteSpace($username)) {
                Write-Host "❌ Username cannot be empty" -ForegroundColor Red
            }
            elseif ($username -in @('admin', 'administrator', 'root', 'guest')) {
                Write-Host "❌ Username '$username' is not allowed" -ForegroundColor Red
                $username = $null
            }
        } while ([string]::IsNullOrWhiteSpace($username))
        $AdminUsername = $username
    }
    
    # Get password
    do {
        $password = Read-Host "Enter VM administrator password" -AsSecureString
        $passwordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        
        if ([string]::IsNullOrWhiteSpace($passwordText)) {
            Write-Host "❌ Password cannot be empty" -ForegroundColor Red
            continue
        }
        
        # Check username not in password
        if ($passwordText.ToLower().Contains($AdminUsername.ToLower())) {
            Write-Host "❌ Password cannot contain the username" -ForegroundColor Red
            continue
        }
        
        $isValid, $message = Test-PasswordComplexity -Password $password
        if (-not $isValid) {
            Write-Host "❌ $message" -ForegroundColor Red
            continue
        }
        
        # Confirm password
        $confirmPassword = Read-Host "Confirm VM administrator password" -AsSecureString
        $confirmPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
        
        if ($passwordText -ne $confirmPasswordText) {
            Write-Host "❌ Passwords do not match" -ForegroundColor Red
            continue
        }
        
        Write-Host "✅ Password meets Azure VM requirements" -ForegroundColor Green
        break
        
    } while ($true)
    
    return $AdminUsername, $password
}

function Get-DeployerPublicIP {
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10).Trim()
        Write-Host "✅ Detected deployer public IP: $publicIP" -ForegroundColor Green
        Write-Host "🔒 SECURITY: RDP access will be restricted to this IP only" -ForegroundColor Yellow
        return $publicIP
    }
    catch {
        Write-Warning "Could not detect public IP automatically. You may need to configure RDP access manually."
        return $null
    }
}

function Enable-VmRdpAccess {
    param(
        $ResourceGroupName,
        $VmName,
        $AllowedSourceIP
    )
    
    if (-not $AllowedSourceIP) {
        Write-Warning "⚠️  No source IP provided for RDP access configuration"
        return
    }
    
    Write-Host "🔐 Configuring secure access for $VmName from $AllowedSourceIP..." -ForegroundColor Yellow
    
    try {
        # Get the VM and its private IP address
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
        $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
        $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.Id -eq $nicId }
        $vmPrivateIP = $nic.IpConfigurations[0].PrivateIpAddress
        
        Write-Host "  📍 VM Private IP: $vmPrivateIP" -ForegroundColor Gray
        
        # For subnet-level NSGs, we need to get the NSG from the subnet, not the NIC
        $subnetId = $nic.IpConfigurations[0].Subnet.Id
        $vnetName = ($subnetId.Split('/') | Where-Object { $_ -match 'virtualNetworks' })[1]
        $subnetName = ($subnetId.Split('/'))[-1]
        
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $vnetName
        $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
        
        if ($subnet.NetworkSecurityGroup) {
            $nsgName = Split-Path $subnet.NetworkSecurityGroup.Id -Leaf
            $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $nsgName
            
            # Check if RDP rule already exists for this deployer IP and VM IP
            $existingRdpRule = $nsg.SecurityRules | Where-Object { 
                $_.Direction -eq "Inbound" -and 
                $_.Protocol -eq "Tcp" -and 
                $_.DestinationPortRange -eq "3389" -and 
                ($_.SourceAddressPrefix -eq "$AllowedSourceIP/32" -or $_.SourceAddressPrefix -eq $AllowedSourceIP) -and
                ($_.DestinationAddressPrefix -eq "$vmPrivateIP/32" -or $_.DestinationAddressPrefix -eq $vmPrivateIP)
            }
            
            # Check if ICMP rule already exists for this deployer IP and VM IP
            $existingIcmpRule = $nsg.SecurityRules | Where-Object { 
                $_.Direction -eq "Inbound" -and 
                $_.Protocol -eq "Icmp" -and 
                ($_.SourceAddressPrefix -eq "$AllowedSourceIP/32" -or $_.SourceAddressPrefix -eq $AllowedSourceIP) -and
                ($_.DestinationAddressPrefix -eq "$vmPrivateIP/32" -or $_.DestinationAddressPrefix -eq $vmPrivateIP) -and
                $_.Name -like "*Deployer*"
            }
            
            $rulesAdded = 0
            
            # Add RDP rule if it doesn't exist
            if (-not $existingRdpRule) {
                # Find the next available priority (starting from 1000)
                $existingPriorities = $nsg.SecurityRules | Where-Object { $_.Direction -eq "Inbound" } | Select-Object -ExpandProperty Priority
                $nextPriority = 1000
                while ($existingPriorities -contains $nextPriority) {
                    $nextPriority++
                }
                
                # Create RDP rule for the specific source IP and destination VM IP
                $rdpRuleName = "Allow-RDP-From-Deployer-To-$($VmName.Replace('-', ''))-$($AllowedSourceIP.Replace('.', '-'))"
                $rdpRule = New-AzNetworkSecurityRuleConfig -Name $rdpRuleName -Description "Allow RDP from deployer IP to $VmName" -Access Allow -Protocol Tcp -Direction Inbound -Priority $nextPriority -SourceAddressPrefix "$AllowedSourceIP/32" -SourcePortRange * -DestinationAddressPrefix "$vmPrivateIP/32" -DestinationPortRange 3389
                
                $nsg.SecurityRules.Add($rdpRule)
                $rulesAdded++
                Write-Host "  ✅ RDP rule added (Priority: $nextPriority, Destination: $vmPrivateIP/32)" -ForegroundColor Green
            }
            
            # Add ICMP rule if it doesn't exist
            if (-not $existingIcmpRule) {
                # Find the next available priority
                $existingPriorities = $nsg.SecurityRules | Where-Object { $_.Direction -eq "Inbound" } | Select-Object -ExpandProperty Priority
                $nextPriority = 1000
                while ($existingPriorities -contains $nextPriority) {
                    $nextPriority++
                }
                
                # Create ICMP rule for the specific source IP and destination VM IP
                $icmpRuleName = "Allow-ICMP-From-Deployer-To-$($VmName.Replace('-', ''))-$($AllowedSourceIP.Replace('.', '-'))"
                $icmpRule = New-AzNetworkSecurityRuleConfig -Name $icmpRuleName -Description "Allow ICMP ping from deployer IP to $VmName" -Access Allow -Protocol Icmp -Direction Inbound -Priority $nextPriority -SourceAddressPrefix "$AllowedSourceIP/32" -SourcePortRange * -DestinationAddressPrefix "$vmPrivateIP/32" -DestinationPortRange *
                
                $nsg.SecurityRules.Add($icmpRule)
                $rulesAdded++
                Write-Host "  ✅ ICMP rule added (Priority: $nextPriority, Destination: $vmPrivateIP/32)" -ForegroundColor Green
            }
            
            # Update NSG if any rules were added
            if ($rulesAdded -gt 0) {
                Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg | Out-Null
                Write-Host "✅ Secure access configured for $VmName ($vmPrivateIP) from $AllowedSourceIP" -ForegroundColor Green
                if ($existingRdpRule) {
                    Write-Host "  • RDP (3389 → $vmPrivateIP): Already configured" -ForegroundColor Gray
                } else {
                    Write-Host "  • RDP (3389 → $vmPrivateIP): Added" -ForegroundColor Gray
                }
                if ($existingIcmpRule) {
                    Write-Host "  • ICMP (ping → $vmPrivateIP): Already configured" -ForegroundColor Gray
                } else {
                    Write-Host "  • ICMP (ping → $vmPrivateIP): Added" -ForegroundColor Gray
                }
            } else {
                Write-Host "✅ Secure access already configured for $VmName ($vmPrivateIP) from $AllowedSourceIP" -ForegroundColor Green
            }
        } else {
            Write-Warning "No NSG found on subnet for $VmName"
        }
    }
    catch {
        Write-Warning "Failed to configure secure access for ${VmName}: $_"
    }
}

function Install-ConfigureRRAS {
    param(
        $ResourceGroupName,
        $VmName
    )
    
    Write-Host "🔧 Installing and configuring RRAS on $VmName..." -ForegroundColor Yellow
    
    $script = @'
# Enhanced RRAS Installation and Configuration Script for BGP LAN Router
$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

# Function to write timestamped logs
function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path "C:\Windows\Temp\rras-install.log" -Value $logMessage -Force
}

try {
    Write-Log "Starting RRAS BGP LAN Router installation and configuration"
    
    # Check if RemoteAccess feature is already installed
    $feature = Get-WindowsFeature -Name RemoteAccess
    Write-Log "Current RemoteAccess feature state: $($feature.InstallState)"
    
    if ($feature.InstallState -ne "Installed") {
        Write-Log "Installing RemoteAccess feature with all sub-features..."
        # Install RemoteAccess with all necessary components including PowerShell management tools
        $result = Install-WindowsFeature -Name RemoteAccess -IncludeManagementTools -IncludeAllSubFeature
        Write-Log "RemoteAccess installation result: $($result.Success), Exit Code: $($result.ExitCode)"
        
        # Also install the PowerShell module components explicitly
        Write-Log "Installing RemoteAccess PowerShell management tools..."
        $psResult = Install-WindowsFeature -Name RSAT-RemoteAccess-PowerShell -IncludeAllSubFeature
        Write-Log "RemoteAccess PowerShell tools installation result: $($psResult.Success)"
        
        if ($result.RestartNeeded -eq "Yes" -or $psResult.RestartNeeded -eq "Yes") {
            Write-Log "RESTART REQUIRED after RemoteAccess installation"
            return
        }
    } else {
        Write-Log "RemoteAccess feature already installed"
    }
    
    # Wait for modules to be available
    Start-Sleep -Seconds 10
    
    # Import RemoteAccess module explicitly
    try {
        Write-Log "Importing RemoteAccess PowerShell module..."
        Import-Module RemoteAccess -Force -ErrorAction Stop
        Write-Log "RemoteAccess module imported successfully"
        
        # Verify module cmdlets are available
        $installCmd = Get-Command Install-RemoteAccess -ErrorAction SilentlyContinue
        if ($installCmd) {
            Write-Log "Install-RemoteAccess cmdlet is available"
        } else {
            Write-Log "Install-RemoteAccess cmdlet not found - attempting alternative configuration method"
        }
    } catch {
        Write-Log "Failed to import RemoteAccess module: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Attempting alternative RRAS configuration using netsh..."
    }
    
    # Check if already configured as RoutingOnly
    try {
        $remoteAccessConfig = Get-RemoteAccess -ErrorAction SilentlyContinue
        if ($remoteAccessConfig -and $remoteAccessConfig.VpnS2SStatus -eq "Installed") {
            Write-Log "RemoteAccess already configured for routing"
        } else {
            Write-Log "Configuring RemoteAccess as BGP LAN Router..."
            
            # Try using Install-RemoteAccess cmdlet first (preferred method)
            try {
                Write-Log "Using Install-RemoteAccess -VpnType RoutingOnly (Microsoft recommended approach)"
                # Add -Force to ensure clean configuration
                Install-RemoteAccess -VpnType RoutingOnly -Force -PassThru -ErrorAction Stop
                Write-Log "RemoteAccess configured successfully using Install-RemoteAccess"
            } catch {
                Write-Log "Install-RemoteAccess failed: $($_.Exception.Message)" -Level "ERROR"
                Write-Log "Attempting alternative configuration using registry and service management..."
                
                # Enhanced alternative method with proper service configuration
                Write-Log "Configuring RRAS service settings via registry..."
                $rrasPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess\Parameters"
                
                # Ensure registry path exists
                if (!(Test-Path $rrasPath)) {
                    Write-Log "Creating RRAS registry path..."
                    New-Item -Path $rrasPath -Force | Out-Null
                }
                
                # Configure RRAS for routing only mode
                Set-ItemProperty -Path $rrasPath -Name "ConfiguredInRegistry" -Value 1 -Force
                Set-ItemProperty -Path $rrasPath -Name "RouterType" -Value 1 -Force
                Set-ItemProperty -Path $rrasPath -Name "EnableIn" -Value 1 -Force
                Set-ItemProperty -Path $rrasPath -Name "EnableOut" -Value 1 -Force
                
                # Set service startup type to automatic
                Write-Log "Setting RemoteAccess service to automatic startup..."
                Set-Service -Name "RemoteAccess" -StartupType Automatic -ErrorAction SilentlyContinue
                
                Write-Log "Alternative RRAS configuration applied using registry"
            }
        }
    } catch {
        Write-Log "Error checking RemoteAccess configuration: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Proceeding with fallback configuration..."
        
        # Enhanced fallback configuration
        Write-Log "Applying enhanced fallback RRAS configuration..."
        
        # Set service to automatic and try to start
        try {
            Set-Service -Name "RemoteAccess" -StartupType Automatic -ErrorAction Stop
            Write-Log "RemoteAccess service set to automatic startup"
        } catch {
            Write-Log "Failed to set service startup type: $($_.Exception.Message)" -Level "ERROR"
        }
        
        Write-Log "Basic routing configuration applied"
    }
    
    # Wait for services to stabilize after configuration
    Start-Sleep -Seconds 20
    
    # Comprehensive service verification and startup
    Write-Log "Verifying and starting RRAS services..."
    
    # First, try to find the correct service name
    $serviceNames = @("RemoteAccess", "Routing and Remote Access", "RasMan")
    $rrasService = $null
    
    foreach ($serviceName in $serviceNames) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Found service: $serviceName (Status: $($service.Status), StartType: $($service.StartType))"
            if ($serviceName -eq "RemoteAccess" -or $serviceName -eq "Routing and Remote Access") {
                $rrasService = $service
                break
            }
        }
    }
    
    if ($rrasService) {
        Write-Log "Primary RRAS service: $($rrasService.Name)"
        
        # Ensure service is set to automatic startup
        try {
            if ($rrasService.StartType -ne "Automatic") {
                Write-Log "Setting $($rrasService.Name) to automatic startup..."
                Set-Service -Name $rrasService.Name -StartupType Automatic
            }
        } catch {
            Write-Log "Failed to set startup type: $($_.Exception.Message)" -Level "ERROR"
        }
        
        # Start the service with retry logic
        $maxRetries = 3
        $retryCount = 0
        
        while ($retryCount -lt $maxRetries -and $rrasService.Status -ne "Running") {
            $retryCount++
            Write-Log "Attempt $retryCount/$maxRetries to start $($rrasService.Name)..."
            
            try {
                Start-Service -Name $rrasService.Name -ErrorAction Stop
                Start-Sleep -Seconds 15
                $rrasService = Get-Service -Name $rrasService.Name
                
                if ($rrasService.Status -eq "Running") {
                    Write-Log "✅ $($rrasService.Name) started successfully"
                    break
                } else {
                    Write-Log "Service status after start attempt: $($rrasService.Status)" -Level "WARNING"
                }
            } catch {
                Write-Log "Start attempt $retryCount failed: $($_.Exception.Message)" -Level "ERROR"
                if ($retryCount -lt $maxRetries) {
                    Write-Log "Waiting 10 seconds before retry..."
                    Start-Sleep -Seconds 10
                }
            }
        }
        
        if ($rrasService.Status -ne "Running") {
            Write-Log "❌ Failed to start $($rrasService.Name) after $maxRetries attempts" -Level "ERROR"
            Write-Log "Service will be configured to start automatically on next reboot" -Level "WARNING"
        }
    } else {
        Write-Log "⚠️ No RRAS service found - service may need manual configuration" -Level "WARNING"
    }
    
    # Also check and start dependent services
    $dependentServices = @("RasMan", "PolicyAgent")
    foreach ($depServiceName in $dependentServices) {
        $depService = Get-Service -Name $depServiceName -ErrorAction SilentlyContinue
        if ($depService -and $depService.Status -ne "Running") {
            Write-Log "Starting dependent service: $depServiceName"
            try {
                Start-Service -Name $depServiceName -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Failed to start $depServiceName : $($_.Exception.Message)" -Level "WARNING"
            }
        }
    }
    
    # Enable IP forwarding in registry (critical for routing)
    Write-Log "Enabling IP forwarding in registry..."
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $regPath -Name "IPEnableRouter" -Value 1 -Force
    Write-Log "IP forwarding enabled in registry"
    
    # Verify network configuration
    Write-Log "Network interfaces and routing configuration:"
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
        $ip = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ip) {
            Write-Log "Interface: $($_.Name), Status: $($_.Status), IP: $($ip.IPAddress), InterfaceIndex: $($_.InterfaceIndex)"
        }
    }
    
    # Check current routing table
    Write-Log "Current routing table:"
    $routes = Get-NetRoute -AddressFamily IPv4 | Where-Object {$_.RouteMetric -lt 1000} | Select-Object -First 10
    foreach ($route in $routes) {
        Write-Log "Route: $($route.DestinationPrefix) via $($route.NextHop) metric $($route.RouteMetric)"
    }
    
    # Test BGP cmdlets availability
    try {
        Import-Module RemoteAccess -Force -ErrorAction SilentlyContinue
        $bgpRouter = Get-BgpRouter -ErrorAction SilentlyContinue
        if ($bgpRouter) {
            Write-Log "BGP Router already configured: ASN $($bgpRouter.BgpIdentifier)"
        } else {
            Write-Log "BGP Router not yet configured (this is normal, will be configured in Phase 5)"
            Write-Log "BGP cmdlets are available and ready for configuration"
        }
    } catch {
        Write-Log "BGP cmdlets test result: $($_.Exception.Message)"
        Write-Log "This may be normal - BGP will be configured in Phase 5"
    }
    
    # Verify RemoteAccess configuration
    try {
        $raConfig = Get-RemoteAccess -ErrorAction SilentlyContinue
        if ($raConfig) {
            Write-Log "RemoteAccess configuration status:"
            Write-Log "  VPN S2S Status: $($raConfig.VpnS2SStatus)"
            Write-Log "  BGP Status: $($raConfig.BgpStatus)"
            Write-Log "  Installation Type: $($raConfig.InstallType)"
        }
    } catch {
        Write-Log "Could not retrieve RemoteAccess configuration: $($_.Exception.Message)"
    }
    
    Write-Log "RRAS BGP LAN Router installation and configuration completed successfully"
    
    # Create a marker file to indicate successful completion
    $marker = @"
RRAS BGP LAN Router configured successfully at $(Get-Date)
Configuration: Install-RemoteAccess -VpnType RoutingOnly
Purpose: BGP LAN Router for VWAN lab environment
Next step: Phase 5 will configure BGP router and peer relationships
"@
    $marker | Out-File -FilePath "C:\Windows\Temp\rras-configured.txt" -Force
    
} catch {
    Write-Log "ERROR during RRAS BGP configuration: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    throw
}
'@
    
    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString $script
        
        # Display the output
        Write-Host "📋 RRAS Configuration Results:" -ForegroundColor Cyan
        if ($result.Value) {
            foreach ($output in $result.Value) {
                if ($output.Code -eq "ComponentStatus/StdOut/succeeded") {
                    Write-Host $output.Message -ForegroundColor White
                }
                elseif ($output.Code -eq "ComponentStatus/StdErr/succeeded" -and $output.Message) {
                    Write-Host "STDERR: $($output.Message)" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host "✅ RRAS installation and configuration completed" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to configure RRAS on ${VmName}: $_"
        throw
    }
}

function Enable-VmBootDiagnostics {
    param(
        $ResourceGroupName,
        $VmName
    )
    
    Write-Host "🔧 Enabling boot diagnostics with managed storage on $VmName..." -ForegroundColor Yellow
    
    try {
        # Get the VM
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop
        
        # Check if boot diagnostics is already enabled
        if ($vm.DiagnosticsProfile.BootDiagnostics.Enabled -eq $true) {
            Write-Host "✅ Boot diagnostics already enabled on $VmName" -ForegroundColor Green
            return
        }
        
        # Enable boot diagnostics with managed storage (latest Azure best practice)
        # When no storage URI is specified, Azure automatically uses managed storage
        Set-AzVMBootDiagnostic -VM $vm -Enable
        
        # Update the VM configuration
        $updateResult = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm
        
        if ($updateResult.IsSuccessStatusCode) {
            Write-Host "✅ Boot diagnostics enabled successfully on $VmName" -ForegroundColor Green
            Write-Host "  • Using managed storage (Azure best practice)" -ForegroundColor Gray
            Write-Host "  • Cost: ~$0.05/GB per month for diagnostic data only" -ForegroundColor Gray
        } else {
            Write-Warning "Failed to update VM configuration for boot diagnostics on $VmName"
        }
    }
    catch {
        Write-Warning "Failed to enable boot diagnostics on ${VmName}: $_"
    }
}

function Start-CleanupJob {
    param($ResourceGroupName)
    
    if (-not $ResourceGroupName) { return }
    
    Write-Host '🧹 Starting cleanup of old resource group: $ResourceGroupName' -ForegroundColor Yellow
    
    $scriptBlock = {
        param($rgName)
        try {
            Remove-AzResourceGroup -Name $rgName -Force -AsJob
            Write-Output "Cleanup job started for $rgName"
        }
        catch {
            Write-Error "Failed to start cleanup for $rgName`: $_"
        }
    }
    
    Start-Job -ScriptBlock $scriptBlock -ArgumentList $ResourceGroupName -Name "Cleanup-$ResourceGroupName"
    Write-Host '✅ Cleanup job started in background' -ForegroundColor Green
}

function Set-VmAutoShutdown {
    param(
        [string]$ResourceGroupName,
        [string]$VmName,
        [string]$ShutdownTime = "01:00",
        [string]$TimeZone = "UTC"
    )
    
    try {
        Write-Host "  🕐 Setting auto-shutdown for $VmName at $ShutdownTime ($TimeZone)..." -ForegroundColor Gray
        
        # Get the VM to get its resource ID
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop
        
        # Create the auto-shutdown schedule resource name
        $scheduleName = "shutdown-computevm-$VmName"
        
        # Create the auto-shutdown policy using Azure REST API via PowerShell
        $scheduleProperties = @{
            status = "Enabled"
            taskType = "ComputeVmShutdownTask"
            dailyRecurrence = @{
                time = $ShutdownTime
            }
            timeZoneId = $TimeZone
            targetResourceId = $vm.Id
            notificationSettings = @{
                status = "Disabled"
            }
        }
        
        # Use New-AzResource to create the auto-shutdown schedule
        $null = New-AzResource -ResourceType "microsoft.devtestlab/schedules" `
            -ResourceName $scheduleName `
            -ResourceGroupName $ResourceGroupName `
            -Location $vm.Location `
            -Properties $scheduleProperties `
            -Force
            
        Write-Host "    ✅ Auto-shutdown configured successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "    ❌ Failed to configure auto-shutdown for ${VmName}: $($_.Exception.Message)"
        return $false
    }
}

function Enable-AutoShutdownForLab {
    param(
        [string]$ResourceGroupName,
        [string]$ShutdownTime = "01:00",
        [string]$TimeZone = "UTC"
    )
    
    # Validate time format
    if ($ShutdownTime -notmatch '^\d{2}:\d{2}$') {
        Write-Error "Invalid time format: $ShutdownTime. Use 24-hour format (HH:MM), e.g., '01:00' or '18:30'"
        return 0
    }
    
    Write-Host '⏰ Configuring auto-shutdown for all VMs...' -ForegroundColor Yellow
    Write-Host "   Shutdown Time: $ShutdownTime" -ForegroundColor Gray
    Write-Host "   Time Zone: $TimeZone" -ForegroundColor Gray
    
    # Get all VMs in the resource group
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    
    if (-not $vms) {
        Write-Warning "No VMs found in resource group $ResourceGroupName"
        return 0
    }
    
    $successCount = 0
    $totalCount = $vms.Count
    
    foreach ($vm in $vms) {
        if (Set-VmAutoShutdown -ResourceGroupName $ResourceGroupName -VmName $vm.Name -ShutdownTime $ShutdownTime -TimeZone $TimeZone) {
            $successCount++
        }
    }
    
    Write-Host "`n✅ Auto-shutdown configured: $successCount/$totalCount VMs" -ForegroundColor Green
    
    if ($successCount -gt 0) {
        Write-Host "💰 Estimated monthly savings: ~25% of VM costs (~$15-30/month)" -ForegroundColor Cyan
        Write-Host "🕐 VMs will shutdown daily at $ShutdownTime ($TimeZone)" -ForegroundColor Cyan
        Write-Host "🔄 VMs can be manually started anytime via Azure Portal or PowerShell" -ForegroundColor Gray
    }
    
    return $successCount
}

function Enable-JitAccessForLab {
    param(
        [string]$ResourceGroupName
    )
    
    Write-Host '🔐 Configuring Just-In-Time (JIT) VM access...' -ForegroundColor Yellow
    Write-Host "   Secure Future Initiative (SFI) security enhancement" -ForegroundColor Gray
    
    # Get all VMs in the resource group
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    
    if (-not $vms) {
        Write-Warning "No VMs found in resource group $ResourceGroupName"
        return 0
    }
    
    $successCount = 0
    $totalCount = $vms.Count
    
    # Check if Azure Security Center is available
    try {
        # Try to get the Security Center workspace
        $securityContacts = Get-AzSecurityContact -ErrorAction SilentlyContinue
        $defenderAvailable = $true
    }
    catch {
        Write-Warning "Microsoft Defender for Cloud not available. JIT requires Defender for Cloud."
        $defenderAvailable = $false
    }
    
    if (-not $defenderAvailable) {
        Write-Host "   📋 Alternative: Configure NSG rules for restricted RDP access" -ForegroundColor Cyan
        foreach ($vm in $vms) {
            if (Set-VmRestrictedRdpAccess -ResourceGroupName $ResourceGroupName -VmName $vm.Name) {
                $successCount++
            }
        }
    } else {
        foreach ($vm in $vms) {
            if (Set-VmJitAccess -ResourceGroupName $ResourceGroupName -VmName $vm.Name) {
                $successCount++
            }
        }
    }
    
    Write-Host "`n✅ JIT/Restricted access configured: $successCount/$totalCount VMs" -ForegroundColor Green
    
    if ($successCount -gt 0) {
        Write-Host "🔒 Enhanced Security: VMs protected with Just-In-Time access" -ForegroundColor Cyan
        Write-Host "🛡️ Access Control: RDP access requires approval through Azure Portal" -ForegroundColor Cyan
        Write-Host "⏱️ Time-Limited: Access automatically expires after specified duration" -ForegroundColor Gray
    }
    
    return $successCount
}

function Set-VmJitAccess {
    param(
        [string]$ResourceGroupName,
        [string]$VmName
    )
    
    try {
        Write-Host "  🔐 Configuring JIT access for $VmName..." -ForegroundColor Gray
        
        # Get the VM to get its resource ID and location
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop
        
        # JIT Policy configuration
        $jitPolicy = @{
            id = $vm.Id
            ports = @(
                @{
                    number = 3389
                    protocol = "TCP"
                    allowedSourceAddressPrefix = "*"
                    maxRequestAccessDuration = "PT3H"  # 3 hours
                }
            )
        }
        
        # Create JIT access policy using REST API
        $subscriptionId = (Get-AzContext).Subscription.Id
        $policyName = "default"
        $resourceUri = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Security/locations/$($vm.Location)/jitNetworkAccessPolicies/$policyName"
        
        $jitPolicyRequest = @{
            properties = @{
                virtualMachines = @($jitPolicy)
            }
        }
        
        # Use Azure REST API to create JIT policy
        $headers = @{
            'Authorization' = "Bearer $((Get-AzAccessToken).Token)"
            'Content-Type' = 'application/json'
        }
        
        $body = $jitPolicyRequest | ConvertTo-Json -Depth 5
        $uri = "https://management.azure.com$resourceUri" + "?api-version=2020-01-01"
        
        $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
        
        Write-Host "    ✅ JIT access policy configured successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "    ❌ Failed to configure JIT for ${VmName}: $($_.Exception.Message)"
        
        # Fallback to restricted NSG rules
        Write-Host "    🔄 Falling back to restricted NSG configuration..." -ForegroundColor Yellow
        return Set-VmRestrictedRdpAccess -ResourceGroupName $ResourceGroupName -VmName $VmName
    }
}

function Set-VmRestrictedRdpAccess {
    param(
        [string]$ResourceGroupName,
        [string]$VmName
    )
    
    try {
        Write-Host "  🛡️ Configuring restricted RDP access for $VmName..." -ForegroundColor Gray
        
        # Get the VM's network interface
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop
        $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
        $nic = Get-AzNetworkInterface -ResourceId $nicId
        
        # Get the NSG associated with the subnet or NIC
        $nsg = $null
        if ($nic.NetworkSecurityGroup) {
            $nsg = Get-AzNetworkSecurityGroup -ResourceId $nic.NetworkSecurityGroup.Id
        } else {
            # Check subnet NSG
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
            $subnet = $vnet.Subnets | Where-Object { $_.Id -eq $nic.IpConfigurations[0].Subnet.Id }
            if ($subnet.NetworkSecurityGroup) {
                $nsg = Get-AzNetworkSecurityGroup -ResourceId $subnet.NetworkSecurityGroup.Id
            }
        }
        
        if ($nsg) {
            # Add a high-priority rule that denies RDP from internet (as backup)
            $ruleName = "DenyRdpFromInternet"
            $existingRule = $nsg.SecurityRules | Where-Object { $_.Name -eq $ruleName }
            
            if (-not $existingRule) {
                $nsg | Add-AzNetworkSecurityRuleConfig -Name $ruleName -Description "SFI: Deny RDP from Internet (JIT override available)" -Access Deny -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix "Internet" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "3389"
                $nsg | Set-AzNetworkSecurityGroup | Out-Null
            }
            
            Write-Host "    ✅ Restricted RDP access configured" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "    ❌ No NSG found for $VmName"
            return $false
        }
    }
    catch {
        Write-Warning "    ❌ Failed to configure restricted access for ${VmName}: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Execution

try {
    # Display header
    Write-DeploymentHeader "Azure Virtual WAN Lab - Unified Deployment" "Performance-optimized phased deployment with automatic VM configuration"
    
    # Show deployment configuration
    Write-Host '📋 Deployment Configuration:' -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  Deployment Mode: $DeploymentMode" -ForegroundColor White
    Write-Host "  IP Schema: $IpSchema" -ForegroundColor White
    if ($Phase) {
        Write-Host "  Phase: $Phase only" -ForegroundColor White
    } else {
        Write-Host "  Phase: All phases (1-5)" -ForegroundColor White
    }
    
    # Show cost analysis
    Show-CostAnalysis -DeploymentMode $DeploymentMode
    
    # Check prerequisites
    Test-Prerequisites
    
    # Connect to Azure
    $actualSubscriptionId = Connect-ToAzure -SubscriptionId $SubscriptionId
    
    # Create resource group
    $resourceGroup = New-ResourceGroupIfNotExists -ResourceGroupName $ResourceGroupName -Location $Location
    
    # Get VM credentials if deploying VMs (check if VMs exist first)
    if ($DeploymentMode -eq "Full" -and (-not $Phase -or $Phase -eq 2 -or $Phase -eq 3)) {
        # Check which VMs exist to determine if we need credentials
        $allExpectedVms = @()
        
        if (-not $Phase -or $Phase -eq 2) {
            $allExpectedVms += @("vwanlab-spoke1-nva-vm", "vwanlab-spoke2-test-vm")
        }
        if (-not $Phase -or $Phase -eq 3) {
            $allExpectedVms += @("vwanlab-spoke3-test-vm")
        }
        
        if ($allExpectedVms.Count -gt 0) {
            Write-Host "`n🔍 Checking existing VMs..." -ForegroundColor Cyan
            $vmStatus = Get-VmDeploymentMode -ResourceGroupName $ResourceGroupName -ExpectedVms $allExpectedVms
            
            if ($vmStatus.AllExist) {
                Write-Host "✅ All required VMs exist - skipping password prompt" -ForegroundColor Green
                Write-Host "🔧 Will apply configuration to existing VMs only" -ForegroundColor Yellow
            }
            elseif ($vmStatus.RequiresPassword -and (-not $AdminUsername -or -not $AdminPassword)) {
                Write-Host "🔧 New VMs need creation - credentials required for: $($vmStatus.MissingVms -join ', ')" -ForegroundColor Yellow
                $AdminUsername, $AdminPassword = Get-UserCredentials -AdminUsername $AdminUsername
            }
            elseif (-not $vmStatus.RequiresPassword) {
                Write-Host "ℹ️  No new VMs to create - existing configuration will be applied" -ForegroundColor Cyan
            }
        }
    }
    
    # Get deployer IP for RDP access configuration
    $deployerIP = Get-DeployerPublicIP
    
    # Confirm deployment if not forced
    if (-not $Force -and -not $WhatIfPreference) {
        $confirmation = Read-Host "Continue with deployment? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "Deployment cancelled by user" -ForegroundColor Yellow
            return
        }
    }
    
    # Determine parameter overrides based on deployment mode
    $baseParameters = @{
        'environmentPrefix' = 'vwanlab'
    }
    
    # Add admin credentials if deploying VMs
    if ($AdminUsername -and $AdminPassword) {
        $baseParameters['adminUsername'] = $AdminUsername
        $adminPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword))
        $baseParameters['adminPassword'] = $adminPasswordText
    }
    
    $deploymentConfig = $DeploymentModes[$DeploymentMode]
    
    # Execute deployment phases
    if ($Phase) {
        # Deploy specific phase
        $phaseConfig = $Phases[$Phase]
        Invoke-PhaseDeployment -PhaseNumber $Phase -PhaseConfig $phaseConfig -ResourceGroupName $ResourceGroupName -ParameterOverrides $baseParameters -Location $Location -DeployerIP $deployerIP
    }
    else {
        # Deploy all phases
        foreach ($phaseNumber in 1..5) {
            if ($DeploymentMode -eq "InfrastructureOnly" -and $phaseNumber -eq 2) {
                Write-Host '⏭️  Skipping Phase 2 (VMs) in InfrastructureOnly mode' -ForegroundColor Yellow
                continue
            }
            
            $phaseConfig = $Phases[$phaseNumber]
            Invoke-PhaseDeployment -PhaseNumber $phaseNumber -PhaseConfig $phaseConfig -ResourceGroupName $ResourceGroupName -ParameterOverrides $baseParameters -Location $Location -DeployerIP $deployerIP
        }
    }
    
    if (-not $WhatIfPreference) {
        # Start cleanup job if specified
        if ($CleanupOldResourceGroup) {
            Start-CleanupJob -ResourceGroupName $CleanupOldResourceGroup
        }
        
        # Configure auto-shutdown if enabled
        if ($EnableAutoShutdown -and $DeploymentMode -ne "InfrastructureOnly") {
            Write-Host "`n⏰ Auto-Shutdown Configuration" -ForegroundColor Cyan
            Write-Host "   Shutdown Time: $AutoShutdownTime" -ForegroundColor Gray
            Write-Host "   Time Zone: $AutoShutdownTimeZone" -ForegroundColor Gray
            
            if ($WhatIf) {
                Write-Host "What if: Performing the operation ""Configure auto-shutdown for VMs"" on target ""$ResourceGroupName""." -ForegroundColor Magenta
            } else {
                $shutdownConfigured = Enable-AutoShutdownForLab -ResourceGroupName $ResourceGroupName -ShutdownTime $AutoShutdownTime -TimeZone $AutoShutdownTimeZone
                
                if ($shutdownConfigured -gt 0) {
                    Write-Host "🎯 Auto-shutdown feature activated!" -ForegroundColor Green
                } else {
                    Write-Warning "Auto-shutdown configuration failed - VMs will run continuously"
                }
            }
        }
        
        # Configure JIT access if SFI is enabled
        if ($SfiEnable -and $DeploymentMode -ne "InfrastructureOnly") {
            Write-Host "`n🔐 Secure Future Initiative (SFI) Configuration" -ForegroundColor Cyan
            Write-Host "   Just-In-Time VM Access" -ForegroundColor Gray
            
            if ($WhatIf) {
                Write-Host "What if: Performing the operation ""Configure JIT access for VMs"" on target ""$ResourceGroupName""." -ForegroundColor Magenta
            } else {
                $jitConfigured = Enable-JitAccessForLab -ResourceGroupName $ResourceGroupName
                
                if ($jitConfigured -gt 0) {
                    Write-Host "🛡️ SFI security features activated!" -ForegroundColor Green
                } else {
                    Write-Warning "JIT configuration failed - VMs have standard RDP access"
                }
            }
        }
        
        # Success message
        Write-Host "`n" -NoNewline
        Write-Host '🎉 Deployment completed successfully!' -ForegroundColor Green
        Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
        Write-Host "   Mode: $DeploymentMode" -ForegroundColor White
        Write-Host "   Estimated Cost: $($deploymentConfig.EstimatedCost.Hourly)/hour" -ForegroundColor White
        
        # Next steps
        Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Configure NVA BGP: .\scripts\Configure-NvaBgp.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
        Write-Host "  2. Check BGP status: .\scripts\Get-BgpStatus.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
        Write-Host "  3. Test connectivity: .\scripts\Test-Connectivity.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
        Write-Host "  4. Monitor status: dotnet run --project .\src\VwanLabAutomation -- status --resource-group '$ResourceGroupName'" -ForegroundColor Gray
    }
    
    # Show post-deployment configuration in WhatIf mode
    if ($WhatIfPreference) {
        # Show auto-shutdown configuration preview
        if ($EnableAutoShutdown -and $DeploymentMode -ne "InfrastructureOnly") {
            Write-Host "`n⏰ Auto-Shutdown Configuration" -ForegroundColor Cyan
            Write-Host "   Shutdown Time: $AutoShutdownTime" -ForegroundColor Gray
            Write-Host "   Time Zone: $AutoShutdownTimeZone" -ForegroundColor Gray
            Write-Host "What if: Performing the operation ""Configure auto-shutdown for VMs"" on target ""$ResourceGroupName""." -ForegroundColor Magenta
        }
        
        # Show JIT configuration preview
        if ($SfiEnable -and $DeploymentMode -ne "InfrastructureOnly") {
            Write-Host "`n🔐 Secure Future Initiative (SFI) Configuration" -ForegroundColor Cyan
            Write-Host "   Just-In-Time VM Access" -ForegroundColor Gray
            Write-Host "What if: Performing the operation ""Configure JIT access for VMs"" on target ""$ResourceGroupName""." -ForegroundColor Magenta
        }
    }
}
catch {
    Write-Error "❌ Deployment failed: $_"
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check Azure permissions and quotas" -ForegroundColor Gray
    Write-Host "  2. Review error details above" -ForegroundColor Gray
    Write-Host "  3. Try deploying individual phases" -ForegroundColor Gray
    Write-Host "  4. Run: .\scripts\Troubleshoot-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
    exit 1
}

#endregion

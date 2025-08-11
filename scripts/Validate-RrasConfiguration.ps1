#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute

<#
.SYNOPSIS
    Validates RRAS BGP configuration on NVA VMs

.DESCRIPTION
    This script validates that RRAS is properly configured for BGP routing on NVA VMs.
    It checks the RemoteAccess configuration, service status, and BGP readiness.

.PARAMETER ResourceGroupName
    Name of the resource group containing the VMs

.PARAMETER VmName
    Specific VM name to validate (optional - validates all NVA VMs if not specified)

.EXAMPLE
    .\Validate-RrasConfiguration.ps1 -ResourceGroupName "rg-vwanlab-demo"

.EXAMPLE
    .\Validate-RrasConfiguration.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-spoke1-nva-vm"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VmName
)

function Write-StatusHeader {
    param($Title)
    Write-Host "`n" -NoNewline
    Write-Host "═" * 60 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "═" * 60 -ForegroundColor Cyan
}

function Test-RrasConfiguration {
    param($ResourceGroupName, $VmName)
    
    Write-Host "`n🔧 Validating RRAS configuration on $VmName..." -ForegroundColor Yellow
    
    $validationScript = @'
$ErrorActionPreference = "Continue"

function Write-ValidationResult {
    param($Test, $Result, $Details = $null)
    if ($Result) {
        Write-Host "✅ $Test" -ForegroundColor Green
        if ($Details) { Write-Host "   $Details" -ForegroundColor Gray }
    } else {
        Write-Host "❌ $Test" -ForegroundColor Red
        if ($Details) { Write-Host "   $Details" -ForegroundColor Yellow }
    }
}

Write-Host "🔍 RRAS Configuration Validation Report" -ForegroundColor Cyan
Write-Host "═" * 50 -ForegroundColor DarkGray

# Test 1: RemoteAccess Feature Installation
try {
    $feature = Get-WindowsFeature -Name RemoteAccess
    Write-ValidationResult "RemoteAccess Feature Installed" ($feature.InstallState -eq "Installed") "State: $($feature.InstallState)"
} catch {
    Write-ValidationResult "RemoteAccess Feature Check" $false "Error: $($_.Exception.Message)"
}

# Test 2: RemoteAccess PowerShell Module
try {
    Import-Module RemoteAccess -Force -ErrorAction Stop
    $moduleImported = $true
    Write-ValidationResult "RemoteAccess Module Import" $true "Module imported successfully"
} catch {
    $moduleImported = $false
    Write-ValidationResult "RemoteAccess Module Import" $false "Error: $($_.Exception.Message)"
}

# Test 3: Install-RemoteAccess Cmdlet Availability
if ($moduleImported) {
    try {
        $installCmd = Get-Command Install-RemoteAccess -ErrorAction Stop
        Write-ValidationResult "Install-RemoteAccess Cmdlet Available" $true "Cmdlet found and ready"
    } catch {
        Write-ValidationResult "Install-RemoteAccess Cmdlet Available" $false "Cmdlet not found: $($_.Exception.Message)"
    }
}

# Test 4: RemoteAccess Configuration Status
try {
    $raConfig = Get-RemoteAccess -ErrorAction SilentlyContinue
    if ($raConfig) {
        Write-ValidationResult "RemoteAccess Configured" $true "VPN S2S Status: $($raConfig.VpnS2SStatus), BGP Status: $($raConfig.BgpStatus)"
        
        # Additional details
        Write-Host "`n📋 RemoteAccess Configuration Details:" -ForegroundColor Cyan
        Write-Host "   Installation Type: $($raConfig.InstallType)" -ForegroundColor Gray
        Write-Host "   VPN S2S Status: $($raConfig.VpnS2SStatus)" -ForegroundColor Gray
        Write-Host "   BGP Status: $($raConfig.BgpStatus)" -ForegroundColor Gray
        if ($raConfig.TenantId) {
            Write-Host "   Tenant ID: $($raConfig.TenantId)" -ForegroundColor Gray
        }
    } else {
        Write-ValidationResult "RemoteAccess Configured" $false "No RemoteAccess configuration found"
    }
} catch {
    Write-ValidationResult "RemoteAccess Configuration Check" $false "Error: $($_.Exception.Message)"
}

# Test 5: Service Status
$services = @("RemoteAccess", "Routing and Remote Access")
foreach ($serviceName in $services) {
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-ValidationResult "$serviceName Service" ($service.Status -eq "Running") "Status: $($service.Status), StartType: $($service.StartType)"
            break  # Found the service, no need to check others
        }
    } catch {
        # Continue to next service name
    }
}

# Test 6: IP Forwarding Registry Setting
try {
    $ipForwarding = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -ErrorAction SilentlyContinue
    Write-ValidationResult "IP Forwarding Enabled" ($ipForwarding.IPEnableRouter -eq 1) "Registry Value: $($ipForwarding.IPEnableRouter)"
} catch {
    Write-ValidationResult "IP Forwarding Check" $false "Error: $($_.Exception.Message)"
}

# Test 7: Network Interfaces
Write-Host "`n🌐 Network Interface Status:" -ForegroundColor Cyan
try {
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($adapter in $adapters) {
        $ip = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ip) {
            Write-Host "   ✅ $($adapter.Name): $($ip.IPAddress) (Index: $($adapter.InterfaceIndex))" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ❌ Error checking network interfaces: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 8: BGP Cmdlets Availability
Write-Host "`n🔄 BGP Functionality Test:" -ForegroundColor Cyan
try {
    $bgpCmdlets = @("Get-BgpRouter", "Add-BgpRouter", "Add-BgpPeer")
    foreach ($cmdlet in $bgpCmdlets) {
        try {
            $cmd = Get-Command $cmdlet -ErrorAction Stop
            Write-Host "   ✅ $cmdlet available" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ $cmdlet not available" -ForegroundColor Red
        }
    }
    
    # Test BGP router status (if configured)
    try {
        $bgpRouter = Get-BgpRouter -ErrorAction SilentlyContinue
        if ($bgpRouter) {
            Write-Host "   ✅ BGP Router configured: ASN $($bgpRouter.BgpIdentifier)" -ForegroundColor Green
        } else {
            Write-Host "   ℹ️  BGP Router not yet configured (normal for Phase 2)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ℹ️  BGP Router check: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ BGP functionality test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 9: Check marker files
Write-Host "`n📄 Configuration Markers:" -ForegroundColor Cyan
$markerFiles = @(
    "C:\Windows\Temp\rras-configured.txt",
    "C:\Windows\Temp\rras-install.log"
)

foreach ($markerFile in $markerFiles) {
    if (Test-Path $markerFile) {
        Write-Host "   ✅ Found: $markerFile" -ForegroundColor Green
        if ($markerFile -like "*.txt") {
            $content = Get-Content $markerFile -Raw -ErrorAction SilentlyContinue
            if ($content) {
                Write-Host "      Content preview: $($content.Substring(0, [Math]::Min(100, $content.Length)))" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   ❌ Missing: $markerFile" -ForegroundColor Red
    }
}

Write-Host "`n═" * 50 -ForegroundColor DarkGray
Write-Host "🏁 RRAS Validation Complete" -ForegroundColor Cyan
'@

    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString $validationScript
        
        if ($result.Value) {
            foreach ($output in $result.Value) {
                if ($output.Code -eq "ComponentStatus/StdOut/succeeded") {
                    Write-Host $output.Message
                }
                elseif ($output.Code -eq "ComponentStatus/StdErr/succeeded" -and $output.Message) {
                    Write-Host "STDERR: $($output.Message)" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        Write-Error "Failed to validate RRAS configuration on ${VmName}: $_"
    }
}

# Main execution
try {
    Write-StatusHeader "RRAS Configuration Validation"
    
    # Connect to Azure if not already connected
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "🔐 Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    }
    
    Write-Host "📋 Resource Group: $ResourceGroupName" -ForegroundColor Cyan
    
    if ($VmName) {
        # Validate specific VM
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue
        if ($vm) {
            Test-RrasConfiguration -ResourceGroupName $ResourceGroupName -VmName $VmName
        } else {
            Write-Error "VM '$VmName' not found in resource group '$ResourceGroupName'"
        }
    }
    else {
        # Find and validate all NVA VMs
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*nva*" }
        
        if ($vms) {
            Write-Host "Found $($vms.Count) NVA VM(s) to validate:" -ForegroundColor Green
            foreach ($vm in $vms) {
                Write-Host "  • $($vm.Name)" -ForegroundColor White
            }
            
            foreach ($vm in $vms) {
                Test-RrasConfiguration -ResourceGroupName $ResourceGroupName -VmName $vm.Name
            }
        }
        else {
            Write-Warning "No NVA VMs found in resource group '$ResourceGroupName'"
            Write-Host "🔍 Available VMs:" -ForegroundColor Yellow
            $allVms = Get-AzVM -ResourceGroupName $ResourceGroupName
            foreach ($vm in $allVms) {
                Write-Host "  • $($vm.Name)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`n✅ Validation complete!" -ForegroundColor Green
}
catch {
    Write-Error "Validation failed: $_"
    exit 1
}

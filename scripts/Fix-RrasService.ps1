#Requires -Version 7.0
#Requires -Modules Az.Compute

<#
.SYNOPSIS
    Fixes RRAS service startup issues on NVA VMs in Azure VWAN lab environment.

.DESCRIPTION
    This script diagnoses and fixes common RRAS (Routing and Remote Access Service) startup issues
    that can occur during Azure VWAN lab deployment. It provides comprehensive troubleshooting
    and repair capabilities for RRAS configuration problems.

.PARAMETER ResourceGroupName
    Name of the Azure resource group containing the VMs.

.PARAMETER VmName
    Name of the specific VM to fix. If not specified, all NVA VMs will be processed.

.PARAMETER Force
    Force reinstallation of RRAS even if it appears to be working.

.EXAMPLE
    .\Fix-RrasService.ps1 -ResourceGroupName "rg-vwanlab-demo" 

.EXAMPLE
    .\Fix-RrasService.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-spoke1-nva-vm"

.NOTES
    Author: Azure VWAN Lab Team
    Version: 1.0
    Requires: Azure PowerShell, VM Contributor permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VmName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param($Title)
    Write-Host "`n" -NoNewline
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host ""
}

function Repair-RrasService {
    param(
        $ResourceGroupName,
        $VmName
    )
    
    Write-Host "🔧 Diagnosing and repairing RRAS on $VmName..." -ForegroundColor Yellow
    
    $repairScript = @'
# RRAS Service Repair and Diagnostic Script
$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path "C:\Windows\Temp\rras-repair.log" -Value $logMessage -Force
}

try {
    Write-Log "=== RRAS SERVICE REPAIR AND DIAGNOSTIC STARTED ==="
    
    # 1. Check current service status
    Write-Log "--- Step 1: Service Status Check ---"
    $services = @("RemoteAccess", "Routing and Remote Access", "RasMan", "PolicyAgent")
    foreach ($svcName in $services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Log "Service $svcName : Status=$($svc.Status), StartType=$($svc.StartType)"
        } else {
            Write-Log "Service $svcName : NOT FOUND"
        }
    }
    
    # 2. Check Windows Features
    Write-Log "--- Step 2: Windows Features Check ---"
    $features = @("RemoteAccess", "Routing", "RSAT-RemoteAccess-PowerShell")
    foreach ($featureName in $features) {
        $feature = Get-WindowsFeature -Name $featureName -ErrorAction SilentlyContinue
        if ($feature) {
            Write-Log "Feature $featureName : State=$($feature.InstallState)"
        }
    }
    
    # 3. Check Registry Configuration
    Write-Log "--- Step 3: Registry Configuration Check ---"
    $regPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess\Parameters",
        "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    )
    
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            Write-Log "Registry path exists: $regPath"
            $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if ($regPath -like "*RemoteAccess*") {
                Write-Log "  ConfiguredInRegistry: $($items.ConfiguredInRegistry)"
                Write-Log "  RouterType: $($items.RouterType)"
            } elseif ($regPath -like "*Tcpip*") {
                Write-Log "  IPEnableRouter: $($items.IPEnableRouter)"
            }
        } else {
            Write-Log "Registry path missing: $regPath"
        }
    }
    
    # 4. Stop all RRAS-related services
    Write-Log "--- Step 4: Stopping Services ---"
    $servicesToStop = @("RemoteAccess", "Routing and Remote Access")
    foreach ($svcName in $servicesToStop) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            Write-Log "Stopping service: $svcName"
            try {
                Stop-Service -Name $svcName -Force -ErrorAction Stop
                Write-Log "Service $svcName stopped successfully"
            } catch {
                Write-Log "Failed to stop $svcName : $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    # 5. Clean up any corrupted configuration
    Write-Log "--- Step 5: Configuration Cleanup ---"
    try {
        # Remove existing RemoteAccess configuration if corrupted
        $raConfig = Get-RemoteAccess -ErrorAction SilentlyContinue
        if ($raConfig) {
            Write-Log "Existing RemoteAccess configuration found, attempting cleanup..."
            try {
                Uninstall-RemoteAccess -Force -ErrorAction SilentlyContinue
                Write-Log "Previous RemoteAccess configuration removed"
                Start-Sleep -Seconds 10
            } catch {
                Write-Log "Uninstall-RemoteAccess failed (this may be normal): $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Log "RemoteAccess configuration check failed: $($_.Exception.Message)"
    }
    
    # 6. Ensure required Windows features are installed
    Write-Log "--- Step 6: Installing Required Features ---"
    $requiredFeatures = @("RemoteAccess", "Routing", "RSAT-RemoteAccess-PowerShell")
    foreach ($featureName in $requiredFeatures) {
        $feature = Get-WindowsFeature -Name $featureName
        if ($feature.InstallState -ne "Installed") {
            Write-Log "Installing feature: $featureName"
            try {
                $result = Install-WindowsFeature -Name $featureName -IncludeManagementTools
                Write-Log "Feature $featureName installation: Success=$($result.Success)"
                if ($result.RestartNeeded -eq "Yes") {
                    Write-Log "RESTART REQUIRED after installing $featureName"
                }
            } catch {
                Write-Log "Failed to install $featureName : $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-Log "Feature $featureName already installed"
        }
    }
    
    # 7. Wait and import modules
    Start-Sleep -Seconds 15
    Write-Log "--- Step 7: Module Import ---"
    try {
        Import-Module RemoteAccess -Force
        Write-Log "RemoteAccess module imported successfully"
    } catch {
        Write-Log "Failed to import RemoteAccess module: $($_.Exception.Message)" -Level "ERROR"
    }
    
    # 8. Configure RemoteAccess with enhanced error handling
    Write-Log "--- Step 8: RemoteAccess Configuration ---"
    try {
        Write-Log "Configuring RemoteAccess for routing only..."
        
        # Method 1: Try Install-RemoteAccess
        try {
            Install-RemoteAccess -VpnType RoutingOnly -Force -ErrorAction Stop
            Write-Log "✅ RemoteAccess configured successfully using Install-RemoteAccess"
        } catch {
            Write-Log "Install-RemoteAccess failed: $($_.Exception.Message)" -Level "ERROR"
            
            # Method 2: Manual registry configuration
            Write-Log "Attempting manual registry configuration..."
            $rrasRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess\Parameters"
            
            if (!(Test-Path $rrasRegPath)) {
                New-Item -Path $rrasRegPath -Force | Out-Null
                Write-Log "Created registry path: $rrasRegPath"
            }
            
            # Set RRAS configuration values
            Set-ItemProperty -Path $rrasRegPath -Name "ConfiguredInRegistry" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $rrasRegPath -Name "RouterType" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $rrasRegPath -Name "EnableIn" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $rrasRegPath -Name "EnableOut" -Value 1 -Type DWord -Force
            Write-Log "Registry configuration applied"
            
            # Enable IP forwarding
            $tcpipRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            Set-ItemProperty -Path $tcpipRegPath -Name "IPEnableRouter" -Value 1 -Type DWord -Force
            Write-Log "IP forwarding enabled"
        }
    } catch {
        Write-Log "RemoteAccess configuration failed: $($_.Exception.Message)" -Level "ERROR"
    }
    
    # 9. Configure services
    Write-Log "--- Step 9: Service Configuration ---"
    $servicesToConfigure = @("RemoteAccess", "Routing and Remote Access")
    foreach ($svcName in $servicesToConfigure) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Log "Configuring service: $svcName"
            try {
                # Set to automatic startup
                Set-Service -Name $svcName -StartupType Automatic
                Write-Log "Service $svcName set to automatic startup"
                
                # Try to start the service
                Start-Service -Name $svcName -ErrorAction Stop
                Start-Sleep -Seconds 10
                
                $svc = Get-Service -Name $svcName
                if ($svc.Status -eq "Running") {
                    Write-Log "✅ Service $svcName started successfully"
                } else {
                    Write-Log "⚠️ Service $svcName status: $($svc.Status)" -Level "WARNING"
                }
            } catch {
                Write-Log "Failed to start service $svcName : $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    # 10. Final verification
    Write-Log "--- Step 10: Final Verification ---"
    
    # Check service status
    foreach ($svcName in $services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Log "FINAL - Service $svcName : Status=$($svc.Status), StartType=$($svc.StartType)"
        }
    }
    
    # Check RemoteAccess configuration
    try {
        $raConfig = Get-RemoteAccess -ErrorAction SilentlyContinue
        if ($raConfig) {
            Write-Log "FINAL - RemoteAccess Config: VpnS2S=$($raConfig.VpnS2SStatus), BGP=$($raConfig.BgpStatus)"
        } else {
            Write-Log "FINAL - RemoteAccess configuration not found"
        }
    } catch {
        Write-Log "FINAL - Failed to get RemoteAccess config: $($_.Exception.Message)"
    }
    
    # Check BGP capabilities
    try {
        $bgpRouter = Get-BgpRouter -ErrorAction SilentlyContinue
        if ($bgpRouter) {
            Write-Log "FINAL - BGP Router configured: ASN=$($bgpRouter.BgpIdentifier)"
        } else {
            Write-Log "FINAL - BGP Router not configured (will be done in Phase 5)"
        }
    } catch {
        Write-Log "FINAL - BGP check: $($_.Exception.Message)"
    }
    
    # Create status file
    $statusReport = @"
RRAS Repair Summary - $(Get-Date)
================================

Services Status:
$(foreach ($svcName in $services) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        "  $svcName : $($svc.Status) ($($svc.StartType))"
    } else {
        "  $svcName : NOT FOUND"
    }
})

Configuration:
  IP Forwarding: $(if ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'IPEnableRouter' -ErrorAction SilentlyContinue).IPEnableRouter -eq 1) { 'ENABLED' } else { 'DISABLED' })
  RRAS Registry: $(if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess\Parameters') { 'CONFIGURED' } else { 'MISSING' })

Next Steps:
1. If services are not running, VM may need reboot
2. Phase 5 will configure BGP router and peer relationships
3. Use Get-BgpStatus.ps1 to verify BGP configuration after Phase 5
"@

    $statusReport | Out-File -FilePath "C:\Windows\Temp\rras-repair-status.txt" -Force
    Write-Log "Status report saved to C:\Windows\Temp\rras-repair-status.txt"
    
    Write-Log "=== RRAS SERVICE REPAIR COMPLETED ==="
    
} catch {
    Write-Log "CRITICAL ERROR during RRAS repair: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    throw
}
'@
    
    try {
        Write-Host "📋 Executing RRAS repair script..." -ForegroundColor Cyan
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString $repairScript
        
        # Display results
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
        
        Write-Host "✅ RRAS repair completed on $VmName" -ForegroundColor Green
        
    } catch {
        Write-Error "❌ Failed to repair RRAS on ${VmName}: $_"
        throw
    }
}

# Main execution
try {
    Write-Header "Azure VWAN Lab - RRAS Service Repair Tool"
    
    # Get target VMs
    if ($VmName) {
        $vms = @(Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop)
    } else {
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*nva*" }
        if ($vms.Count -eq 0) {
            Write-Warning "No NVA VMs found. Looking for all VMs with 'vwanlab' in name..."
            $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*vwanlab*" }
        }
    }
    
    if ($vms.Count -eq 0) {
        throw "No VMs found to repair in resource group: $ResourceGroupName"
    }
    
    Write-Host "🎯 Found $($vms.Count) VM(s) to repair:" -ForegroundColor Cyan
    foreach ($vm in $vms) {
        Write-Host "  • $($vm.Name)" -ForegroundColor White
    }
    
    # Process each VM
    foreach ($vm in $vms) {
        Write-Host "`n🔧 Processing VM: $($vm.Name)" -ForegroundColor Yellow
        Repair-RrasService -ResourceGroupName $ResourceGroupName -VmName $vm.Name
    }
    
    Write-Host "`n🎉 RRAS repair completed successfully!" -ForegroundColor Green
    Write-Host "📋 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Check if services are running: .\scripts\Get-BgpStatus.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
    Write-Host "  2. If services are still not running, consider VM reboot" -ForegroundColor Gray
    Write-Host "  3. Continue with Phase 5 for BGP configuration" -ForegroundColor Gray
    
} catch {
    Write-Error "❌ RRAS repair failed: $_"
    exit 1
}

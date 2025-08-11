#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute

<#
.SYNOPSIS
    Enable boot diagnostics with managed storage on Azure VMs

.DESCRIPTION
    This script enables boot diagnostics with managed storage on all VMs in a resource group
    or on specific VMs. Uses the latest Azure best practices with managed storage accounts.
    
    Boot diagnostics helps troubleshoot VM boot failures by providing console output and
    screenshots. Managed storage is automatically handled by Azure and costs approximately
    $0.05/GB per month for diagnostic data only.

.PARAMETER ResourceGroupName
    Name of the resource group containing the VMs

.PARAMETER VmName
    Optional specific VM name. If not provided, will process all VMs in the resource group

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current context if not specified)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Enable-BootDiagnostics.ps1 -ResourceGroupName "rg-vwanlab-demo"
    
.EXAMPLE
    .\Enable-BootDiagnostics.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-spoke1-nva-vm"

.NOTES
    Author: Azure VWAN Lab Team
    Version: 1.0
    Requires: Azure PowerShell, appropriate Azure permissions
    
    Uses latest Azure best practices:
    - API version 2024-07-01 or later
    - Managed storage (no custom storage account needed)
    - Automatic cost optimization
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VmName,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

#region Helper Functions

function Write-ScriptHeader {
    param($Title, $Description)
    
    Write-Host "`n" -NoNewline
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "  $Description" -ForegroundColor Gray
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host ""
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

function Enable-VmBootDiagnostics {
    param(
        $ResourceGroupName,
        $VmName,
        $ShowDetails = $true
    )
    
    if ($ShowDetails) {
        Write-Host "🔧 Enabling boot diagnostics with managed storage on $VmName..." -ForegroundColor Yellow
    }
    
    try {
        # Get the VM
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop
        
        # Check if boot diagnostics is already enabled
        if ($vm.DiagnosticsProfile.BootDiagnostics.Enabled -eq $true) {
            if ($ShowDetails) {
                Write-Host "✅ Boot diagnostics already enabled on $VmName" -ForegroundColor Green
                if ($vm.DiagnosticsProfile.BootDiagnostics.StorageUri) {
                    Write-Host "  • Using custom storage: $($vm.DiagnosticsProfile.BootDiagnostics.StorageUri)" -ForegroundColor Gray
                } else {
                    Write-Host "  • Using managed storage (Azure best practice)" -ForegroundColor Gray
                }
            }
            return $true
        }
        
        # Enable boot diagnostics with managed storage (latest Azure best practice)
        # When no storage URI is specified, Azure automatically uses managed storage
        if ($PSCmdlet.ShouldProcess($VmName, "Enable boot diagnostics with managed storage")) {
            Set-AzVMBootDiagnostic -VM $vm -Enable
            
            # Update the VM configuration
            $updateResult = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm
            
            if ($updateResult.IsSuccessStatusCode) {
                if ($ShowDetails) {
                    Write-Host "✅ Boot diagnostics enabled successfully on $VmName" -ForegroundColor Green
                    Write-Host "  • Using managed storage (Azure best practice)" -ForegroundColor Gray
                    Write-Host "  • Cost: ~$0.05/GB per month for diagnostic data only" -ForegroundColor Gray
                }
                return $true
            } else {
                Write-Warning "Failed to update VM configuration for boot diagnostics on $VmName"
                return $false
            }
        }
        return $false
    }
    catch {
        Write-Warning "Failed to enable boot diagnostics on ${VmName}: $_"
        return $false
    }
}

#endregion

#region Main Execution

try {
    # Display header
    Write-ScriptHeader "Azure VM Boot Diagnostics Enablement" "Enable boot diagnostics with managed storage using Azure best practices"
    
    # Show configuration
    Write-Host '📋 Configuration:' -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
    if ($VmName) {
        Write-Host "  Target VM: $VmName" -ForegroundColor White
    } else {
        Write-Host "  Target: All VMs in resource group" -ForegroundColor White
    }
    
    # Connect to Azure
    $actualSubscriptionId = Connect-ToAzure -SubscriptionId $SubscriptionId
    
    # Check if resource group exists
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        throw "Resource group '$ResourceGroupName' not found"
    }
    
    # Get VMs to process
    if ($VmName) {
        # Process specific VM
        $vms = @(Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue)
        if (-not $vms) {
            throw "VM '$VmName' not found in resource group '$ResourceGroupName'"
        }
    } else {
        # Process all VMs in resource group
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
        if (-not $vms) {
            Write-Host "ℹ️  No VMs found in resource group '$ResourceGroupName'" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "`n📊 Found $($vms.Count) VM(s) to process" -ForegroundColor Cyan
    
    # Confirm operation if not forced
    if (-not $Force -and -not $WhatIfPreference) {
        $vmList = $vms | ForEach-Object { "  • $($_.Name)" }
        Write-Host "`nVMs to process:" -ForegroundColor Gray
        $vmList | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        
        $confirmation = Read-Host "`nContinue with enabling boot diagnostics? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            return
        }
    }
    
    # Process each VM
    $successCount = 0
    $skippedCount = 0
    $failedCount = 0
    
    foreach ($vm in $vms) {
        Write-Host "`n🖥️  Processing VM: $($vm.Name)" -ForegroundColor Yellow
        
        $result = Enable-VmBootDiagnostics -ResourceGroupName $ResourceGroupName -VmName $vm.Name -ShowDetails $true
        
        if ($result -eq $true) {
            if ($vm.DiagnosticsProfile.BootDiagnostics.Enabled -eq $true) {
                $skippedCount++
            } else {
                $successCount++
            }
        } else {
            $failedCount++
        }
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host '📋 Summary:' -ForegroundColor Cyan
    Write-Host "  Total VMs processed: $($vms.Count)" -ForegroundColor White
    Write-Host "  Successfully enabled: $successCount" -ForegroundColor Green
    Write-Host "  Already enabled: $skippedCount" -ForegroundColor Yellow
    Write-Host "  Failed: $failedCount" -ForegroundColor Red
    
    if ($successCount -gt 0) {
        Write-Host "`n🎉 Boot diagnostics enabled successfully!" -ForegroundColor Green
        Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Boot diagnostics are now available in Azure Portal" -ForegroundColor Gray
        Write-Host "  2. Navigate to VM → Help → Boot diagnostics to view" -ForegroundColor Gray
        Write-Host "  3. Screenshots and serial console logs will be available" -ForegroundColor Gray
        Write-Host "  4. Costs are ~$0.05/GB per month for diagnostic data only" -ForegroundColor Gray
    }
    
    if ($failedCount -gt 0) {
        Write-Host "`n⚠️  Some VMs failed to enable boot diagnostics. Check the warnings above." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "❌ Script failed: $_"
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check Azure permissions (VM Contributor role required)" -ForegroundColor Gray
    Write-Host "  2. Verify VM is running and accessible" -ForegroundColor Gray
    Write-Host "  3. Check for VM locks or policies" -ForegroundColor Gray
    exit 1
}

#endregion

#Requires -Modules Az.Accounts, Az.Compute, Az.Resources

<#
.SYNOPSIS
    Configure auto-shutdown for Azure VMs in VWAN Lab

.DESCRIPTION
    This script configures Azure DevTest Lab auto-shutdown schedules for all VMs in the specified resource group.
    Auto-shutdown helps reduce costs by automatically stopping VMs at a specified time each day.

.PARAMETER ResourceGroupName
    Name of the resource group containing the VMs

.PARAMETER ShutdownTime
    Time to shutdown VMs daily (24-hour format, e.g., "19:00")

.PARAMETER TimeZone
    Time zone for the shutdown schedule (e.g., "UTC", "Eastern Standard Time", "Pacific Standard Time")

.PARAMETER VmName
    Optional: Specific VM name to configure (if not provided, configures all VMs in the resource group)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Set-VmAutoShutdown.ps1 -ResourceGroupName "rg-vwanlab-demo"
    Configure auto-shutdown for all VMs at 01:00 UTC (1:00 AM)

.EXAMPLE
    .\Set-VmAutoShutdown.ps1 -ResourceGroupName "rg-vwanlab-demo" -ShutdownTime "18:00" -TimeZone "Eastern Standard Time"
    Configure auto-shutdown for all VMs at 6 PM Eastern time

.EXAMPLE
    .\Set-VmAutoShutdown.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-spoke1-nva-vm" -Force
    Configure auto-shutdown for a specific VM without prompts

.NOTES
    Author: Azure VWAN Lab Team
    Version: 1.0
    Requires: Azure PowerShell, appropriate Azure permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ShutdownTime = "01:00",
    
    [Parameter(Mandatory = $false)]
    [string]$TimeZone = "UTC",
    
    [Parameter(Mandatory = $false)]
    [string]$VmName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script configuration
$ErrorActionPreference = "Stop"

function Write-Header {
    param($Title, $Subtitle)
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    if ($Subtitle) {
        Write-Host " $Subtitle" -ForegroundColor Gray
    }
    Write-Host "=" * 60 -ForegroundColor DarkCyan
}

function Set-VmAutoShutdown {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ResourceGroupName,
        [string]$VmName,
        [string]$ShutdownTime,
        [string]$TimeZone
    )
    
    try {
        Write-Host "🕐 Configuring auto-shutdown for $VmName..." -ForegroundColor Yellow
        
        # Get the VM to validate and get its resource ID
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop
        Write-Host "  ✅ VM found: $($vm.Name) in $($vm.Location)" -ForegroundColor Green
        
        # Create the auto-shutdown schedule resource name
        $scheduleName = "shutdown-computevm-$VmName"
        
        # Check if auto-shutdown already exists
        $existingSchedule = Get-AzResource -ResourceType "microsoft.devtestlab/schedules" -ResourceGroupName $ResourceGroupName -Name $scheduleName -ErrorAction SilentlyContinue
        if ($existingSchedule) {
            Write-Host "  ⚠️  Auto-shutdown already configured - updating settings" -ForegroundColor Yellow
        }
        
        # Create the auto-shutdown policy
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
                timeInMinutes = 30
            }
        }
        
        # Use New-AzResource to create/update the auto-shutdown schedule
        if ($PSCmdlet.ShouldProcess($VmName, "Configure auto-shutdown at $ShutdownTime ($TimeZone)")) {
            $schedule = New-AzResource -ResourceType "microsoft.devtestlab/schedules" `
                -ResourceName $scheduleName `
                -ResourceGroupName $ResourceGroupName `
                -Location $vm.Location `
                -Properties $scheduleProperties `
                -Force
                
            Write-Host "  ✅ Auto-shutdown configured successfully" -ForegroundColor Green
            Write-Host "     Schedule ID: $($schedule.ResourceId)" -ForegroundColor Gray
            Write-Host "     Shutdown Time: $ShutdownTime ($TimeZone)" -ForegroundColor Gray
            return $true
        }
    }
    catch {
        Write-Error "  ❌ Failed to configure auto-shutdown for ${VmName}: $($_.Exception.Message)"
        return $false
    }
}

function Get-CurrentAutoShutdown {
    param(
        [string]$ResourceGroupName,
        [string]$VmName
    )
    
    try {
        $scheduleName = "shutdown-computevm-$VmName"
        $schedule = Get-AzResource -ResourceType "microsoft.devtestlab/schedules" -ResourceGroupName $ResourceGroupName -Name $scheduleName -ErrorAction SilentlyContinue
        
        if ($schedule) {
            $properties = $schedule.Properties
            return @{
                Configured = $true
                Status = $properties.status
                Time = $properties.dailyRecurrence.time
                TimeZone = $properties.timeZoneId
                ScheduleId = $schedule.ResourceId
            }
        } else {
            return @{ Configured = $false }
        }
    }
    catch {
        return @{ Configured = $false; Error = $_.Exception.Message }
    }
}

# Main execution
try {
    Write-Header "Azure VM Auto-Shutdown Configuration" "VWAN Lab Cost Optimization Tool"
    
    # Connect to Azure if not already connected
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "🔐 Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    } else {
        Write-Host "✅ Connected to Azure as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "   Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    }
    
    # Validate resource group
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        throw "Resource group '$ResourceGroupName' not found"
    }
    
    Write-Host "✅ Resource group found: $ResourceGroupName" -ForegroundColor Green
    
    # Get VMs to configure
    if ($VmName) {
        $vms = @(Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue)
        if (-not $vms) {
            throw "VM '$VmName' not found in resource group '$ResourceGroupName'"
        }
    } else {
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
        if (-not $vms) {
            throw "No VMs found in resource group '$ResourceGroupName'"
        }
    }
    
    Write-Host "📊 Found $($vms.Count) VM(s) to configure" -ForegroundColor Cyan
    
    # Show current auto-shutdown status
    Write-Host "`n📋 Current Auto-Shutdown Status:" -ForegroundColor Cyan
    foreach ($vm in $vms) {
        $current = Get-CurrentAutoShutdown -ResourceGroupName $ResourceGroupName -VmName $vm.Name
        if ($current.Configured) {
            Write-Host "  $($vm.Name): ✅ Configured ($($current.Status)) - $($current.Time) $($current.TimeZone)" -ForegroundColor Green
        } else {
            Write-Host "  $($vm.Name): ❌ Not configured" -ForegroundColor Yellow
        }
    }
    
    # Confirm action unless Force is specified
    if (-not $Force -and -not $WhatIfPreference) {
        Write-Host "`n⚙️  Configuration Details:" -ForegroundColor Yellow
        Write-Host "   Shutdown Time: $ShutdownTime" -ForegroundColor White
        Write-Host "   Time Zone: $TimeZone" -ForegroundColor White
        Write-Host "   Target VMs: $($vms.Count)" -ForegroundColor White
        Write-Host "   Estimated Savings: ~25% of VM costs" -ForegroundColor Green
        
        $confirmation = Read-Host "`nConfigure auto-shutdown for these VMs? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Configure auto-shutdown for each VM
    Write-Host "`n🔧 Configuring Auto-Shutdown..." -ForegroundColor Cyan
    $successCount = 0
    
    foreach ($vm in $vms) {
        if (Set-VmAutoShutdown -ResourceGroupName $ResourceGroupName -VmName $vm.Name -ShutdownTime $ShutdownTime -TimeZone $TimeZone) {
            $successCount++
        }
    }
    
    # Summary
    Write-Host "`n🎉 Configuration Complete!" -ForegroundColor Green
    Write-Host "   Configured: $successCount/$($vms.Count) VMs" -ForegroundColor White
    
    if ($successCount -gt 0) {
        Write-Host "`n💰 Cost Savings:" -ForegroundColor Cyan
        Write-Host "   Daily shutdown at: $ShutdownTime ($TimeZone)" -ForegroundColor White
        Write-Host "   Estimated monthly savings: ~25% of VM costs (~$15-30)" -ForegroundColor Green
        Write-Host "`n📋 Important Notes:" -ForegroundColor Yellow
        Write-Host "   • VMs will shutdown automatically but must be manually started" -ForegroundColor Gray
        Write-Host "   • You can start VMs anytime via Azure Portal or PowerShell" -ForegroundColor Gray
        Write-Host "   • Auto-shutdown can be disabled in Azure Portal > VM > Auto-shutdown" -ForegroundColor Gray
        
        Write-Host "`n🔧 Manual Start Commands:" -ForegroundColor Cyan
        foreach ($vm in $vms) {
            Write-Host "   Start-AzVM -ResourceGroupName '$ResourceGroupName' -Name '$($vm.Name)'" -ForegroundColor Gray
        }
    }
    
    if ($successCount -lt $vms.Count) {
        Write-Warning "$($vms.Count - $successCount) VM(s) failed to configure - check errors above"
        exit 1
    }
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}

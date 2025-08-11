#Requires -Version 5.1
<#
.SYNOPSIS
    Background Resource Group Cleanup Manager
    
.DESCRIPTION
    Manages cleanup of Azure resource groups in the background, with status monitoring
    and bulk cleanup capabilities.
    
.PARAMETER ResourceGroupNames
    Array of resource group names to delete
    
.PARAMETER ListJobs
    List all currently running cleanup jobs
    
.PARAMETER CheckStatus
    Check status of specific cleanup job by ID
    
.PARAMETER JobId
    Specific job ID to check or clean up
    
.PARAMETER CleanupJobs
    Remove completed cleanup jobs
    
.PARAMETER Force
    Force delete resource groups without confirmation
    
.EXAMPLE
    .\Manage-Cleanup.ps1 -ResourceGroupNames @("rg-old-lab", "rg-test-failed")
    
.EXAMPLE
    .\Manage-Cleanup.ps1 -ListJobs
    
.EXAMPLE
    .\Manage-Cleanup.ps1 -CheckStatus -JobId 12
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$ResourceGroupNames,
    
    [Parameter(Mandatory = $false)]
    [switch]$ListJobs,
    
    [Parameter(Mandatory = $false)]
    [switch]$CheckStatus,
    
    [Parameter(Mandatory = $false)]
    [int]$JobId,
    
    [Parameter(Mandatory = $false)]
    [switch]$CleanupJobs,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Color output function
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{
        "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"
        "Cyan" = "Cyan"; "White" = "White"; "Magenta" = "Magenta"
    }
    if ($colors.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colors[$Color]
    } else {
        Write-Host $Message
    }
}

function Write-Header {
    param([string]$Title)
    Write-ColorOutput "`n$('=' * 50)" "Cyan"
    Write-ColorOutput "  $Title" "Cyan"
    Write-ColorOutput "$('=' * 50)" "Cyan"
}

# Start cleanup jobs
function Start-CleanupJobs {
    param([string[]]$RgNames, [bool]$ForceDelete = $false)
    
    Write-Header "Starting Background Cleanup Jobs"
    
    $jobs = @()
    foreach ($rgName in $RgNames) {
        # Check if resource group exists first
        try {
            $rg = az group show --name $rgName 2>$null | ConvertFrom-Json
            if (!$rg) {
                Write-ColorOutput "⚠️  Resource group '$rgName' not found, skipping..." "Yellow"
                continue
            }
        } catch {
            Write-ColorOutput "⚠️  Resource group '$rgName' not found, skipping..." "Yellow"
            continue
        }
        
        # Get resource count
        try {
            $resources = az resource list --resource-group $rgName --query "length(@)" 2>$null
            Write-ColorOutput "📦 Resource group '$rgName' contains $resources resources" "White"
        } catch {
            Write-ColorOutput "📦 Resource group '$rgName' - unable to count resources" "White"
        }
        
        # Confirmation unless forced
        if (!$ForceDelete) {
            $confirm = Read-Host "Delete resource group '$rgName'? (y/N)"
            if ($confirm -notmatch '^[Yy]') {
                Write-ColorOutput "⏭️  Skipping '$rgName'" "Yellow"
                continue
            }
        }
        
        # Create cleanup script
        $cleanupScript = @"
`$resourceGroup = '$rgName'
Write-Host "🗑️  Starting deletion of resource group: `$resourceGroup" -ForegroundColor Yellow
try {
    # Get initial resource count
    try {
        `$initialCount = az resource list --resource-group `$resourceGroup --query "length(@)" 2>`$null
        Write-Host "📊 Initial resource count: `$initialCount" -ForegroundColor White
    } catch {
        `$initialCount = "unknown"
    }
    
    # Start deletion
    `$deleteResult = az group delete --name `$resourceGroup --yes --no-wait 2>&1
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "✅ Deletion initiated for: `$resourceGroup" -ForegroundColor Green
        Write-Host "⏳ Deletion will continue in background..." -ForegroundColor Yellow
        
        # Monitor deletion progress
        `$maxWait = 300  # 5 minutes max monitoring
        `$waited = 0
        while (`$waited -lt `$maxWait) {
            Start-Sleep 30
            `$waited += 30
            
            try {
                `$rg = az group show --name `$resourceGroup 2>`$null
                if (!`$rg) {
                    Write-Host "🎉 Resource group `$resourceGroup successfully deleted!" -ForegroundColor Green
                    break
                }
                
                # Check remaining resources
                try {
                    `$currentCount = az resource list --resource-group `$resourceGroup --query "length(@)" 2>`$null
                    Write-Host "⏳ Still deleting... `$currentCount resources remaining (waited `$waited seconds)" -ForegroundColor Yellow
                } catch {
                    Write-Host "⏳ Still deleting... (waited `$waited seconds)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "🎉 Resource group `$resourceGroup successfully deleted!" -ForegroundColor Green
                break
            }
        }
        
        if (`$waited -ge `$maxWait) {
            Write-Host "⏰ Stopped monitoring after `$maxWait seconds. Deletion continues in background." -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Failed to initiate deletion for: `$resourceGroup" -ForegroundColor Red
        Write-Host "Error: `$deleteResult" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Exception during cleanup of `$resourceGroup" -ForegroundColor Red
    Write-Host "Error: `$(`$_.Exception.Message)" -ForegroundColor Red
}
"@
        
        # Start background job
        $job = Start-Job -ScriptBlock {
            param($script)
            Invoke-Expression $script
        } -ArgumentList $cleanupScript -Name "Cleanup-$rgName"
        
        $jobs += $job
        Write-ColorOutput "🚀 Started cleanup job for '$rgName' (Job ID: $($job.Id))" "Green"
    }
    
    if ($jobs.Count -gt 0) {
        Write-ColorOutput "`n📋 Summary:" "Cyan"
        Write-ColorOutput "   Started $($jobs.Count) cleanup job(s)" "White"
        Write-ColorOutput "   Monitor with: .\scripts\Manage-Cleanup.ps1 -ListJobs" "White"
        Write-ColorOutput "   Check specific job: .\scripts\Manage-Cleanup.ps1 -CheckStatus -JobId <ID>" "White"
    } else {
        Write-ColorOutput "ℹ️  No cleanup jobs started" "Yellow"
    }
    
    return $jobs
}

# List all cleanup jobs
function Show-CleanupJobs {
    Write-Header "Background Cleanup Jobs"
    
    $allJobs = Get-Job | Where-Object { $_.Name -like "Cleanup-*" }
    
    if ($allJobs.Count -eq 0) {
        Write-ColorOutput "ℹ️  No cleanup jobs found" "Yellow"
        return
    }
    
    Write-ColorOutput "📊 Found $($allJobs.Count) cleanup job(s):`n" "White"
    
    foreach ($job in $allJobs) {
        $rgName = $job.Name -replace "^Cleanup-", ""
        $statusIcon = switch ($job.State) {
            "Running" { "🔄" }
            "Completed" { "✅" }
            "Failed" { "❌" }
            "Stopped" { "⏹️" }
            default { "❓" }
        }
        
        $duration = if ($job.PSEndTime) {
            "{0:mm\:ss}" -f ($job.PSEndTime - $job.PSBeginTime)
        } else {
            "{0:mm\:ss}" -f ((Get-Date) - $job.PSBeginTime)
        }
        
        Write-ColorOutput "  $statusIcon Job ID: $($job.Id) | RG: $rgName | State: $($job.State) | Duration: $duration" "White"
        
        if ($job.State -eq "Failed") {
            Write-ColorOutput "     Error: $($job.StatusMessage)" "Red"
        }
    }
    
    Write-ColorOutput "`n💡 Commands:" "Cyan"
    Write-ColorOutput "   Check job details: Get-Job -Id <JobId> | Format-List" "White"
    Write-ColorOutput "   View job output: Receive-Job -Id <JobId>" "White"
    Write-ColorOutput "   Remove completed: .\scripts\Manage-Cleanup.ps1 -CleanupJobs" "White"
}

# Check specific job status
function Show-JobStatus {
    param([int]$JobId)
    
    Write-Header "Job Status Details"
    
    $job = Get-Job -Id $JobId -ErrorAction SilentlyContinue
    if (!$job) {
        Write-ColorOutput "❌ Job ID $JobId not found" "Red"
        return
    }
    
    $rgName = $job.Name -replace "^Cleanup-", ""
    
    Write-ColorOutput "🔍 Job Details:" "Cyan"
    Write-ColorOutput "   Job ID: $($job.Id)" "White"
    Write-ColorOutput "   Resource Group: $rgName" "White"
    Write-ColorOutput "   State: $($job.State)" "White"
    Write-ColorOutput "   Started: $($job.PSBeginTime)" "White"
    
    if ($job.PSEndTime) {
        $duration = $job.PSEndTime - $job.PSBeginTime
        Write-ColorOutput "   Ended: $($job.PSEndTime)" "White"
        Write-ColorOutput "   Duration: $("{0:mm\:ss}" -f $duration)" "White"
    } else {
        $duration = (Get-Date) - $job.PSBeginTime
        Write-ColorOutput "   Running for: $("{0:mm\:ss}" -f $duration)" "White"
    }
    
    # Show recent output
    Write-ColorOutput "`n📄 Recent Output:" "Cyan"
    try {
        $output = Receive-Job -Id $JobId -Keep
        if ($output) {
            $output | Select-Object -Last 10 | ForEach-Object {
                Write-ColorOutput "   $_" "White"
            }
        } else {
            Write-ColorOutput "   No output available yet..." "Yellow"
        }
    } catch {
        Write-ColorOutput "   Unable to retrieve job output" "Red"
    }
    
    # Check resource group status if job is running
    if ($job.State -eq "Running") {
        Write-ColorOutput "`n🔍 Current Resource Group Status:" "Cyan"
        try {
            $resources = az resource list --resource-group $rgName --query "length(@)" 2>$null
            if ($resources) {
                Write-ColorOutput "   Resources remaining: $resources" "White"
            } else {
                Write-ColorOutput "   Resource group appears to be deleted" "Green"
            }
        } catch {
            Write-ColorOutput "   Resource group not found (likely deleted)" "Green"
        }
    }
}

# Clean up completed jobs
function Remove-CompletedJobs {
    Write-Header "Cleanup Completed Jobs"
    
    $completedJobs = Get-Job | Where-Object { 
        $_.Name -like "Cleanup-*" -and 
        ($_.State -eq "Completed" -or $_.State -eq "Failed" -or $_.State -eq "Stopped")
    }
    
    if ($completedJobs.Count -eq 0) {
        Write-ColorOutput "ℹ️  No completed jobs to clean up" "Yellow"
        return
    }
    
    Write-ColorOutput "🧹 Found $($completedJobs.Count) completed job(s) to remove:" "White"
    
    foreach ($job in $completedJobs) {
        $rgName = $job.Name -replace "^Cleanup-", ""
        Write-ColorOutput "   Removing Job ID $($job.Id) (RG: $rgName) - State: $($job.State)" "White"
        Remove-Job -Id $job.Id -Force
    }
    
    Write-ColorOutput "✅ Removed $($completedJobs.Count) completed job(s)" "Green"
}

# Main execution logic
if ($ListJobs) {
    Show-CleanupJobs
} elseif ($CheckStatus -and $JobId) {
    Show-JobStatus -JobId $JobId
} elseif ($CleanupJobs) {
    Remove-CompletedJobs
} elseif ($ResourceGroupNames) {
    Start-CleanupJobs -RgNames $ResourceGroupNames -ForceDelete $Force.IsPresent
} else {
    Write-Header "Resource Group Cleanup Manager"
    Write-ColorOutput "Available commands:" "Cyan"
    Write-ColorOutput "   Delete RGs: .\Manage-Cleanup.ps1 -ResourceGroupNames @('rg1','rg2')" "White"
    Write-ColorOutput "   List jobs: .\Manage-Cleanup.ps1 -ListJobs" "White"
    Write-ColorOutput "   Check job: .\Manage-Cleanup.ps1 -CheckStatus -JobId <ID>" "White"
    Write-ColorOutput "   Clean jobs: .\Manage-Cleanup.ps1 -CleanupJobs" "White"
    Write-ColorOutput "   Force delete: .\Manage-Cleanup.ps1 -ResourceGroupNames @('rg1') -Force" "White"
}

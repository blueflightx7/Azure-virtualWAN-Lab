# Azure Resource Group Cleanup - Usage Guide

This guide covers the comprehensive Azure Resource Group cleanup tools available in the VWAN Lab environment.

## 🚀 Quick Start

### Standalone Cleanup (Recommended)

The new `Cleanup-ResourceGroups.ps1` script provides comprehensive, standalone resource group cleanup capabilities with background job management.

```powershell
# Delete a single resource group with prompts
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-old-vwanlab"

# Delete multiple resource groups without prompts (prompt-less mode)
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupNames @("rg-old-1", "rg-old-2") -Force

# Delete a resource group and wait for completion
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-test" -WaitForCompletion -Force -Timeout 90
```

### Monitor Cleanup Jobs

```powershell
# List all active cleanup jobs
.\scripts\Cleanup-ResourceGroups.ps1 -ListJobs

# Check specific job details
.\scripts\Cleanup-ResourceGroups.ps1 -CheckJob -JobId 123

# Clean up completed jobs from memory
.\scripts\Cleanup-ResourceGroups.ps1 -CleanupCompletedJobs
```

## 📋 Available Scripts

### 1. Cleanup-ResourceGroups.ps1 (Primary)
**Purpose**: Comprehensive standalone cleanup with background job management
**Features**:
- ✅ Standalone operation (independent of deployment)
- ✅ Prompt-less mode with `-Force` parameter
- ✅ Background job monitoring and management
- ✅ Real-time progress tracking
- ✅ Comprehensive error handling
- ✅ Resource count and deletion time tracking

### 2. Manage-Cleanup.ps1 (Legacy Wrapper)
**Purpose**: Backward compatibility wrapper that redirects to the new script
**Features**:
- ✅ Maintains existing parameter compatibility
- ✅ Automatically uses new enhanced features
- ✅ Seamless transition from old usage patterns

## 🛠️ Parameter Reference

### Core Parameters

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| `ResourceGroupName` | String | Single resource group to delete | No* |
| `ResourceGroupNames` | String[] | Multiple resource groups to delete | No* |
| `Force` | Switch | Skip all confirmation prompts | No |
| `WaitForCompletion` | Switch | Wait for all jobs to complete | No |
| `Timeout` | Int | Timeout in minutes (default: 60) | No |

*At least one resource group must be specified for cleanup operations

### Management Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `ListJobs` | Switch | List all active cleanup jobs |
| `CheckJob` | Switch | Check specific job details |
| `JobId` | Int | Specific job ID to check |
| `CleanupCompletedJobs` | Switch | Remove completed jobs from memory |

## 📖 Usage Examples

### Basic Cleanup Operations

```powershell
# Interactive cleanup with confirmation
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-networking-multi-vwanlab"

# Automated cleanup without prompts
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-old-lab" -Force

# Bulk cleanup of multiple resource groups
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupNames @(
    "rg-dev-vwanlab-001",
    "rg-test-vwanlab-002",
    "rg-staging-vwanlab-003"
) -Force
```

### Advanced Scenarios

```powershell
# Start cleanup and wait for completion with extended timeout
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-large-deployment" -Force -WaitForCompletion -Timeout 120

# Monitor all cleanup operations
.\scripts\Cleanup-ResourceGroups.ps1 -ListJobs

# Get detailed information about a specific cleanup job
.\scripts\Cleanup-ResourceGroups.ps1 -CheckJob -JobId 456

# Clean up completed jobs to free memory
.\scripts\Cleanup-ResourceGroups.ps1 -CleanupCompletedJobs
```

### Integration with Deployment

```powershell
# Use with enhanced deployment script (automatic background cleanup)
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-new-lab" -CleanupResourceGroup "rg-old-lab"

# Monitor the deployment's cleanup job
.\scripts\Cleanup-ResourceGroups.ps1 -ListJobs
```

## 🔍 Monitoring and Status

### Job Status Indicators

| Status | Icon | Description |
|--------|------|-------------|
| Running | 🔄 | Cleanup is actively in progress |
| Completed | ✅ | Cleanup finished successfully |
| Failed | ❌ | Cleanup encountered an error |
| Timeout | ⏰ | Cleanup exceeded time limit |
| Not Found | ⚠️ | Resource group doesn't exist |

### Real-time Monitoring

The script provides real-time updates during cleanup:
- Resource count tracking
- Progress notifications
- Time elapsed information
- Error reporting
- Completion confirmation

### Example Output

```
======================================================================
  Active Cleanup Jobs Status
======================================================================

📋 Found 2 cleanup job(s):

🔄 Job 123: Cleanup-rg-networking-multi-vwanlab
   State: Running
   Started: 2024-01-15 14:30:45
   Runtime: 00:15:32
   Recent: Found 23 resources in 'rg-networking-multi-vwanlab'

✅ Job 124: Cleanup-rg-old-test
   State: Completed
   Duration: 00:08:15
   Result: Success
   Resources deleted: 15
```

## ⚡ Performance Tips

### 1. Resource Group Size
- **Small RGs** (< 10 resources): ~2-5 minutes
- **Medium RGs** (10-50 resources): ~5-15 minutes
- **Large RGs** (50+ resources): ~15-60+ minutes

### 2. Optimization Strategies
- Use `-Force` to avoid interactive delays
- Delete empty resource groups first (instant deletion)
- Use `-WaitForCompletion` for critical deployments
- Monitor jobs with `-ListJobs` for long-running operations

### 3. Background Job Management
- Jobs continue even if console is closed
- Use `Get-Job` for PowerShell native monitoring
- Clean up completed jobs regularly to free memory
- Maximum monitoring time: 2 hours per job

## 🚨 Safety Features

### 1. Confirmation Prompts
Without `-Force` parameter, the script will:
- Show resource count and types
- Display resource group location
- Require typing 'DELETE' to confirm
- Allow cancellation at any point

### 2. Error Handling
- Validates resource group existence
- Handles Azure CLI errors gracefully
- Provides clear error messages
- Continues monitoring even with temporary failures

### 3. Timeout Protection
- Default 2-hour maximum per cleanup job
- Configurable timeout with `-Timeout` parameter
- Jobs stop monitoring but Azure continues deletion
- Status can be checked manually afterward

## 🔧 Troubleshooting

### Common Issues

**Issue**: "Resource group not found"
```powershell
# Check if resource group exists
az group show --name "your-rg-name"

# List all resource groups
az group list --output table
```

**Issue**: "Cleanup job stuck"
```powershell
# Check job status
.\scripts\Cleanup-ResourceGroups.ps1 -CheckJob -JobId <job-id>

# Force stop a job if needed
Stop-Job -Id <job-id>
Remove-Job -Id <job-id>
```

**Issue**: "Azure CLI not authenticated"
```powershell
# Login to Azure
az login

# Verify authentication
az account show
```

### Manual Cleanup

If automated cleanup fails, you can manually delete resources:

```powershell
# Force delete all resources in a resource group
az group delete --name "problematic-rg" --yes --force-deletion-types Microsoft.Compute/virtualMachines,Microsoft.Network/networkInterfaces

# Delete resource group without waiting
az group delete --name "old-rg" --yes --no-wait
```

## 🔗 Integration Points

### With Deployment Scripts
- `Deploy-VwanLab-Enhanced.ps1` automatically uses this cleanup
- Background cleanup jobs integrate seamlessly
- Status monitoring works across all tools

### With Monitoring Scripts
- `Get-LabStatus.ps1` can check cleanup job status
- `Test-Connectivity.ps1` works with cleaned environments
- All scripts respect resource group states

### With PowerShell Jobs
- Uses standard PowerShell job system
- Compatible with `Get-Job`, `Receive-Job`, `Remove-Job`
- Job names follow pattern: `Cleanup-<ResourceGroupName>`

## 📚 Advanced Usage

### Scripted Automation

```powershell
# Automated nightly cleanup script
$oldResourceGroups = az group list --query "[?starts_with(name, 'rg-temp-')].name" -o tsv
if ($oldResourceGroups) {
    .\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupNames $oldResourceGroups -Force
}
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Cleanup Old Resource Groups
  shell: pwsh
  run: |
    .\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupNames @("rg-pr-${{ github.event.number }}") -Force -WaitForCompletion
```

### Bulk Operations

```powershell
# Clean up all resource groups matching a pattern
$targetRgs = az group list --query "[?contains(name, 'vwanlab-test')].name" -o tsv
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupNames $targetRgs -Force -WaitForCompletion
```

This comprehensive cleanup system provides robust, automated resource group management with full monitoring and safety features, enabling efficient Azure resource lifecycle management in your VWAN lab environment.

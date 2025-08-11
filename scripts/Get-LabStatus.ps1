#Requires -Version 5.1
<#
.SYNOPSIS
    Quick Lab Status Checker
    
.DESCRIPTION
    Provides quick status overview of VWAN lab deployments and resources
    
.PARAMETER ResourceGroupName
    Name of the resource group to check
    
.PARAMETER ShowDetails
    Show detailed resource information
    
.PARAMETER CheckConnectivity
    Test basic connectivity between resources
    
.EXAMPLE
    .\Get-LabStatus.ps1 -ResourceGroupName "rg-vwanlab-test"
    
.EXAMPLE
    .\Get-LabStatus.ps1 -ResourceGroupName "rg-vwanlab-test" -ShowDetails -CheckConnectivity
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails,
    
    [Parameter(Mandatory = $false)]
    [switch]$CheckConnectivity
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"; "Cyan" = "Cyan"; "White" = "White"; "Magenta" = "Magenta" }
    if ($colors.ContainsKey($Color)) { Write-Host $Message -ForegroundColor $colors[$Color] } else { Write-Host $Message }
}

function Write-Header { param([string]$Title); Write-ColorOutput "`n$('=' * 50)" "Cyan"; Write-ColorOutput "  $Title" "Cyan"; Write-ColorOutput "$('=' * 50)" "Cyan" }

function Get-ResourceStatus {
    param([string]$RgName)
    
    Write-Header "Resource Group Status: $RgName"
    
    try {
        $rg = az group show --name $RgName 2>$null | ConvertFrom-Json
        if (!$rg) {
            Write-ColorOutput "❌ Resource group '$RgName' not found" "Red"
            return $null
        }
        
        Write-ColorOutput "✅ Resource group exists in $($rg.location)" "Green"
        
        # Get resources
        $resources = az resource list --resource-group $RgName 2>$null | ConvertFrom-Json
        if (!$resources) {
            Write-ColorOutput "📦 No resources found in resource group" "Yellow"
            return @{ ResourceGroup = $rg; Resources = @() }
        }
        
        Write-ColorOutput "📦 Found $($resources.Count) resources" "White"
        
        # Categorize resources
        $resourceTypes = @{
            "VirtualWan" = $resources | Where-Object { $_.type -eq "Microsoft.Network/virtualWans" }
            "VirtualHub" = $resources | Where-Object { $_.type -eq "Microsoft.Network/virtualHubs" }
            "VirtualNetwork" = $resources | Where-Object { $_.type -eq "Microsoft.Network/virtualNetworks" }
            "VirtualMachine" = $resources | Where-Object { $_.type -eq "Microsoft.Compute/virtualMachines" }
            "PublicIP" = $resources | Where-Object { $_.type -eq "Microsoft.Network/publicIPAddresses" }
            "NetworkInterface" = $resources | Where-Object { $_.type -eq "Microsoft.Network/networkInterfaces" }
            "NSG" = $resources | Where-Object { $_.type -eq "Microsoft.Network/networkSecurityGroups" }
        }
        
        foreach ($type in $resourceTypes.Keys) {
            $count = $resourceTypes[$type].Count
            if ($count -gt 0) {
                $icon = switch ($type) {
                    "VirtualWan" { "🌐" }
                    "VirtualHub" { "🔄" }
                    "VirtualNetwork" { "🔗" }
                    "VirtualMachine" { "💻" }
                    "PublicIP" { "🌍" }
                    "NetworkInterface" { "🔌" }
                    "NSG" { "🛡️" }
                    default { "📋" }
                }
                Write-ColorOutput "   $icon $type`: $count" "White"
                
                if ($ShowDetails) {
                    foreach ($resource in $resourceTypes[$type]) {
                        Write-ColorOutput "      - $($resource.name)" "Cyan"
                    }
                }
            }
        }
        
        return @{ ResourceGroup = $rg; Resources = $resources; Categorized = $resourceTypes }
        
    } catch {
        Write-ColorOutput "❌ Error checking resource group: $($_.Exception.Message)" "Red"
        return $null
    }
}

function Test-LabConnectivity {
    param([object]$ResourceInfo)
    
    if (!$CheckConnectivity) { return }
    
    Write-Header "Connectivity Tests"
    
    $vms = $ResourceInfo.Categorized.VirtualMachine
    if ($vms.Count -eq 0) {
        Write-ColorOutput "⚠️  No VMs found for connectivity testing" "Yellow"
        return
    }
    
    Write-ColorOutput "🔍 Testing VM connectivity..." "White"
    
    foreach ($vm in $vms) {
        try {
            $vmDetails = az vm show --resource-group $ResourceGroupName --name $vm.name 2>$null | ConvertFrom-Json
            $powerState = az vm get-instance-view --resource-group $ResourceGroupName --name $vm.name --query "instanceView.statuses[?code=='PowerState/running'].displayStatus" --output tsv 2>$null
            
            if ($powerState -eq "VM running") {
                Write-ColorOutput "   ✅ $($vm.name): Running" "Green"
            } else {
                Write-ColorOutput "   ⏸️  $($vm.name): $powerState" "Yellow"
            }
            
            # Get IP addresses
            if ($ShowDetails) {
                $nics = az vm nic list --resource-group $ResourceGroupName --vm-name $vm.name 2>$null | ConvertFrom-Json
                foreach ($nic in $nics) {
                    $nicDetails = az network nic show --ids $nic.id 2>$null | ConvertFrom-Json
                    $privateIP = $nicDetails.ipConfigurations[0].privateIPAddress
                    $publicIP = if ($nicDetails.ipConfigurations[0].publicIPAddress) {
                        $pip = az network public-ip show --ids $nicDetails.ipConfigurations[0].publicIPAddress.id 2>$null | ConvertFrom-Json
                        $pip.ipAddress
                    } else { "None" }
                    
                    Write-ColorOutput "      Private IP: $privateIP | Public IP: $publicIP" "Cyan"
                }
            }
            
        } catch {
            Write-ColorOutput "   ❌ $($vm.name): Error getting status" "Red"
        }
    }
}

function Test-VwanStatus {
    param([object]$ResourceInfo)
    
    $vwans = $ResourceInfo.Categorized.VirtualWan
    $hubs = $ResourceInfo.Categorized.VirtualHub
    
    if ($vwans.Count -eq 0) {
        Write-ColorOutput "⚠️  No Virtual WAN found" "Yellow"
        return
    }
    
    Write-Header "Virtual WAN Status"
    
    foreach ($vwan in $vwans) {
        try {
            $vwanDetails = az network vwan show --resource-group $ResourceGroupName --name $vwan.name 2>$null | ConvertFrom-Json
            Write-ColorOutput "🌐 VWAN: $($vwan.name)" "Green"
            Write-ColorOutput "   Type: $($vwanDetails.type)" "White"
            Write-ColorOutput "   Allow Branch-to-Branch: $($vwanDetails.allowBranchToBranchTraffic)" "White"
            
        } catch {
            Write-ColorOutput "❌ Error getting VWAN details: $($vwan.name)" "Red"
        }
    }
    
    foreach ($hub in $hubs) {
        try {
            $hubDetails = az network vhub show --resource-group $ResourceGroupName --name $hub.name 2>$null | ConvertFrom-Json
            Write-ColorOutput "🔄 Hub: $($hub.name)" "Green"
            Write-ColorOutput "   Address Prefix: $($hubDetails.addressPrefix)" "White"
            Write-ColorOutput "   Routing State: $($hubDetails.routingState)" "White"
            
            # Check connections
            if ($ShowDetails) {
                $connections = az network vhub connection list --resource-group $ResourceGroupName --vhub-name $hub.name 2>$null | ConvertFrom-Json
                if ($connections.Count -gt 0) {
                    Write-ColorOutput "   Connections:" "Cyan"
                    foreach ($conn in $connections) {
                        Write-ColorOutput "      - $($conn.name): $($conn.connectionStatus)" "White"
                    }
                } else {
                    Write-ColorOutput "   No VNet connections found" "Yellow"
                }
            }
            
        } catch {
            Write-ColorOutput "❌ Error getting Hub details: $($hub.name)" "Red"
        }
    }
}

# Main execution
$resourceInfo = Get-ResourceStatus -RgName $ResourceGroupName

if ($resourceInfo) {
    Test-VwanStatus -ResourceInfo $resourceInfo
    Test-LabConnectivity -ResourceInfo $resourceInfo
    
    Write-Header "Quick Actions"
    Write-ColorOutput "🧪 Test full connectivity: .\scripts\Test-Connectivity.ps1 -ResourceGroupName '$ResourceGroupName'" "White"
    Write-ColorOutput "🔧 Configure NVA: .\scripts\Configure-NvaVm.ps1 -ResourceGroupName '$ResourceGroupName'" "White"
    Write-ColorOutput "🔍 Troubleshoot: .\scripts\Troubleshoot-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName'" "White"
    Write-ColorOutput "🗑️  Enhanced cleanup: .\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName '$ResourceGroupName' -Force" "White"
    Write-ColorOutput "📊 Monitor cleanup jobs: .\scripts\Cleanup-ResourceGroups.ps1 -ListJobs" "White"
    
    # Check for active cleanup jobs related to this resource group
    $cleanupJobs = Get-Job | Where-Object { $_.Name -like "*Cleanup*$ResourceGroupName*" -or $_.Name -like "Cleanup-$ResourceGroupName" }
    if ($cleanupJobs.Count -gt 0) {
        Write-ColorOutput "`n🔄 Active cleanup jobs for this resource group:" "Yellow"
        foreach ($job in $cleanupJobs) {
            $status = switch ($job.State) {
                "Running" { @{ Icon = "🔄"; Color = "Yellow" } }
                "Completed" { @{ Icon = "✅"; Color = "Green" } }
                "Failed" { @{ Icon = "❌"; Color = "Red" } }
                default { @{ Icon = "❓"; Color = "White" } }
            }
            Write-ColorOutput "   $($status.Icon) Job $($job.Id): $($job.Name) - $($job.State)" $status.Color
        }
        Write-ColorOutput "   Check details: .\scripts\Cleanup-ResourceGroups.ps1 -CheckJob -JobId <JobId>" "Cyan"
    }
} else {
    Write-ColorOutput "❌ Unable to get resource group status" "Red"
    exit 1
}

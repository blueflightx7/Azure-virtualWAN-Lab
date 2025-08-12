#Requires -Version 5.1
#Requires -Modules Az.Accounts, Az.Compute, Az.Network, Az.Security

<#
.SYNOPSIS
    Configure Just-In-Time (JIT) VM access for Azure VWAN Lab VMs
    
.DESCRIPTION
    This script configures JIT access for all VMs in a resource group.
    Uses REST API since Azure CLI doesn't support JIT policy create/delete operations.
    Falls back to restrictive NSG rules if JIT configuration fails.
    
.PARAMETER ResourceGroupName
    Name of the resource group containing the VMs
    
.PARAMETER Force
    Skip confirmation prompt
    
.EXAMPLE
    .\Set-VmJitAccess-Fixed.ps1 -ResourceGroupName "rg-vwanlab-security"
    
.EXAMPLE
    .\Set-VmJitAccess-Fixed.ps1 -ResourceGroupName "rg-vwanlab-security" -Force
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [switch]$Force
)

function Write-Header {
    param([string]$Title, [string]$Subtitle = "")
    
    $line = "=" * 60
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor White
    if ($Subtitle) {
        Write-Host " $Subtitle" -ForegroundColor Gray
    }
    Write-Host "$line" -ForegroundColor Cyan
}

function Get-ActualJitVmCount {
    param([string]$ResourceGroupName)
    
    try {
        # Get all unique locations with VMs
        $vmLocations = (Get-AzVM -ResourceGroupName $ResourceGroupName).Location | Sort-Object -Unique
        
        $totalJitVms = 0
        foreach ($location in $vmLocations) {
            try {
                $jitPolicyResult = az security jit-policy show --resource-group $ResourceGroupName --location $location --name "default" --query "virtualMachines[].id" --output json 2>$null
                if ($LASTEXITCODE -eq 0 -and $jitPolicyResult) {
                    $vmIds = $jitPolicyResult | ConvertFrom-Json
                    if ($vmIds) {
                        $vmCount = if ($vmIds -is [array]) { $vmIds.Count } else { 1 }
                        $totalJitVms += $vmCount
                        Write-Host "  📍 $location`: $vmCount VMs in JIT policy" -ForegroundColor Gray
                    }
                }
            } catch {
                # No JIT policy for this location
            }
        }
        
        return $totalJitVms
    } catch {
        Write-Warning "Failed to verify JIT configuration: $($_.Exception.Message)"
        return 0
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
            $nsgId = $nic.NetworkSecurityGroup.Id
            $nsgName = ($nsgId -split '/')[-1]
            $nsgRg = ($nsgId -split '/')[4]
            $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $nsgRg
        } else {
            # Check subnet NSG
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
            $subnet = $vnet.Subnets | Where-Object { $_.Id -eq $nic.IpConfigurations[0].Subnet.Id }
            if ($subnet.NetworkSecurityGroup) {
                $nsgId = $subnet.NetworkSecurityGroup.Id
                $nsgName = ($nsgId -split '/')[-1]
                $nsgRg = ($nsgId -split '/')[4]
                $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $nsgRg
            }
        }
        
        if ($nsg) {
            # Add a high-priority rule that denies RDP from internet (as backup)
            $ruleName = "SfiDenyRdpFromInternet"
            $existingRule = $nsg.SecurityRules | Where-Object { $_.Name -eq $ruleName }
            
            if (-not $existingRule) {
                # Find a unique priority (avoid conflicts)
                $usedPriorities = $nsg.SecurityRules | Where-Object { $_.Direction -eq "Inbound" } | ForEach-Object { $_.Priority }
                $priority = 1001
                while ($priority -in $usedPriorities) {
                    $priority++
                }
                
                $nsg | Add-AzNetworkSecurityRuleConfig -Name $ruleName -Description "SFI: Deny RDP from Internet (JIT override available)" -Access Deny -Protocol Tcp -Direction Inbound -Priority $priority -SourceAddressPrefix "Internet" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "3389"
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

function Enable-JitAccessForLab {
    param([string]$ResourceGroupName)
    
    Write-Host '🔐 Configuring Just-In-Time (JIT) VM access...' -ForegroundColor Yellow
    Write-Host "   Secure Future Initiative (SFI) security enhancement" -ForegroundColor Gray
    
    # Get all VMs in the resource group
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    
    if (-not $vms) {
        Write-Warning "No VMs found in resource group $ResourceGroupName"
        return 0
    }
    
    $totalCount = $vms.Count
    Write-Host "`n🔍 Found $totalCount VMs in resource group: $ResourceGroupName" -ForegroundColor Cyan
    
    # Group VMs by location for regional JIT policies
    $vmsByLocation = $vms | Group-Object Location
    
    $policiesCreated = 0
    
    foreach ($locationGroup in $vmsByLocation) {
        $location = $locationGroup.Name
        $locationVms = $locationGroup.Group
        
        Write-Host "`n📍 Configuring JIT for $($locationVms.Count) VMs in $location" -ForegroundColor Yellow
        
        try {
            # Get access token for REST API
            try {
                $tokenResult = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
                $token = $tokenResult.Token
            } catch {
                throw "Failed to get Azure access token: $($_.Exception.Message)"
            }
            
            # Create JIT policy for all VMs in this location using REST API
            $virtualMachines = @()
            foreach ($vm in $locationVms) {
                $virtualMachines += @{
                    id = $vm.Id
                    ports = @(
                        @{
                            number = 3389
                            protocol = "TCP"
                            allowedSourceAddressPrefix = "*"
                            maxRequestAccessDuration = "PT3H"
                        }
                        @{
                            number = 22
                            protocol = "TCP"
                            allowedSourceAddressPrefix = "*"
                            maxRequestAccessDuration = "PT3H"
                        }
                    )
                }
            }
            
            $jitPolicy = @{
                kind = "Basic"
                properties = @{
                    virtualMachines = $virtualMachines
                }
            }
            
            # Create REST API request
            $subscriptionId = (Get-AzContext).Subscription.Id
            $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Security/locations/$location/jitNetworkAccessPolicies/default?api-version=2020-01-01"
            $headers = @{
                'Authorization' = "Bearer $token"
                'Content-Type' = 'application/json'
            }
            
            $body = $jitPolicy | ConvertTo-Json -Depth 10
            
            try {
                $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
                Write-Host "  ✅ JIT policy created for $($locationVms.Count) VMs in $location" -ForegroundColor Green
                $policiesCreated++
            } catch {
                $errorDetails = $_.Exception.Message
                if ($_.Exception.Response) {
                    try {
                        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                        $errorDetails += " Response: " + $reader.ReadToEnd()
                        $reader.Close()
                    } catch {
                        # Ignore errors reading response
                    }
                }
                Write-Host "  ❌ REST API JIT configuration failed for $location`: $errorDetails" -ForegroundColor Red
                
                # Fallback to NSG configuration for this location
                Write-Host "  🔄 Falling back to NSG configuration for $location..." -ForegroundColor Yellow
                foreach ($vm in $locationVms) {
                    Set-VmRestrictedRdpAccess -ResourceGroupName $ResourceGroupName -VmName $vm.Name | Out-Null
                }
            }
        } catch {
            Write-Host "  ❌ Error configuring JIT for $location`: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  🔄 Attempting NSG fallback for $location..." -ForegroundColor Yellow
            
            # Fallback to NSG configuration for this location
            foreach ($vm in $locationVms) {
                Set-VmRestrictedRdpAccess -ResourceGroupName $ResourceGroupName -VmName $vm.Name | Out-Null
            }
        }
    }
    
    # Verify actual JIT configuration
    Write-Host "`n🔍 Verifying JIT policies..." -ForegroundColor Yellow
    $actualJitCount = Get-ActualJitVmCount -ResourceGroupName $ResourceGroupName
    
    return $actualJitCount
}

# Main execution
try {
    Write-Header "Azure VWAN Lab - JIT Access Configuration" "Secure Future Initiative (SFI) Enhancement"
    
    Write-Host "📋 Configuration Details:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "  Security Enhancement: Just-In-Time (JIT) VM Access" -ForegroundColor White
    Write-Host "  Fallback: Restrictive NSG rules if Defender for Cloud unavailable" -ForegroundColor White
    
    # Validate prerequisites
    Write-Host "`n🔍 Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Azure connection
    $context = Get-AzContext
    if (-not $context) {
        throw "Not connected to Azure. Please run Connect-AzAccount first."
    }
    
    Write-Host "✅ Connected to Azure subscription: $($context.Subscription.Name)" -ForegroundColor Green
    
    # Check resource group exists
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        throw "Resource group '$ResourceGroupName' not found."
    }
    
    Write-Host "✅ Resource group found: $ResourceGroupName" -ForegroundColor Green
    
    # Confirm action
    if (-not $Force) {
        Write-Host "`n⚠️  This will configure JIT access for all VMs in the resource group." -ForegroundColor Yellow
        Write-Host "   - RDP access will require approval through Azure Portal" -ForegroundColor Yellow
        Write-Host "   - Existing RDP access may be restricted" -ForegroundColor Yellow
        
        $confirmation = Read-Host "`nContinue? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Configure JIT access
    $actualJitCount = Enable-JitAccessForLab -ResourceGroupName $ResourceGroupName
    
    # Get VM count for reporting
    $allVms = Get-AzVM -ResourceGroupName $ResourceGroupName
    $totalVmCount = $allVms.Count
    
    # Results based on actual verification
    Write-Host "`n✅ JIT/Restricted access configured: $actualJitCount/$totalVmCount VMs" -ForegroundColor $(if ($actualJitCount -eq $totalVmCount) { 'Green' } elseif ($actualJitCount -gt 0) { 'Yellow' } else { 'Red' })
    
    if ($actualJitCount -gt 0) {
        Write-Host "🔒 Enhanced Security: $actualJitCount VMs protected with Just-In-Time access" -ForegroundColor Cyan
        Write-Host "🛡️ Access Control: RDP access requires approval through Azure Portal" -ForegroundColor Cyan
        Write-Host "⏱️ Time-Limited: Access automatically expires after specified duration" -ForegroundColor Gray
    }
    
    if ($actualJitCount -lt $totalVmCount) {
        Write-Host "⚠️ Warning: $($totalVmCount - $actualJitCount) VMs failed to configure JIT/restricted access" -ForegroundColor Red
        Write-Host "💡 Manual configuration may be required for failed VMs" -ForegroundColor Yellow
    }
    
    # Results
    if ($actualJitCount -eq 0) {
        Write-Host "`n❌ JIT Configuration failed for all VMs!" -ForegroundColor Red
        Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Ensure Microsoft Defender for Cloud is enabled" -ForegroundColor Gray
        Write-Host "  2. Check Azure permissions (Security Admin role required)" -ForegroundColor Gray
        Write-Host "  3. Verify VMs are running and accessible" -ForegroundColor Gray
        Write-Host "  4. Check if JIT policies already exist for these VMs" -ForegroundColor Gray
        exit 1
    } elseif ($actualJitCount -lt $totalVmCount) {
        Write-Host "`n⚠️ JIT Configuration partially completed!" -ForegroundColor Yellow
        Write-Host "   Configured: $actualJitCount/$totalVmCount VMs" -ForegroundColor Yellow
    } else {
        Write-Host "`n🎉 JIT Configuration completed successfully!" -ForegroundColor Green
        Write-Host "   Configured: $actualJitCount/$totalVmCount VMs" -ForegroundColor Green
    }
    
    if ($actualJitCount -gt 0) {
        Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Test JIT access through Azure Portal" -ForegroundColor Gray
        Write-Host "  2. Configure JIT policies as needed" -ForegroundColor Gray
        Write-Host "  3. Train users on requesting JIT access" -ForegroundColor Gray
        Write-Host "  4. Monitor access requests in Security Center" -ForegroundColor Gray
        
        Write-Host "`n🔗 Learn more about JIT access:" -ForegroundColor Cyan
        Write-Host "  https://docs.microsoft.com/en-us/azure/security-center/security-center-just-in-time" -ForegroundColor Blue
    }
}
catch {
    Write-Error "❌ JIT configuration failed: $_"
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure Microsoft Defender for Cloud is enabled" -ForegroundColor Gray
    Write-Host "  2. Check Azure permissions (Security Admin role required)" -ForegroundColor Gray
    Write-Host "  3. Verify VMs are running and accessible" -ForegroundColor Gray
    exit 1
}

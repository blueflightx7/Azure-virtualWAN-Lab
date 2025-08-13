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
    .\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-security"
    
.EXAMPLE
    .\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-security" -Force
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

function Remove-PermissiveNsgRules {
    param([string]$ResourceGroupName)
    
    Write-Host "`n🔒 Removing permissive NSG rules..." -ForegroundColor Yellow
    
    try {
        $nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName
        
        foreach ($nsg in $nsgs) {
            $rulesToRemove = @()
            
            # Find permissive SSH and RDP rules
            foreach ($rule in $nsg.SecurityRules) {
                if ($rule.Access -eq "Allow" -and 
                    ($rule.DestinationPortRange -eq "22" -or $rule.DestinationPortRange -eq "3389") -and
                    ($rule.SourceAddressPrefix -eq "VirtualNetwork" -or $rule.SourceAddressPrefix -eq "*" -or $rule.SourceAddressPrefix -eq "Internet")) {
                    $rulesToRemove += $rule.Name
                }
            }
            
            # Remove permissive rules
            foreach ($ruleName in $rulesToRemove) {
                try {
                    Write-Host "  🗑️ Removing permissive rule '$ruleName' from $($nsg.Name)" -ForegroundColor Gray
                    Remove-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $ruleName | Out-Null
                } catch {
                    Write-Warning "Failed to remove rule $ruleName`: $($_.Exception.Message)"
                }
            }
            
            # Update NSG if rules were removed
            if ($rulesToRemove.Count -gt 0) {
                try {
                    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg | Out-Null
                    Write-Host "  ✅ Updated NSG: $($nsg.Name)" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to update NSG $($nsg.Name)`: $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warning "Error removing permissive NSG rules: $($_.Exception.Message)"
    }
}

function Request-JitAccess {
    param(
        [string]$ResourceGroupName,
        [string]$VmName,
        [string]$SourceIp,
        [string]$Location,
        [int]$DurationHours = 24
    )
    
    Write-Host "`n🔓 Requesting JIT access for $VmName..." -ForegroundColor Yellow
    
    try {
        # Get access token
        $tokenResult = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
        $token = $tokenResult.Token
        
        # Get VM details
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
        
        # Create access request
        $accessRequest = @{
            virtualMachines = @(
                @{
                    id = $vm.Id
                    ports = @(
                        @{
                            number = 22
                            duration = "PT$($DurationHours)H"
                            allowedSourceAddressPrefix = "$SourceIp/32"
                        }
                        @{
                            number = 3389
                            duration = "PT$($DurationHours)H"
                            allowedSourceAddressPrefix = "$SourceIp/32"
                        }
                    )
                }
            )
            justification = "Automated access request for lab deployment"
        }
        
        # Make REST API call
        $subscriptionId = (Get-AzContext).Subscription.Id
        $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Security/locations/$Location/jitNetworkAccessPolicies/default/initiate?api-version=2020-01-01"
        
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }
        
        $body = $accessRequest | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
        Write-Host "  ✅ JIT access granted for $VmName (24 hours)" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Warning "Failed to request JIT access for $VmName`: $($_.Exception.Message)"
        return $false
    }
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
                            maxRequestAccessDuration = "PT24H"
                        }
                        @{
                            number = 22
                            protocol = "TCP"
                            allowedSourceAddressPrefix = "*"
                            maxRequestAccessDuration = "PT24H"
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
    Write-Host "🔐 Setting up JIT VM Access for Azure VWAN Lab" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
    Write-Host "SFI Enabled: $($SfiEnable -or $Force)" -ForegroundColor Gray
    
    if ($Force -or $SfiEnable) {
        # First remove permissive NSG rules for SFI compliance
        Remove-PermissiveNsgRules -ResourceGroupName $ResourceGroupName
    }
    
    # Get all VMs in the resource group
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*vwanlab*" }
    
    if ($vms.Count -eq 0) {
        Write-Warning "No VMs found in resource group $ResourceGroupName"
        exit 1
    }
    
    Write-Host "`nFound $($vms.Count) VMs in resource group $ResourceGroupName" -ForegroundColor Green
    
    # Group VMs by location for JIT policy creation
    $vmsByLocation = $vms | Group-Object Location
    
    foreach ($locationGroup in $vmsByLocation) {
        $location = $locationGroup.Name
        $locationVms = $locationGroup.Group
        
        Write-Host "`n📍 Processing $($locationVms.Count) VM(s) in $location..." -ForegroundColor Cyan
        
        try {
            # Create JIT policy for this location using the new function
            $virtualMachines = @()
            foreach ($vm in $locationVms) {
                $virtualMachines += @{
                    id = $vm.Id
                    ports = @(
                        @{
                            number = 3389
                            protocol = "TCP"
                            allowedSourceAddressPrefix = "*"
                            maxRequestAccessDuration = "PT24H"
                        }
                        @{
                            number = 22
                            protocol = "TCP"
                            allowedSourceAddressPrefix = "*"
                            maxRequestAccessDuration = "PT24H"
                        }
                    )
                }
            }
            
            # Get access token for REST API
            $tokenResult = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
            $token = $tokenResult.Token
            
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
            $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
            Write-Host "✅ JIT policy created for $($locationVms.Count) VMs in $location" -ForegroundColor Green
            
        } catch {
            Write-Warning "Error processing VMs in $location`: $($_.Exception.Message)"
        }
    }
    
    # Display access instructions
    Write-Host "`n📋 JIT ACCESS INSTRUCTIONS" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "🔓 TO REQUEST JIT ACCESS:" -ForegroundColor Green
    Write-Host "Option 1 - Azure Portal:" -ForegroundColor Cyan
    Write-Host "  1. Go to Azure Security Center > Just-in-time VM access" -ForegroundColor Gray
    Write-Host "  2. Select the VM you want to access" -ForegroundColor Gray
    Write-Host "  3. Click 'Request access'" -ForegroundColor Gray
    Write-Host "  4. Enter your IP address (current: $deployerIp)" -ForegroundColor Gray
    Write-Host "  5. Set duration (max 24 hours)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Option 2 - PowerShell REST API:" -ForegroundColor Cyan
    Write-Host "  Run the following command for each VM:" -ForegroundColor Gray
    Write-Host ""
    foreach ($vm in $vms) {
        Write-Host "  # Access $($vm.Name)" -ForegroundColor Yellow
        Write-Host "  Request-JitAccess -ResourceGroupName '$ResourceGroupName' -VmName '$($vm.Name)' -SourceIp '$deployerIp' -Location '$($vm.Location)'" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "Option 3 - Azure CLI:" -ForegroundColor Cyan
    Write-Host "  az security jit-policy initiate \\" -ForegroundColor White
    Write-Host "    --resource-group '$ResourceGroupName' \\" -ForegroundColor White
    Write-Host "    --vm-name 'VM_NAME' \\" -ForegroundColor White
    Write-Host "    --vm-ports '[{`"number`":22,`"duration`":`"PT24H`",`"allowedSourceAddressPrefix`":`"$deployerIp/32`"}]'" -ForegroundColor White
    Write-Host ""
    
    Write-Host "� NOTES:" -ForegroundColor Yellow
    Write-Host "  • JIT access duration: 24 hours maximum" -ForegroundColor Gray
    Write-Host "  • Access is restricted to your IP: $deployerIp" -ForegroundColor Gray
    Write-Host "  • RDP (3389) and SSH (22) ports are configured" -ForegroundColor Gray
    Write-Host "  • Permissive NSG rules have been removed for SFI compliance" -ForegroundColor Gray
    Write-Host ""
    
    # Show actual policy count
    $actualCount = Get-ActualJitVmCount -ResourceGroupName $ResourceGroupName
    Write-Host "✅ Total JIT policies active: $actualCount" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to configure JIT access: $($_.Exception.Message)"
    exit 1
}

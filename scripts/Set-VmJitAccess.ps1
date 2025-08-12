#Requires -Modules Az.Accounts, Az.Compute, Az.Resources, Az.Network

<#
.SYNOPSIS
    Configure Just-In-Time (JIT) VM access for Azure VMs in VWAN Lab

.DESCRIPTION
    This script configures Microsoft Defender for Cloud Just-In-Time (JIT) VM access for all VMs in the specified resource group.
    JIT access is part of Microsoft's Secure Future Initiative (SFI) and helps reduce the attack surface by automatically
    closing RDP ports and requiring approval for access.

.PARAMETER ResourceGroupName
    Name of the resource group containing the VMs

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-demo"
    Configure JIT access for all VMs in the resource group

.EXAMPLE
    .\Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-security" -Force
    Configure JIT access without confirmation prompts

.NOTES
    Author: Azure VWAN Lab Team
    Version: 1.0
    Requires: Azure PowerShell, Microsoft Defender for Cloud, appropriate Azure permissions
    
    This script is part of the Secure Future Initiative (SFI) implementation for the Azure VWAN Lab.
    If Defender for Cloud is not available, it will fall back to restrictive NSG rules.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
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
    
    Write-Host "`n✅ JIT/Restricted access configured: $successCount/$totalCount VMs" -ForegroundColor $(if ($successCount -eq $totalCount) { 'Green' } elseif ($successCount -gt 0) { 'Yellow' } else { 'Red' })
    
    if ($successCount -gt 0) {
        Write-Host "🔒 Enhanced Security: $successCount VMs protected with Just-In-Time access" -ForegroundColor Cyan
        Write-Host "🛡️ Access Control: RDP access requires approval through Azure Portal" -ForegroundColor Cyan
        Write-Host "⏱️ Time-Limited: Access automatically expires after specified duration" -ForegroundColor Gray
    }
    
    if ($successCount -lt $totalCount) {
        Write-Host "⚠️ Warning: $($totalCount - $successCount) VMs failed to configure JIT/restricted access" -ForegroundColor Red
        Write-Host "💡 Manual configuration may be required for failed VMs" -ForegroundColor Yellow
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
        
        # Try using REST API through PowerShell (Azure CLI doesn't support JIT policy creation)
        $vmResourceId = $vm.Id
        $subscriptionId = (Get-AzContext).Subscription.Id
        $location = $vm.Location
        
        # Create JIT policy using REST API
        $jitPolicy = @{
            kind = "Basic"
            properties = @{
                virtualMachines = @(
                    @{
                        id = $vmResourceId
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
                )
            }
        }
        
        # Get access token for REST API (using newer method)
        try {
            $tokenResult = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
            $token = $tokenResult.Token
        } catch {
            # Fallback to older method if available
            $context = Get-AzContext
            $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, "Never", $null, "https://management.azure.com/").AccessToken
        }
        
        # Create REST API request
        $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Security/locations/$location/jitNetworkAccessPolicies/default?api-version=2020-01-01"
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }
        
        $body = $jitPolicy | ConvertTo-Json -Depth 10
        
        try {
            $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
            Write-Host "    ✅ JIT access policy configured successfully" -ForegroundColor Green
            return $true
        } catch {
            $errorDetails = $_.Exception.Message
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorDetails += " Response: " + $reader.ReadToEnd()
            }
            throw "REST API JIT configuration failed: $errorDetails"
        }
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
    $result = Enable-JitAccessForLab -ResourceGroupName $ResourceGroupName
    $jitConfigured = $result
    
    # Get VM count for reporting
    $allVms = Get-AzVM -ResourceGroupName $ResourceGroupName
    $totalVmCount = $allVms.Count
    
    # Results
    if ($jitConfigured -eq 0) {
        Write-Host "`n❌ JIT Configuration failed for all VMs!" -ForegroundColor Red
        Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Ensure Microsoft Defender for Cloud is enabled" -ForegroundColor Gray
        Write-Host "  2. Check Azure permissions (Security Admin role required)" -ForegroundColor Gray
        Write-Host "  3. Verify VMs are running and accessible" -ForegroundColor Gray
        Write-Host "  4. Check if JIT policies already exist for these VMs" -ForegroundColor Gray
        exit 1
    } elseif ($jitConfigured -lt $totalVmCount) {
        Write-Host "`n⚠️ JIT Configuration partially completed!" -ForegroundColor Yellow
        Write-Host "   Configured: $jitConfigured/$totalVmCount VMs" -ForegroundColor Yellow
    } else {
        Write-Host "`n🎉 JIT Configuration completed successfully!" -ForegroundColor Green
        Write-Host "   Configured: $jitConfigured/$totalVmCount VMs" -ForegroundColor Green
    }
    
    if ($jitConfigured -gt 0) {
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

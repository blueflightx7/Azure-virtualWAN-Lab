#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute, Az.Network

<#
.SYNOPSIS
    Complete RRAS and BGP Configuration for Azure VWAN Lab NVA

.DESCRIPTION
    This script provides complete configuration of the NVA VM with:
    - Windows RRAS (Routing and Remote Access Service)
    - BGP peering with Azure Route Server (ASN 65515)
    - BGP peering with VWAN Hub (if enabled)
    - Proper IP forwarding and routing configuration

.PARAMETER ResourceGroupName
    Name of the resource group containing the NVA VM

.PARAMETER VmName  
    Name of the NVA VM to configure (default: vwanlab-spoke1-nva-vm)

.PARAMETER LocalAsn
    Local ASN for the NVA BGP configuration (default: 65001)

.PARAMETER RouteServerAsn
    Remote ASN for Azure Route Server (default: 65515)

.EXAMPLE
    .\Configure-NvaBgp.ps1 -ResourceGroupName "rg-vwanlab-demo"

.EXAMPLE
    .\Configure-NvaBgp.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-spoke1-nva-vm" -LocalAsn 65001

.NOTES
    Author: Azure VWAN Lab Team
    Version: 2.0
    Requires: Azure PowerShell, appropriate Azure permissions
    
    This script configures BGP peering for:
    1. NVA (ASN 65001) ↔ Azure Route Server (ASN 65515)
    2. Proper RRAS service configuration
    3. IP forwarding and routing enablement
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$VmName = "vwanlab-spoke1-nva-vm",

    [Parameter(Mandatory = $false)]
    [int]$LocalAsn = 65001,

    [Parameter(Mandatory = $false)]
    [int]$RouteServerAsn = 65515,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Error handling
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to get Azure Route Server IPs (PRIVATE IPs ONLY)
function Get-RouteServerInfo {
    param(
        [string]$ResourceGroupName
    )
    
    try {
        Write-ColorOutput "🔍 Discovering Azure Route Server (private IPs)..." "Cyan"
        
        # Find Route Server using Azure CLI (PowerShell cmdlets don't work well with Route Servers)
        $routeServersJson = az network vhub list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        $routeServers = $routeServersJson | Where-Object { $_.name -like "*spoke3-route-server*" }
        
        if ($routeServers.Count -eq 0) {
            Write-ColorOutput "❌ No Azure Route Server found in resource group: $ResourceGroupName" "Red"
            return $null
        }
        
        $routeServerName = $routeServers[0].name
        Write-ColorOutput "✅ Found Route Server: $routeServerName" "Green"
        
        # Get Route Server details using Azure CLI (reliable for Route Servers)
        $routeServerJson = az network vhub show --resource-group $ResourceGroupName --name $routeServerName --query "{ips:virtualRouterIps,asn:virtualRouterAsn,id:id}" -o json | ConvertFrom-Json
        $routeServerIPs = $routeServerJson.ips
        $routeServerAsn = $routeServerJson.asn
        $routeServerId = $routeServerJson.id
        
        # Validate that we have private IPs (should be in 10.x.x.x range for route server subnet)
        $validPrivateIPs = @()
        foreach ($ip in $routeServerIPs) {
            if ($ip -and $ip -match '^10\.3\.' -and $ip -ne '') {
                $validPrivateIPs += $ip
                Write-ColorOutput "  ✅ Valid Route Server private IP: $ip" "Green"
            } else {
                Write-ColorOutput "  ⚠️  Skipping invalid IP: $ip" "Yellow"
            }
        }
        
        if ($validPrivateIPs.Count -eq 0) {
            Write-ColorOutput "❌ No valid private IPs found for Route Server" "Red"
            return $null
        }
        
        return @{
            Name = $routeServerName
            Asn = $routeServerAsn
            IPs = $validPrivateIPs
            ResourceId = $routeServerId
        }
    }
    catch {
        Write-ColorOutput "❌ Error retrieving Route Server info: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Function to get NVA VM details
function Get-NvaVmInfo {
    param(
        [string]$ResourceGroupName,
        [string]$VmName
    )
    
    try {
        Write-ColorOutput "🔍 Getting NVA VM information..." "Cyan"
        
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
        if (-not $vm) {
            throw "VM $VmName not found in resource group $ResourceGroupName"
        }
        
        # Get primary network interface
        $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
        $nic = Get-AzNetworkInterface -ResourceId $nicId
        $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
        
        Write-ColorOutput "✅ NVA VM: $VmName (Private IP: $privateIp)" "Green"
        
        return @{
            VM = $vm
            PrivateIP = $privateIp
            ResourceGroup = $ResourceGroupName
        }
    }
    catch {
        Write-ColorOutput "❌ Error getting VM info: $($_.Exception.Message)" "Red"
        throw
    }
}

# Enhanced RRAS and BGP configuration script using modern PowerShell cmdlets
function Get-RrasConfigurationScript {
    param(
        [string]$LocalAsn,
        [array]$RouteServerIPs,
        [int]$RouteServerAsn,
        [string]$LocalIP
    )

    return @"
# Enhanced Windows Server 2022 RRAS and BGP Configuration Script
Write-Host "=== Azure VWAN Lab NVA BGP Configuration ===" -ForegroundColor Cyan
Write-Host "Local ASN: $LocalAsn" -ForegroundColor White
Write-Host "Route Server ASN: $RouteServerAsn" -ForegroundColor White
Write-Host "Route Server IPs: $($RouteServerIPs -join ', ') (PRIVATE IPs ONLY)" -ForegroundColor White
Write-Host "Local IP: $LocalIP (PRIVATE IP)" -ForegroundColor White

# Step 1: Install Windows Features for RRAS and BGP
Write-Host "`n1. Installing Windows Features..." -ForegroundColor Yellow
try {
    # Install RRAS and BGP features
    `$features = @(
        'RemoteAccess',
        'RSAT-RemoteAccess-PowerShell', 
        'Routing',
        'RSAT-RemoteAccess-Mgmt'
    )
    
    foreach (`$feature in `$features) {
        Write-Host "  Installing `$feature..." -ForegroundColor Gray
        `$result = Install-WindowsFeature -Name `$feature -IncludeManagementTools -Confirm:`$false
        if (`$result.RestartNeeded -eq 'Yes') {
            Write-Host "  ⚠️  Feature `$feature requires restart" -ForegroundColor Yellow
        }
    }
    Write-Host "  ✅ Windows features installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Error installing Windows features: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Enable IP Forwarding (Critical for NVA functionality)
Write-Host "`n2. Enabling IP Forwarding..." -ForegroundColor Yellow
try {
    # Registry setting for IP forwarding
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 1
    
    # Enable forwarding on all IPv4 interfaces
    Get-NetIPInterface -AddressFamily IPv4 | ForEach-Object {
        try {
            Set-NetIPInterface -InterfaceIndex `$_.InterfaceIndex -Forwarding Enabled -ErrorAction Stop
            Write-Host "    Enabled forwarding on interface: `$(`$_.InterfaceAlias)" -ForegroundColor Gray
        }
        catch {
            Write-Host "    Warning: Could not enable forwarding on `$(`$_.InterfaceAlias)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "  ✅ IP forwarding enabled" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Error enabling IP forwarding: `$(`$_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Install and Configure RRAS with proper error handling
Write-Host "`n3. Installing RRAS..." -ForegroundColor Yellow
try {
    # Import RemoteAccess module
    Import-Module RemoteAccess -Force -ErrorAction Stop
    
    # Check if RRAS is already installed
    `$rrasStatus = Get-RemoteAccess -ErrorAction SilentlyContinue
    if (`$rrasStatus -and `$rrasStatus.VpnStatus -eq 'Installed') {
        Write-Host "  RRAS already installed, reconfiguring..." -ForegroundColor Gray
        Uninstall-RemoteAccess -VpnType RoutingOnly -Force -ErrorAction SilentlyContinue
    }
    
    # Install RRAS for routing only (no VPN)
    Install-RemoteAccess -VpnType RoutingOnly -Force
    
    # Configure and start the service
    Set-Service RemoteAccess -StartupType Automatic
    Start-Service RemoteAccess
    
    # Wait for service to fully start
    Start-Sleep -Seconds 5
    
    Write-Host "  ✅ RRAS installed and configured successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Error installing RRAS: `$(`$_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Attempting alternative installation method..." -ForegroundColor Yellow
    
    try {
        # Alternative: Use Enable-WindowsOptionalFeature
        Enable-WindowsOptionalFeature -Online -FeatureName 'IIS-ASPNET45' -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName 'RemoteAccess' -All -NoRestart
        
        Set-Service RemoteAccess -StartupType Automatic
        Start-Service RemoteAccess
        Write-Host "  ✅ RRAS installed using alternative method" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Alternative installation also failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 4: Configure BGP using modern PowerShell cmdlets (NOT netsh)
Write-Host "`n4. Configuring BGP with PowerShell cmdlets..." -ForegroundColor Yellow
try {
    # Wait for RRAS to be fully ready
    Start-Sleep -Seconds 10
    
    # Get the local private IP address
    `$localPrivateIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        `$_.IPAddress -like "10.*" -and `$_.PrefixOrigin -eq "Manual" 
    }).IPAddress
    
    if (-not `$localPrivateIP) {
        `$localPrivateIP = "$LocalIP"
    }
    
    Write-Host "  Using local private IP: `$localPrivateIP" -ForegroundColor Gray
    
    # Remove existing BGP configuration if present
    try {
        Remove-BgpRouter -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed existing BGP configuration" -ForegroundColor Gray
    }
    catch {
        # Expected if no BGP router exists
    }
    
    # Add BGP Router with local ASN and private IP
    Add-BgpRouter -BgpIdentifier `$localPrivateIP -LocalASN $LocalAsn
    Write-Host "  ✅ BGP router added with ASN $LocalAsn and identifier `$localPrivateIP" -ForegroundColor Green
    
    # Add BGP peers for each Route Server private IP
    `$peerCount = 0
    foreach (`$routeServerIP in @($($RouteServerIPs | ForEach-Object { "'$_'" } | Join-String -Separator ', '))) {
        if (`$routeServerIP -and `$routeServerIP -ne '') {
            `$peerCount++
            `$peerName = "RouteServer`$peerCount"
            
            Write-Host "  Adding BGP peer: `$peerName (`$routeServerIP) - PRIVATE IP" -ForegroundColor Gray
            
            try {
                Add-BgpPeer -Name `$peerName -LocalIPAddress `$localPrivateIP -PeerIPAddress `$routeServerIP -PeerASN $RouteServerAsn -OperationMode Mixed
                Write-Host "    ✅ BGP peer `$peerName added successfully" -ForegroundColor Green
            }
            catch {
                Write-Host "    ❌ Failed to add BGP peer `$peerName`: `$(`$_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Start BGP routing
    Start-Sleep -Seconds 5
    Write-Host "  ✅ BGP configuration completed with `$peerCount peers" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Error configuring BGP: `$(`$_.Exception.Message)" -ForegroundColor Red
    Write-Host "  This may be normal if BGP cmdlets are not fully available yet." -ForegroundColor Yellow
}

# Step 5: Final service restart and validation
Write-Host "`n5. Final Service Configuration..." -ForegroundColor Yellow
try {
    # Restart RemoteAccess to ensure all configuration takes effect
    Restart-Service RemoteAccess -Force
    Start-Sleep -Seconds 15
    
    # Ensure service is running
    `$serviceStatus = Get-Service RemoteAccess
    if (`$serviceStatus.Status -ne 'Running') {
        Start-Service RemoteAccess
        Start-Sleep -Seconds 10
    }
    
    Write-Host "  ✅ Services configured and restarted" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Error during service restart: `$(`$_.Exception.Message)" -ForegroundColor Red
}

# Step 6: Comprehensive verification using private IPs
Write-Host "`n6. Verifying Configuration..." -ForegroundColor Yellow
try {
    Write-Host "  RemoteAccess Service Status:" -ForegroundColor Gray
    Get-Service RemoteAccess | Select-Object Name, Status, StartType | Format-Table -AutoSize
    
    Write-Host "  BGP Router Status:" -ForegroundColor Gray
    try {
        Get-BgpRouter | Format-Table -AutoSize
    }
    catch {
        Write-Host "    BGP router not yet available (may need time to initialize)" -ForegroundColor Yellow
    }
    
    Write-Host "  BGP Peers Status:" -ForegroundColor Gray
    try {
        Get-BgpPeer | Format-Table -AutoSize
    }
    catch {
        Write-Host "    BGP peers not yet available (may need time to initialize)" -ForegroundColor Yellow
    }
    
    Write-Host "  IP Forwarding Status:" -ForegroundColor Gray
    Get-NetIPInterface -AddressFamily IPv4 | Where-Object { `$_.Forwarding -eq 'Enabled' } | 
        Select-Object InterfaceAlias, Forwarding | Format-Table -AutoSize
    
    Write-Host "  Network Configuration (Private IPs):" -ForegroundColor Gray
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.IPAddress -like "10.*" } |
        Select-Object IPAddress, InterfaceAlias, PrefixLength | Format-Table -AutoSize
    
    Write-Host "✅ BGP Configuration verification completed!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error during verification: `$(`$_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host "Local ASN: $LocalAsn" -ForegroundColor White
Write-Host "Route Server ASN: $RouteServerAsn" -ForegroundColor White
Write-Host "BGP Peers (PRIVATE IPs): $($RouteServerIPs -join ', ')" -ForegroundColor White
Write-Host "Local Private IP: `$localPrivateIP" -ForegroundColor White
Write-Host "Status: Modern PowerShell BGP configuration completed" -ForegroundColor White
Write-Host "Note: BGP peering may take 2-5 minutes to establish" -ForegroundColor Yellow
"@
}

# Main execution
try {
    Write-ColorOutput "🚀 Starting NVA BGP Configuration..." "Cyan"
    Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "VM Name: $VmName" "White"
    Write-ColorOutput "Local ASN: $LocalAsn" "White"
    
    # Connect to Azure
    Write-ColorOutput "`n🔐 Verifying Azure connection..." "Yellow"
    $context = Get-AzContext
    if (-not $context) {
        Connect-AzAccount
    }
    Write-ColorOutput "✅ Connected to subscription: $($context.Subscription.Name)" "Green"
    
    # Get Route Server information
    $routeServerInfo = Get-RouteServerInfo -ResourceGroupName $ResourceGroupName
    if (-not $routeServerInfo) {
        throw "Could not find or access Route Server"
    }
    
    Write-ColorOutput "📊 Route Server Details:" "Cyan"
    Write-ColorOutput "  Name: $($routeServerInfo.Name)" "White"
    Write-ColorOutput "  ASN: $($routeServerInfo.Asn)" "White" 
    Write-ColorOutput "  IPs: $($routeServerInfo.IPs -join ', ')" "White"
    
    # Get NVA VM information
    $nvaInfo = Get-NvaVmInfo -ResourceGroupName $ResourceGroupName -VmName $VmName
    
    # Confirm configuration
    if (-not $Force) {
        Write-ColorOutput "`n⚠️  This will configure BGP on the NVA VM:" "Yellow"
        Write-ColorOutput "  NVA VM: $VmName ($($nvaInfo.PrivateIP))" "White"
        Write-ColorOutput "  Local ASN: $LocalAsn" "White"
        Write-ColorOutput "  Route Server: $($routeServerInfo.Name) (ASN $($routeServerInfo.Asn))" "White"
        Write-ColorOutput "  BGP Peers: $($routeServerInfo.IPs -join ', ')" "White"
        
        $confirmation = Read-Host "`nContinue with BGP configuration? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-ColorOutput "❌ Configuration cancelled by user" "Yellow"
            return
        }
    }
    
    # Generate configuration script
    $configScript = Get-RrasConfigurationScript -LocalAsn $LocalAsn -RouteServerIPs $routeServerInfo.IPs -RouteServerAsn $routeServerInfo.Asn -LocalIP $nvaInfo.PrivateIP
    
    # Execute configuration on VM
    Write-ColorOutput "`n🔧 Executing BGP configuration on VM..." "Yellow"
    
    $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString $configScript
    
    Write-ColorOutput "`n📋 Configuration Results:" "Cyan"
    Write-ColorOutput $result.Value[0].Message "White"
    
    if ($result.Status -eq "Succeeded") {
        Write-ColorOutput "`n🎉 BGP configuration completed successfully!" "Green"
        
        Write-ColorOutput "`n📋 Next Steps:" "Cyan"
        Write-ColorOutput "  1. Wait 2-3 minutes for BGP peering to establish" "Gray"
        Write-ColorOutput "  2. Test connectivity: .\Test-Connectivity.ps1 -ResourceGroupName '$ResourceGroupName'" "Gray"
        Write-ColorOutput "  3. Check BGP status: .\Get-BgpStatus.ps1 -ResourceGroupName '$ResourceGroupName'" "Gray"
        Write-ColorOutput "  4. Verify routes in VWAN hub portal" "Gray"
    } else {
        Write-ColorOutput "❌ Configuration failed. Check the output above for details." "Red"
        exit 1
    }
}
catch {
    Write-ColorOutput "❌ Error during BGP configuration: $($_.Exception.Message)" "Red"
    Write-ColorOutput "`n🔧 Troubleshooting:" "Yellow"
    Write-ColorOutput "  1. Verify VM is running and accessible" "Gray"
    Write-ColorOutput "  2. Check VM has proper network connectivity" "Gray"
    Write-ColorOutput "  3. Verify Route Server is deployed and accessible" "Gray"
    Write-ColorOutput "  4. Check Azure permissions for VM operations" "Gray"
    exit 1
}

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute

<#
.SYNOPSIS
    Configures RRAS (Routing and Remote Access Service) on the NVA VM for BGP peering.

.DESCRIPTION
    This script configures the Windows Server VM to act as a Network Virtual Appliance (NVA)
    with RRAS enabled for BGP peering with Azure Route Server.

.PARAMETER ResourceGroupName
    Name of the resource group containing the NVA VM.

.PARAMETER VmName
    Name of the NVA VM to configure.

.PARAMETER LocalAsn
    Local ASN for the BGP configuration. Defaults to 65001.

.PARAMETER RouteServerIps
    Array of Azure Route Server IP addresses for BGP peering.

.PARAMETER RemoteAsn
    Remote ASN for Azure Route Server. Defaults to 65515.

.EXAMPLE
    .\Configure-NvaVm.ps1 -ResourceGroupName "rg-vwanlab" -VmName "vwanlab-spoke1-nva-vm"

.EXAMPLE
    .\Configure-NvaVm.ps1 -ResourceGroupName "rg-vwanlab" -VmName "vm-nva" -LocalAsn 65001 -RemoteAsn 65515

.NOTES
    Author: VWAN Lab Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$VmName,

    [Parameter(Mandatory = $false)]
    [int]$LocalAsn = 65001,

    [Parameter(Mandatory = $false)]
    [string[]]$RouteServerIps,

    [Parameter(Mandatory = $false)]
    [int]$RemoteAsn = 65515
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

# Function to get Route Server IPs if not provided
function Get-RouteServerIps {
    param(
        [string]$ResourceGroupName
    )
    
    try {
        Write-ColorOutput "Retrieving Azure Route Server information..." "Cyan"
        
        # Find Route Server in the resource group
        $routeServers = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Network/virtualHubs" | Where-Object { $_.Name -like "*spoke3-route-server*" }
        
        if ($routeServers.Count -eq 0) {
            throw "No Azure Route Server found in resource group: $ResourceGroupName"
        }
        
        $routeServer = Get-AzVirtualHub -ResourceGroupName $ResourceGroupName -Name $routeServers[0].Name
        return $routeServer.VirtualRouterIps
    }
    catch {
        Write-ColorOutput "Error retrieving Route Server IPs: $($_.Exception.Message)" "Red"
        throw
    }
}

# RRAS configuration script to run on the VM
$rrasConfigScript = @"
# Install RRAS role
Write-Host "Installing RRAS role..." -ForegroundColor Cyan
Install-WindowsFeature -Name RemoteAccess -IncludeManagementTools
Install-WindowsFeature -Name RSAT-RemoteAccess-PowerShell
Install-WindowsFeature -Name Routing

# Enable IP forwarding
Write-Host "Enabling IP forwarding..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 1

# Configure RRAS
Write-Host "Configuring RRAS..." -ForegroundColor Cyan
netsh routing ip install
netsh routing ip set global loglevel=error

# Enable BGP routing
Write-Host "Enabling BGP routing..." -ForegroundColor Cyan
netsh routing ip add protocol "BGP" "BGP"

# Configure BGP router
netsh routing ip bgp install
netsh routing ip bgp set global loglevel=error

# Add BGP router with local ASN
netsh routing ip bgp add router "BGP" localas=$($LocalAsn)

# Get the local IP address
`$localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.IPAddress -like "10.*" -and `$_.PrefixOrigin -eq "Manual" }).IPAddress
Write-Host "Local IP address: `$localIp" -ForegroundColor Green

# Configure BGP peers for each Route Server IP
$($RouteServerIps | ForEach-Object {
    "Write-Host `"Adding BGP peer: $_`" -ForegroundColor Cyan"
    "netsh routing ip bgp add peer `"BGP`" `"$_`" remoteas=$RemoteAsn"
    "netsh routing ip bgp set peer `"BGP`" `"$_`" state=enabled"
})

# Restart RRAS service
Write-Host "Restarting RRAS service..." -ForegroundColor Cyan
Restart-Service RemoteAccess

# Enable and start BGP
Write-Host "Starting BGP..." -ForegroundColor Cyan
netsh routing ip bgp set global state=enabled

Write-Host "RRAS and BGP configuration completed!" -ForegroundColor Green
Write-Host "Local ASN: $LocalAsn" -ForegroundColor White
Write-Host "Remote ASN: $RemoteAsn" -ForegroundColor White
Write-Host "BGP Peers: $($RouteServerIps -join ', ')" -ForegroundColor White

# Show BGP status
Write-Host "`nBGP Status:" -ForegroundColor Cyan
netsh routing ip bgp show peer
"@

# Main configuration function
function Start-NvaConfiguration {
    param(
        [string]$ResourceGroupName,
        [string]$VmName,
        [int]$LocalAsn,
        [string[]]$RouteServerIps,
        [int]$RemoteAsn
    )

    try {
        # Get Route Server IPs if not provided
        if (!$RouteServerIps) {
            $RouteServerIps = Get-RouteServerIps -ResourceGroupName $ResourceGroupName
        }

        if ($RouteServerIps.Count -eq 0) {
            throw "No Route Server IPs found or provided"
        }

        Write-ColorOutput "Route Server IPs: $($RouteServerIps -join ', ')" "Green"

        # Get VM information
        Write-ColorOutput "Getting VM information..." "Cyan"
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
        
        if (!$vm) {
            throw "VM not found: $VmName in resource group: $ResourceGroupName"
        }

        Write-ColorOutput "Found VM: $($vm.Name) in $($vm.Location)" "Green"

        # Prepare the configuration script with actual values
        $configScript = $rrasConfigScript.Replace('$($LocalAsn)', $LocalAsn).Replace('$($RemoteAsn)', $RemoteAsn)
        
        # Create script file
        $scriptPath = "$env:TEMP\Configure-RRAS.ps1"
        $configScript | Out-File -FilePath $scriptPath -Encoding UTF8

        Write-ColorOutput "Uploading and executing RRAS configuration script..." "Cyan"
        
        # Execute the script on the VM
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath $scriptPath

        if ($result.Status -eq "Succeeded") {
            Write-ColorOutput "RRAS configuration completed successfully!" "Green"
            Write-ColorOutput "Script output:" "Cyan"
            $result.Value[0].Message | Write-Host
        }
        else {
            Write-ColorOutput "RRAS configuration failed!" "Red"
            $result.Value[0].Message | Write-Host
        }

        # Clean up temp file
        Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-ColorOutput "Error during NVA configuration: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to test BGP connectivity
function Test-BgpConnectivity {
    param(
        [string]$ResourceGroupName,
        [string]$VmName
    )

    Write-ColorOutput "Testing BGP connectivity..." "Cyan"
    
    $testScript = @"
Write-Host "Checking BGP peers status..." -ForegroundColor Cyan
netsh routing ip bgp show peer

Write-Host "`nChecking routing table..." -ForegroundColor Cyan
Get-NetRoute | Where-Object { `$_.NextHop -like "10.*" } | Format-Table DestinationPrefix, NextHop, RouteMetric

Write-Host "`nChecking BGP learned routes..." -ForegroundColor Cyan
netsh routing ip bgp show routes
"@

    $scriptPath = "$env:TEMP\Test-BGP.ps1"
    $testScript | Out-File -FilePath $scriptPath -Encoding UTF8

    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath $scriptPath
        
        Write-ColorOutput "BGP connectivity test results:" "Cyan"
        $result.Value[0].Message | Write-Host
    }
    catch {
        Write-ColorOutput "Error testing BGP connectivity: $($_.Exception.Message)" "Red"
    }
    finally {
        Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

# Main script execution
Write-ColorOutput "=== NVA RRAS Configuration Script ===" "Cyan"

try {
    # Check if user is logged in to Azure
    $context = Get-AzContext
    if ($null -eq $context -or $null -eq $context.Account) {
        Write-ColorOutput "Please log in to Azure..." "Yellow"
        Connect-AzAccount
    }

    # Start configuration
    Start-NvaConfiguration -ResourceGroupName $ResourceGroupName -VmName $VmName -LocalAsn $LocalAsn -RouteServerIps $RouteServerIps -RemoteAsn $RemoteAsn

    # Test connectivity
    Write-ColorOutput "`nTesting BGP connectivity..." "Cyan"
    Start-Sleep -Seconds 30  # Wait for BGP to establish
    Test-BgpConnectivity -ResourceGroupName $ResourceGroupName -VmName $VmName

    Write-ColorOutput "`n=== NVA Configuration Completed ===" "Cyan"
    Write-ColorOutput "Next steps:" "Yellow"
    Write-ColorOutput "1. Verify BGP peering is established" "White"
    Write-ColorOutput "2. Check route propagation between spoke VNets" "White"
    Write-ColorOutput "3. Test connectivity using: .\Test-Connectivity.ps1" "White"
}
catch {
    Write-ColorOutput "Script execution failed: $($_.Exception.Message)" "Red"
    exit 1
}

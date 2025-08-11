#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute, Az.Network

<#
.SYNOPSIS
    Tests connectivity and routing in the Azure Virtual WAN lab environment.

.DESCRIPTION
    This script performs comprehensive connectivity tests including:
    - Ping tests between VMs
    - Route table validation
    - BGP peer status verification
    - VWAN hub routing information

.PARAMETER ResourceGroupName
    Name of the resource group containing the lab resources.

.PARAMETER TestVm1Name
    Name of the first test VM (in spoke VNet with NVA).

.PARAMETER TestVm2Name
    Name of the second test VM (in direct spoke VNet).

.PARAMETER NvaVmName
    Name of the NVA VM.

.PARAMETER Detailed
    Enables detailed output including routing tables and BGP information.

.EXAMPLE
    .\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab"

.EXAMPLE
    .\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab" -Detailed

.NOTES
    Author: VWAN Lab Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$TestVm1Name,

    [Parameter(Mandatory = $false)]
    [string]$TestVm2Name,

    [Parameter(Mandatory = $false)]
    [string]$NvaVmName,

    [Parameter(Mandatory = $false)]
    [switch]$Detailed
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

# Function to discover VMs in the resource group
function Get-LabVMs {
    param(
        [string]$ResourceGroupName
    )

    try {
        Write-ColorOutput "Discovering VMs in resource group: $ResourceGroupName" "Cyan"
        
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
        
        $labVMs = @{
            TestVm1 = $vms | Where-Object { $_.Name -like "*test1*" -or $_.Name -like "*spoke1*" } | Select-Object -First 1
            TestVm2 = $vms | Where-Object { $_.Name -like "*test2*" -or $_.Name -like "*spoke2*" } | Select-Object -First 1
            NvaVm = $vms | Where-Object { $_.Name -like "*nva*" } | Select-Object -First 1
        }

        return $labVMs
    }
    catch {
        Write-ColorOutput "Error discovering VMs: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to get VM private IP address
function Get-VmPrivateIp {
    param(
        [string]$ResourceGroupName,
        [string]$VmName
    )

    try {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
        $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
        return $nic.IpConfigurations[0].PrivateIpAddress
    }
    catch {
        Write-ColorOutput "Error getting IP for VM $VmName : $($_.Exception.Message)" "Red"
        return $null
    }
}

# Function to test ping connectivity
function Test-PingConnectivity {
    param(
        [string]$SourceVm,
        [string]$TargetIp,
        [string]$TargetName,
        [string]$ResourceGroupName
    )

    $pingScript = @"
Test-NetConnection -ComputerName '$TargetIp' -CommonTCPPort RDP -InformationLevel Detailed
ping $TargetIp -n 4
"@

    Write-ColorOutput "Testing connectivity from $SourceVm to $TargetName ($TargetIp)..." "Cyan"
    
    try {
        $scriptPath = "$env:TEMP\Test-Ping.ps1"
        $pingScript | Out-File -FilePath $scriptPath -Encoding UTF8

        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $SourceVm -CommandId 'RunPowerShellScript' -ScriptPath $scriptPath

        if ($result.Status -eq "Succeeded") {
            $output = $result.Value[0].Message
            if ($output -match "PingSucceeded.*True" -or $output -match "TTL=") {
                Write-ColorOutput "✓ Connectivity successful: $SourceVm → $TargetName" "Green"
            }
            else {
                Write-ColorOutput "✗ Connectivity failed: $SourceVm → $TargetName" "Red"
            }
            
            if ($Detailed) {
                Write-ColorOutput "Detailed output:" "Yellow"
                $output | Write-Host
            }
        }
        else {
            Write-ColorOutput "✗ Test execution failed: $SourceVm → $TargetName" "Red"
        }

        Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-ColorOutput "Error testing connectivity: $($_.Exception.Message)" "Red"
    }
}

# Function to check routing table
function Get-VmRoutingTable {
    param(
        [string]$VmName,
        [string]$ResourceGroupName
    )

    $routeScript = @"
Write-Host "=== Routing Table for $VmName ===" -ForegroundColor Cyan
Get-NetRoute | Where-Object { `$_.DestinationPrefix -like "10.*" -or `$_.DestinationPrefix -eq "0.0.0.0/0" } | 
    Sort-Object DestinationPrefix | 
    Format-Table DestinationPrefix, NextHop, RouteMetric, InterfaceAlias -AutoSize

Write-Host "`n=== Network Interfaces ===" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.IPAddress -like "10.*" } | 
    Format-Table IPAddress, InterfaceAlias, PrefixLength -AutoSize
"@

    Write-ColorOutput "Getting routing table for $VmName..." "Cyan"
    
    try {
        $scriptPath = "$env:TEMP\Get-Routes.ps1"
        $routeScript | Out-File -FilePath $scriptPath -Encoding UTF8

        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath $scriptPath

        if ($result.Status -eq "Succeeded") {
            $result.Value[0].Message | Write-Host
        }

        Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-ColorOutput "Error getting routing table: $($_.Exception.Message)" "Red"
    }
}

# Function to check BGP status on NVA
function Get-BgpStatus {
    param(
        [string]$NvaVmName,
        [string]$ResourceGroupName
    )

    $bgpScript = @"
Write-Host "=== BGP Peer Status ===" -ForegroundColor Cyan
netsh routing ip bgp show peer

Write-Host "`n=== BGP Learned Routes ===" -ForegroundColor Cyan
netsh routing ip bgp show routes

Write-Host "`n=== RRAS Service Status ===" -ForegroundColor Cyan
Get-Service RemoteAccess | Format-Table Name, Status, StartType

Write-Host "`n=== BGP Global Configuration ===" -ForegroundColor Cyan
netsh routing ip bgp show global
"@

    Write-ColorOutput "Getting BGP status from NVA..." "Cyan"
    
    try {
        $scriptPath = "$env:TEMP\Get-BGP.ps1"
        $bgpScript | Out-File -FilePath $scriptPath -Encoding UTF8

        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $NvaVmName -CommandId 'RunPowerShellScript' -ScriptPath $scriptPath

        if ($result.Status -eq "Succeeded") {
            $result.Value[0].Message | Write-Host
        }

        Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-ColorOutput "Error getting BGP status: $($_.Exception.Message)" "Red"
    }
}

# Function to check VWAN hub information
function Get-VwanHubInfo {
    param(
        [string]$ResourceGroupName
    )

    try {
        Write-ColorOutput "Getting VWAN hub information..." "Cyan"
        
        # Get Virtual WAN
        $vwan = Get-AzVirtualWan -ResourceGroupName $ResourceGroupName
        if ($vwan) {
            Write-ColorOutput "Virtual WAN: $($vwan.Name)" "Green"
            Write-ColorOutput "  Type: $($vwan.Type)" "White"
            Write-ColorOutput "  Allow Branch to Branch: $($vwan.AllowBranchToBranchTraffic)" "White"
        }

        # Get Virtual Hub
        $hub = Get-AzVirtualHub -ResourceGroupName $ResourceGroupName
        if ($hub) {
            Write-ColorOutput "Virtual Hub: $($hub.Name)" "Green"
            Write-ColorOutput "  Address Prefix: $($hub.AddressPrefix)" "White"
            Write-ColorOutput "  Virtual Router ASN: $($hub.VirtualRouterAsn)" "White"
            Write-ColorOutput "  Virtual Router IPs: $($hub.VirtualRouterIps -join ', ')" "White"
        }

        # Get VNet connections
        $connections = Get-AzVirtualHubVnetConnection -ResourceGroupName $ResourceGroupName -VirtualHubName $hub.Name
        if ($connections) {
            Write-ColorOutput "VNet Connections:" "Green"
            foreach ($conn in $connections) {
                Write-ColorOutput "  - $($conn.Name): $($conn.ConnectionStatus)" "White"
            }
        }
    }
    catch {
        Write-ColorOutput "Error getting VWAN hub information: $($_.Exception.Message)" "Red"
    }
}

# Main testing function
function Start-ConnectivityTests {
    param(
        [string]$ResourceGroupName,
        [hashtable]$VMs,
        [bool]$DetailedOutput
    )

    Write-ColorOutput "=== Starting Connectivity Tests ===" "Cyan"

    # Get VM IP addresses
    $vm1Ip = if ($VMs.TestVm1) { Get-VmPrivateIp -ResourceGroupName $ResourceGroupName -VmName $VMs.TestVm1.Name } else { $null }
    $vm2Ip = if ($VMs.TestVm2) { Get-VmPrivateIp -ResourceGroupName $ResourceGroupName -VmName $VMs.TestVm2.Name } else { $null }
    $nvaIp = if ($VMs.NvaVm) { Get-VmPrivateIp -ResourceGroupName $ResourceGroupName -VmName $VMs.NvaVm.Name } else { $null }

    Write-ColorOutput "VM IP Addresses:" "Yellow"
    if ($vm1Ip) { Write-ColorOutput "  $($VMs.TestVm1.Name): $vm1Ip" "White" }
    if ($vm2Ip) { Write-ColorOutput "  $($VMs.TestVm2.Name): $vm2Ip" "White" }
    if ($nvaIp) { Write-ColorOutput "  $($VMs.NvaVm.Name): $nvaIp" "White" }

    # Test connectivity between VMs
    Write-ColorOutput "`n=== Connectivity Tests ===" "Cyan"
    
    if ($VMs.TestVm1 -and $VMs.TestVm2 -and $vm1Ip -and $vm2Ip) {
        Test-PingConnectivity -SourceVm $VMs.TestVm1.Name -TargetIp $vm2Ip -TargetName $VMs.TestVm2.Name -ResourceGroupName $ResourceGroupName
        Test-PingConnectivity -SourceVm $VMs.TestVm2.Name -TargetIp $vm1Ip -TargetName $VMs.TestVm1.Name -ResourceGroupName $ResourceGroupName
    }

    if ($VMs.TestVm1 -and $VMs.NvaVm -and $vm1Ip -and $nvaIp) {
        Test-PingConnectivity -SourceVm $VMs.TestVm1.Name -TargetIp $nvaIp -TargetName $VMs.NvaVm.Name -ResourceGroupName $ResourceGroupName
    }

    if ($VMs.TestVm2 -and $VMs.NvaVm -and $vm2Ip -and $nvaIp) {
        Test-PingConnectivity -SourceVm $VMs.TestVm2.Name -TargetIp $nvaIp -TargetName $VMs.NvaVm.Name -ResourceGroupName $ResourceGroupName
    }

    # Detailed information if requested
    if ($DetailedOutput) {
        Write-ColorOutput "`n=== Detailed Routing Information ===" "Cyan"
        
        if ($VMs.TestVm1) {
            Get-VmRoutingTable -VmName $VMs.TestVm1.Name -ResourceGroupName $ResourceGroupName
        }
        
        if ($VMs.TestVm2) {
            Get-VmRoutingTable -VmName $VMs.TestVm2.Name -ResourceGroupName $ResourceGroupName
        }
        
        if ($VMs.NvaVm) {
            Write-ColorOutput "`n=== BGP Status on NVA ===" "Cyan"
            Get-BgpStatus -NvaVmName $VMs.NvaVm.Name -ResourceGroupName $ResourceGroupName
        }

        Write-ColorOutput "`n=== VWAN Hub Information ===" "Cyan"
        Get-VwanHubInfo -ResourceGroupName $ResourceGroupName
    }
}

# Main script execution
Write-ColorOutput "=== Azure Virtual WAN Lab Connectivity Tests ===" "Cyan"

try {
    # Check if user is logged in to Azure
    $context = Get-AzContext
    if ($null -eq $context -or $null -eq $context.Account) {
        Write-ColorOutput "Please log in to Azure..." "Yellow"
        Connect-AzAccount
    }

    # Discover or use provided VM names
    $labVMs = Get-LabVMs -ResourceGroupName $ResourceGroupName

    if ($TestVm1Name) { $labVMs.TestVm1 = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $TestVm1Name }
    if ($TestVm2Name) { $labVMs.TestVm2 = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $TestVm2Name }
    if ($NvaVmName) { $labVMs.NvaVm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $NvaVmName }

    # Validate that we found the VMs
    $foundVMs = @()
    if ($labVMs.TestVm1) { $foundVMs += "Test VM 1: $($labVMs.TestVm1.Name)" }
    if ($labVMs.TestVm2) { $foundVMs += "Test VM 2: $($labVMs.TestVm2.Name)" }
    if ($labVMs.NvaVm) { $foundVMs += "NVA VM: $($labVMs.NvaVm.Name)" }

    if ($foundVMs.Count -eq 0) {
        throw "No VMs found in resource group: $ResourceGroupName"
    }

    Write-ColorOutput "Found VMs:" "Green"
    $foundVMs | ForEach-Object { Write-ColorOutput "  $_" "White" }

    # Start connectivity tests
    Start-ConnectivityTests -ResourceGroupName $ResourceGroupName -VMs $labVMs -DetailedOutput $Detailed.IsPresent

    Write-ColorOutput "`n=== Connectivity Tests Completed ===" "Cyan"
}
catch {
    Write-ColorOutput "Script execution failed: $($_.Exception.Message)" "Red"
    exit 1
}

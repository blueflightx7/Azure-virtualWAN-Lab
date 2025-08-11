#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute, Az.Network

<#
.SYNOPSIS
    Check BGP status and peering information for Azure VWAN Lab NVA

.DESCRIPTION
    This script checks the BGP configuration and peering status of the NVA VM,
    including connectivity to Azure Route Server and routing information.

.PARAMETER ResourceGroupName
    Name of the resource group containing the NVA VM

.PARAMETER VmName  
    Name of the NVA VM to check (default: vwanlab-spoke1-nva-vm)

.EXAMPLE
    .\Get-BgpStatus.ps1 -ResourceGroupName "rg-vwanlab-demo"

.NOTES
    Author: Azure VWAN Lab Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$VmName = "vwanlab-spoke1-nva-vm"
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

# Enhanced BGP status check script using modern PowerShell cmdlets
$bgpStatusScript = @"
try {
    Write-Host "=== Enhanced BGP Status Check ===" -ForegroundColor Cyan
    Write-Host "Starting BGP analysis..." -ForegroundColor Yellow

    # Check RRAS service status
    Write-Host "`n1. RRAS Service Status:" -ForegroundColor Yellow
    try {
        `$rras = Get-Service RemoteAccess -ErrorAction Stop
        Write-Host "  Service Name: `$(`$rras.Name)" -ForegroundColor White
        Write-Host "  Status: `$(`$rras.Status)" -ForegroundColor White
        Write-Host "  Start Type: `$(`$rras.StartType)" -ForegroundColor White
        
        if (`$rras.Status -eq 'Running') {
            Write-Host "  ✅ RRAS Service is running" -ForegroundColor Green
        } else {
            Write-Host "  ❌ RRAS Service is NOT running" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ Error checking RRAS service: `$(`$_.Exception.Message)" -ForegroundColor Red
    }

    # Check BGP router configuration
    Write-Host "`n2. BGP Router Configuration:" -ForegroundColor Yellow
    try {
        if (Get-Command Get-BgpRouter -ErrorAction SilentlyContinue) {
            `$bgpRouter = Get-BgpRouter -ErrorAction Stop
            if (`$bgpRouter) {
                Write-Host "  ✅ BGP Router configured:" -ForegroundColor Green
                Write-Host "    BGP Identifier: `$(`$bgpRouter.BgpIdentifier)" -ForegroundColor White
                Write-Host "    Local ASN: `$(`$bgpRouter.LocalASN)" -ForegroundColor White
            } else {
                Write-Host "  ❌ No BGP router configured" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ Get-BgpRouter cmdlet not available" -ForegroundColor Red
            Write-Host "  This indicates BGP PowerShell module is not installed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌ Error retrieving BGP router: `$(`$_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Trying netsh alternative..." -ForegroundColor Yellow
        try {
            `$netshOutput = netsh routing ip bgp show global 2>&1
            if (`$netshOutput -and (`$netshOutput -notlike "*The following command was not found*")) {
                Write-Host "  Netsh BGP output:" -ForegroundColor Gray
                Write-Host "  `$netshOutput" -ForegroundColor Gray
            } else {
                Write-Host "  ❌ Netsh BGP commands also not available" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ❌ Netsh commands failed: `$(`$_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Check BGP peers
    Write-Host "`n3. BGP Peer Status:" -ForegroundColor Yellow
    try {
        if (Get-Command Get-BgpPeer -ErrorAction SilentlyContinue) {
            `$bgpPeers = Get-BgpPeer -ErrorAction Stop
            if (`$bgpPeers) {
                Write-Host "  ✅ BGP Peers Found (`$(`$bgpPeers.Count) peer(s)):" -ForegroundColor Green
                foreach (`$peer in `$bgpPeers) {
                    Write-Host "    Peer: `$(`$peer.Name)" -ForegroundColor White
                    Write-Host "      Local IP: `$(`$peer.LocalIPAddress)" -ForegroundColor Gray
                    Write-Host "      Peer IP: `$(`$peer.PeerIPAddress)" -ForegroundColor Gray
                    Write-Host "      Peer ASN: `$(`$peer.PeerASN)" -ForegroundColor Gray
                    Write-Host "      Status: `$(`$peer.ConnectivityStatus)" -ForegroundColor Gray
                }
            } else {
                Write-Host "  ❌ No BGP peers configured" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ Get-BgpPeer cmdlet not available" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ Error retrieving BGP peers: `$(`$_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Trying netsh alternative..." -ForegroundColor Yellow
        try {
            `$peerOutput = netsh routing ip bgp show peer 2>&1
            if (`$peerOutput -and (`$peerOutput -notlike "*The following command was not found*")) {
                Write-Host "  Netsh BGP peer output:" -ForegroundColor Gray
                Write-Host "  `$peerOutput" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  ❌ Netsh peer commands failed" -ForegroundColor Red
        }
    }

    # Test Route Server connectivity
    Write-Host "`n4. Route Server Connectivity:" -ForegroundColor Yellow
    `$routeServerIps = @("10.3.0.68", "10.3.0.69")  # Actual Route Server IPs
    foreach (`$ip in `$routeServerIps) {
        Write-Host "  Testing `${ip}:" -ForegroundColor Gray
        try {
            `$ping = Test-Connection -ComputerName `$ip -Count 1 -Quiet -ErrorAction Stop
            if (`$ping) {
                Write-Host "    ✅ ICMP: SUCCESS" -ForegroundColor Green
            } else {
                Write-Host "    ❌ ICMP: FAILED" -ForegroundColor Red
            }
        } catch {
            Write-Host "    ❌ ICMP: ERROR - `$(`$_.Exception.Message)" -ForegroundColor Red
        }
        
        try {
            `$tcp = Test-NetConnection -ComputerName `$ip -Port 179 -WarningAction SilentlyContinue -ErrorAction Stop
            if (`$tcp.TcpTestSucceeded) {
                Write-Host "    ✅ BGP Port 179: SUCCESS" -ForegroundColor Green
            } else {
                Write-Host "    ❌ BGP Port 179: FAILED" -ForegroundColor Red
            }
        } catch {
            Write-Host "    ❌ BGP Port 179: ERROR - `$(`$_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n=== BGP Status Check Complete ===" -ForegroundColor Cyan
} catch {
    Write-Host "Fatal error in BGP status script: `$(`$_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: `$(`$_.Exception)" -ForegroundColor Gray
}
"@

# Main execution
try {
    Write-ColorOutput "🔍 Checking BGP Status..." "Cyan"
    Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "VM Name: $VmName" "White"
    
    # Connect to Azure
    $context = Get-AzContext
    if (-not $context) {
        Connect-AzAccount
    }
    
    # Execute status check on VM
    Write-ColorOutput "`n📊 Running BGP status check on VM..." "Yellow"
    
    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString $bgpStatusScript
        
        Write-ColorOutput "`n📋 BGP Status Results:" "Cyan"
        
        # Debug: Show what we got back
        Write-ColorOutput "Debug - Result Status: $($result.Status)" "Gray"
        Write-ColorOutput "Debug - Value Count: $($result.Value.Count)" "Gray"
        
        if ($result.Value -and $result.Value.Count -gt 0) {
            foreach ($output in $result.Value) {
                if ($output.Message) {
                    Write-ColorOutput $output.Message "White"
                } else {
                    Write-ColorOutput "No message in this output object" "Yellow"
                }
            }
        } else {
            Write-ColorOutput "❌ No output received from VM command execution" "Red"
            Write-ColorOutput "This could indicate:" "Yellow"
            Write-ColorOutput "  1. VM Guest Agent is not running" "Gray"
            Write-ColorOutput "  2. PowerShell execution policy restrictions" "Gray"
            Write-ColorOutput "  3. Network connectivity issues" "Gray"
            Write-ColorOutput "  4. BGP PowerShell modules not available" "Gray"
            
            # Try a simple test command
            Write-ColorOutput "`n🔧 Trying simple test command..." "Yellow"
            $testResult = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString "Write-Host 'VM is accessible'; Get-Service RemoteAccess"
            
            if ($testResult.Value -and $testResult.Value[0].Message) {
                Write-ColorOutput "✅ Basic VM access works:" "Green"
                Write-ColorOutput $testResult.Value[0].Message "White"
            } else {
                Write-ColorOutput "❌ Even basic VM access failed" "Red"
            }
        }
        
        if ($result.Status -eq "Succeeded") {
            Write-ColorOutput "`n✅ BGP status check command submitted successfully!" "Green"
        } else {
            Write-ColorOutput "❌ BGP status check failed with status: $($result.Status)" "Red"
        }
    } catch {
        Write-ColorOutput "❌ Error executing command on VM: $($_.Exception.Message)" "Red"
        Write-ColorOutput "Full error: $($_.Exception)" "Gray"
    }
}
catch {
    Write-ColorOutput "❌ Error checking BGP status: $($_.Exception.Message)" "Red"
    Write-ColorOutput "`n🔧 Troubleshooting:" "Yellow"
    Write-ColorOutput "  1. Verify VM is running" "Gray"
    Write-ColorOutput "  2. Check VM network connectivity" "Gray"
    Write-ColorOutput "  3. Verify Azure permissions" "Gray"
}

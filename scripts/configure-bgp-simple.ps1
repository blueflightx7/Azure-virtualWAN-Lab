Write-Host "=== Configuring BGP on NVA VM ===" -ForegroundColor Cyan

# BGP Configuration Parameters
$localIP = "10.1.0.4"
$routeServerIPs = @("10.3.0.68", "10.3.0.69")
$localASN = 65001
$remoteASN = 65515

Write-Host "Local IP: $localIP" -ForegroundColor Yellow
Write-Host "Local ASN: $localASN" -ForegroundColor Yellow
Write-Host "Route Server IPs: $($routeServerIPs -join ', ')" -ForegroundColor Yellow
Write-Host "Route Server ASN: $remoteASN" -ForegroundColor Yellow

# Step 1: Remove existing BGP configuration
Write-Host "`nStep 1: Removing existing BGP configuration..." -ForegroundColor Yellow
try {
    Remove-BgpRouter -Force -ErrorAction SilentlyContinue
    Write-Host "  ✅ Removed existing BGP configuration" -ForegroundColor Green
} catch {
    Write-Host "  ℹ️ No existing BGP configuration found" -ForegroundColor Cyan
}

# Step 2: Add BGP Router
Write-Host "`nStep 2: Adding BGP Router..." -ForegroundColor Yellow
try {
    Add-BgpRouter -BgpIdentifier $localIP -LocalASN $localASN
    Write-Host "  ✅ BGP Router added successfully" -ForegroundColor Green
    Write-Host "    BGP Identifier: $localIP" -ForegroundColor Gray
    Write-Host "    Local ASN: $localASN" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ Failed to add BGP Router: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Add BGP Peers
Write-Host "`nStep 3: Adding BGP Peers..." -ForegroundColor Yellow
$peerCount = 0
foreach ($routeServerIP in $routeServerIPs) {
    $peerCount++
    $peerName = "RouteServer$peerCount"
    
    Write-Host "  Adding peer: $peerName ($routeServerIP)" -ForegroundColor Gray
    try {
        Add-BgpPeer -Name $peerName -LocalIPAddress $localIP -PeerIPAddress $routeServerIP -PeerASN $remoteASN -OperationMode Mixed
        Write-Host "    ✅ BGP Peer $peerName added successfully" -ForegroundColor Green
    } catch {
        Write-Host "    ❌ Failed to add BGP Peer $peerName`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 4: Verify BGP configuration
Write-Host "`nStep 4: Verifying BGP configuration..." -ForegroundColor Yellow
try {
    $bgpRouter = Get-BgpRouter
    Write-Host "  ✅ BGP Router Status:" -ForegroundColor Green
    Write-Host "    BGP Identifier: $($bgpRouter.BgpIdentifier)" -ForegroundColor Gray
    Write-Host "    Local ASN: $($bgpRouter.LocalASN)" -ForegroundColor Gray
    
    $bgpPeers = Get-BgpPeer
    Write-Host "  ✅ BGP Peers ($($bgpPeers.Count)):" -ForegroundColor Green
    foreach ($peer in $bgpPeers) {
        Write-Host "    Peer: $($peer.Name) → $($peer.PeerIPAddress) (ASN: $($peer.PeerASN))" -ForegroundColor Gray
        Write-Host "    Status: $($peer.ConnectivityStatus)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ❌ Error verifying BGP configuration: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Test connectivity to Route Server
Write-Host "`nStep 5: Testing Route Server connectivity..." -ForegroundColor Yellow
foreach ($routeServerIP in $routeServerIPs) {
    Write-Host "  Testing $routeServerIP..." -ForegroundColor Gray
    
    # Test BGP port
    try {
        $tcpTest = Test-NetConnection -ComputerName $routeServerIP -Port 179 -WarningAction SilentlyContinue
        if ($tcpTest.TcpTestSucceeded) {
            Write-Host "    ✅ BGP Port 179: Connected" -ForegroundColor Green
        } else {
            Write-Host "    ❌ BGP Port 179: Failed to connect" -ForegroundColor Red
        }
    } catch {
        Write-Host "    ❌ BGP Port 179: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== BGP Configuration Complete ===" -ForegroundColor Cyan
Write-Host "BGP peering may take 2-5 minutes to establish." -ForegroundColor Yellow

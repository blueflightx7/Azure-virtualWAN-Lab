#Requires -Version 5.1
<#
.SYNOPSIS
    Check Azure VWAN Lab BGP Architecture and Configuration

.DESCRIPTION
    This script examines your Azure VWAN Lab deployment to verify:
    1. VWAN Hub configuration and connections
    2. Azure Route Server deployment and BGP peers
    3. NVA VM BGP configuration
    4. Expected vs actual BGP topology

.PARAMETER ResourceGroupName
    Name of the resource group containing the lab resources

.EXAMPLE
    .\Check-VwanBgpArchitecture.ps1 -ResourceGroupName "rg-vwanlab-demo2"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-ColorOutput "Connecting to Azure..." "Yellow"
            Connect-AzAccount
        }
        Write-ColorOutput "✅ Connected to Azure: $($context.Account.Id)" "Green"
        return $true
    } catch {
        Write-ColorOutput "❌ Failed to connect to Azure: $($_.Exception.Message)" "Red"
        return $false
    }
}

Write-ColorOutput "🔍 Azure VWAN Lab BGP Architecture Analysis" "Magenta"
Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
Write-ColorOutput ""

if (-not (Test-AzureLogin)) {
    exit 1
}

try {
    # Check if resource group exists
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    Write-ColorOutput "✅ Resource Group Found: $($rg.ResourceGroupName) ($($rg.Location))" "Green"
} catch {
    Write-ColorOutput "❌ Resource Group '$ResourceGroupName' not found" "Red"
    exit 1
}

Write-ColorOutput "`n=== 1. VWAN Hub Analysis ===" "Cyan"
# First check for Virtual WAN
$vwans = Get-AzVirtualWan -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($vwans) {
    foreach ($vwan in $vwans) {
        Write-ColorOutput "✅ Virtual WAN Found: $($vwan.Name)" "Green"
        Write-ColorOutput "  Location: $($vwan.Location)" "Gray"
        Write-ColorOutput "  Type: $($vwan.Type)" "Gray"
        Write-ColorOutput "  Allow Branch-to-Branch: $($vwan.AllowBranchToBranchTraffic)" "Gray"
    }
} else {
    Write-ColorOutput "⚠️  No Virtual WAN found in resource group" "Yellow"
    # Try to find VWAN in subscription
    $allVwans = Get-AzVirtualWan -ErrorAction SilentlyContinue
    if ($allVwans) {
        Write-ColorOutput "ℹ️  Found VWANs in other resource groups:" "Cyan"
        foreach ($vwan in $allVwans) {
            Write-ColorOutput "    $($vwan.Name) in $($vwan.ResourceGroupName)" "Gray"
        }
    }
}

# Then check for VWAN Hubs
# Note: Get-AzVirtualHub fails when Route Servers are present, so we need to be more specific
try {
    # First get all virtual hub resources
    $hubResources = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Network/virtualHubs" -ErrorAction SilentlyContinue
    
    # Filter out Route Servers (they contain "route-server" in the name)
    $vwanHubResources = $hubResources | Where-Object { $_.Name -notlike "*route-server*" }
    
    $vwanHubs = @()
    foreach ($hubResource in $vwanHubResources) {
        try {
            $hub = Get-AzVirtualHub -ResourceGroupName $ResourceGroupName -Name $hubResource.Name -ErrorAction SilentlyContinue
            if ($hub) {
                $vwanHubs += $hub
            }
        } catch {
            Write-ColorOutput "⚠️  Found hub resource $($hubResource.Name) but could not get details" "Yellow"
        }
    }
    
    if ($vwanHubs.Count -gt 0) {
        foreach ($hub in $vwanHubs) {
            Write-ColorOutput "✅ VWAN Hub Found: $($hub.Name)" "Green"
        Write-ColorOutput "  Location: $($hub.Location)" "Gray"
        Write-ColorOutput "  Address Prefix: $($hub.AddressPrefix)" "Gray"
        Write-ColorOutput "  Virtual Router ASN: $($hub.VirtualRouterAsn)" "Gray"
        
        # Check for BGP connections in VWAN Hub
        Write-ColorOutput "  BGP Connections in VWAN Hub:" "Yellow"
        try {
            $bgpConnections = Get-AzVirtualHubBgpConnection -ResourceGroupName $ResourceGroupName -VirtualHubName $hub.Name -ErrorAction SilentlyContinue
            if ($bgpConnections) {
                foreach ($conn in $bgpConnections) {
                    Write-ColorOutput "    ✅ BGP Peer: $($conn.Name) (ASN: $($conn.PeerAsn), IP: $($conn.PeerIp))" "Green"
                }
            } else {
                Write-ColorOutput "    ✅ No BGP connections found in VWAN Hub (this is normal)" "Green"
                Write-ColorOutput "    ℹ️  Note: VWAN typically doesn't have direct BGP peers - uses Route Server instead" "Cyan"
            }
        } catch {
            Write-ColorOutput "    ✅ No BGP connections in VWAN Hub (this is expected)" "Green"
        }
        
        # Check VWAN Hub connections
        Write-ColorOutput "  VWAN Hub Connections:" "Yellow"
        try {
            $hubConnections = Get-AzVirtualHubVnetConnection -ResourceGroupName $ResourceGroupName -VirtualHubName $hub.Name -ErrorAction SilentlyContinue
            if ($hubConnections) {
                foreach ($conn in $hubConnections) {
                    Write-ColorOutput "    ✅ VNet Connection: $($conn.Name)" "Green"
                    Write-ColorOutput "      Remote VNet: $($conn.RemoteVirtualNetwork.Id.Split('/')[-1])" "Gray"
                }
            } else {
                Write-ColorOutput "    ⚠️  No VNet connections found" "Yellow"
            }
        } catch {
            Write-ColorOutput "    ⚠️  Could not retrieve hub connections: $($_.Exception.Message)" "Yellow"
        }
        }
    } else {
        Write-ColorOutput "❌ No VWAN Hubs found in resource group (only Route Servers found)" "Red"
        
        # Show what virtual hub resources we did find
        if ($hubResources.Count -gt 0) {
            Write-ColorOutput "ℹ️  Found virtual hub resources (but they are Route Servers):" "Cyan"
            foreach ($resource in $hubResources) {
                if ($resource.Name -like "*route-server*") {
                    Write-ColorOutput "    📍 Route Server: $($resource.Name)" "Gray"
                } else {
                    Write-ColorOutput "    🏢 Unknown Hub: $($resource.Name)" "Gray"
                }
            }
        }
    }
} catch {
    Write-ColorOutput "❌ Error checking for VWAN Hubs: $($_.Exception.Message)" "Red"
    
    # Fallback: Try to get virtual hub resources directly
    try {
        $hubResources = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Network/virtualHubs" -ErrorAction SilentlyContinue
        if ($hubResources) {
            Write-ColorOutput "ℹ️  Found virtual hub resources (checking individually):" "Cyan"
            foreach ($resource in $hubResources) {
                if ($resource.Name -like "*route-server*") {
                    Write-ColorOutput "    📍 Route Server: $($resource.Name)" "Gray"
                } else {
                    Write-ColorOutput "    🏢 VWAN Hub: $($resource.Name)" "Gray"
                    # This is likely a real VWAN Hub
                    Write-ColorOutput "    ✅ Found potential VWAN Hub: $($resource.Name)" "Green"
                }
            }
        }
    } catch {
        Write-ColorOutput "❌ Could not retrieve any virtual hub resources" "Red"
    }
}

Write-ColorOutput "`n=== 2. Azure Route Server Analysis ===" "Cyan"
# Look for Azure Route Server using the specific naming pattern: vwanlab-spoke3-route-server
try {
    # Method 1: Try Get-AzRouteServer first
    $routeServers = Get-AzRouteServer -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    
    # Method 2: If that fails, look for resources with route-server naming pattern
    if (-not $routeServers) {
        Write-ColorOutput "Searching for Route Server by name pattern..." "Yellow"
        $allResources = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Network/virtualHubs" -ErrorAction SilentlyContinue
        $routeServers = $allResources | Where-Object { $_.Name -like "*route-server*" -or $_.Name -like "*spoke3*" }
        
        # Method 3: Also try searching for RouteServer resources directly
        if (-not $routeServers) {
            $routeServerResources = Get-AzResource -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { 
                $_.ResourceType -eq "Microsoft.Network/virtualHubs" -and $_.Name -like "*route-server*" 
            }
            if ($routeServerResources) {
                foreach ($rsResource in $routeServerResources) {
                    try {
                        $rs = Get-AzRouteServer -ResourceGroupName $ResourceGroupName -Name $rsResource.Name -ErrorAction SilentlyContinue
                        if ($rs) { $routeServers += $rs }
                    } catch {
                        Write-ColorOutput "    Found resource $($rsResource.Name) but could not get details" "Yellow"
                    }
                }
            }
        }
    }
    
    if ($routeServers) {
        foreach ($rs in $routeServers) {
            Write-ColorOutput "✅ Azure Route Server Found: $($rs.Name)" "Green"
            
            # Try to get Route Server details
            try {
                if ($rs.VirtualRouterAsn) {
                    Write-ColorOutput "  Virtual Router ASN: $($rs.VirtualRouterAsn)" "Gray"
                }
                if ($rs.VirtualRouterIps) {
                    Write-ColorOutput "  Virtual Router IPs: $($rs.VirtualRouterIps -join ', ')" "Gray"
                }
                if ($rs.HostedSubnet) {
                    Write-ColorOutput "  Hosted Subnet: $($rs.HostedSubnet)" "Gray"
                }
                if ($null -ne $rs.AllowBranchToBranchTraffic) {
                    Write-ColorOutput "  Allow Branch to Branch Traffic: $($rs.AllowBranchToBranchTraffic)" "Gray"
                }
            } catch {
                Write-ColorOutput "  ⚠️  Could not get detailed Route Server properties" "Yellow"
            }
            
            # Check BGP connections to Route Server
            Write-ColorOutput "  BGP Peers on Route Server:" "Yellow"
            try {
                # First try to get the Route Server object to check if it supports BGP peers
                $routeServerObject = Get-AzRouteServer -ResourceGroupName $ResourceGroupName -RouteServerName $rs.Name -ErrorAction SilentlyContinue
                
                if ($routeServerObject) {
                    # Try to get BGP peer information using REST API or alternative method
                    # Since Get-AzRouteServerPeer requires peer name, we need to find peers first
                    
                    # Method 1: Try to list BGP connections through the route server properties
                    $bgpConnectionsFound = $false
                    
                    # Check if we can find any BGP peer configuration in the route server
                    if ($routeServerObject.BgpConnections -and $routeServerObject.BgpConnections.Count -gt 0) {
                        foreach ($bgpConn in $routeServerObject.BgpConnections) {
                            Write-ColorOutput "    ✅ BGP Connection: $($bgpConn.Name)" "Green"
                            $bgpConnectionsFound = $true
                        }
                    }
                    
                    # Method 2: Try to find known peer names based on expected lab configuration
                    if (-not $bgpConnectionsFound) {
                        # Try common peer names that might exist
                        $commonPeerNames = @("nva-peer", "spoke1-nva", "bgp-peer", "nva-bgp-peer", "nva-connection")
                        
                        foreach ($peerName in $commonPeerNames) {
                            try {
                                $peer = Get-AzRouteServerPeer -ResourceGroupName $ResourceGroupName -RouteServerName $rs.Name -PeerName $peerName -ErrorAction SilentlyContinue
                                if ($peer) {
                                    Write-ColorOutput "    ✅ BGP Peer Found: $($peer.Name)" "Green"
                                    Write-ColorOutput "      Peer ASN: $($peer.PeerAsn)" "Gray"
                                    Write-ColorOutput "      Peer IP: $($peer.PeerIp)" "Gray"
                                    Write-ColorOutput "      Connection State: $($peer.State)" "Gray"
                                    $bgpConnectionsFound = $true
                                }
                            } catch {
                                # Silently continue to try next peer name
                            }
                        }
                    }
                    
                    if (-not $bgpConnectionsFound) {
                        Write-ColorOutput "    ❌ No BGP peers configured on Route Server" "Red"
                        Write-ColorOutput "    🔧 This means Phase 5 (BGP Peering) hasn't been deployed" "Yellow"
                        Write-ColorOutput "    💡 Expected peer: NVA VM with ASN 65001" "Cyan"
                    }
                } else {
                    Write-ColorOutput "    ⚠️  Could not access Route Server details" "Yellow"
                }
            } catch {
                Write-ColorOutput "    ⚠️  Error checking Route Server BGP peers: $($_.Exception.Message)" "Yellow"
                Write-ColorOutput "    💡 This usually means no BGP peers are configured yet" "Cyan"
            }
        }
    } else {
        Write-ColorOutput "❌ No Azure Route Server found" "Red"
        Write-ColorOutput "🔧 This means Phase 3 (Route Server) hasn't been deployed" "Yellow"
        Write-ColorOutput "💡 Expected: vwanlab-spoke3-route-server in spoke3 VNet" "Cyan"
        
        # Alternative check - look for Route Server as a subnet type
        Write-ColorOutput "  Checking for RouteServerSubnet..." "Yellow"
        $vnets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        $routeServerSubnetFound = $false
        foreach ($vnet in $vnets) {
            $rsSubnet = $vnet.Subnets | Where-Object { $_.Name -eq "RouteServerSubnet" }
            if ($rsSubnet) {
                Write-ColorOutput "    ✅ RouteServerSubnet found in VNet: $($vnet.Name)" "Green"
                Write-ColorOutput "    📍 Subnet Address: $($rsSubnet.AddressPrefix)" "Gray"
                $routeServerSubnetFound = $true
                
                # If subnet exists, check if Route Server resource exists but was missed
                Write-ColorOutput "    Checking for Route Server resource in this VNet..." "Yellow"
                $allRouteServers = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Network/virtualHubs" -ErrorAction SilentlyContinue
                $routeServerInVnet = $allRouteServers | Where-Object { 
                    $_.Name -like "*route-server*" -or $_.Name -like "*spoke3*" 
                }
                if ($routeServerInVnet) {
                    Write-ColorOutput "    ✅ Found Route Server resource: $($routeServerInVnet.Name)" "Green"
                    Write-ColorOutput "    🔧 Route Server exists but may not be fully configured for BGP" "Yellow"
                } else {
                    Write-ColorOutput "    ⚠️  RouteServerSubnet exists but no Route Server resource found" "Yellow"
                    Write-ColorOutput "    🔧 This indicates incomplete Phase 3 deployment" "Yellow"
                }
            }
        }
        if (-not $routeServerSubnetFound) {
            Write-ColorOutput "    ❌ No RouteServerSubnet found in any VNet" "Red"
            Write-ColorOutput "    🔧 Phase 3 (Route Server) definitely not deployed" "Yellow"
        }
    }
} catch {
    Write-ColorOutput "❌ Error checking for Route Server: $($_.Exception.Message)" "Red"
}

Write-ColorOutput "`n=== 3. NVA VM Analysis ===" "Cyan"
# Look for NVA VMs using the expected naming pattern
$nvaVms = Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*nva*" -or $_.Name -like "*spoke1*" 
}
if ($nvaVms) {
    foreach ($vm in $nvaVms) {
        Write-ColorOutput "✅ NVA VM Found: $($vm.Name)" "Green"
        
        # Get VM status
        $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Status -ErrorAction SilentlyContinue
        if ($vmStatus) {
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState*" }).DisplayStatus
            Write-ColorOutput "  Power State: $powerState" "Gray"
        }
        Write-ColorOutput "  VM Size: $($vm.HardwareProfile.VmSize)" "Gray"
        Write-ColorOutput "  OS Type: $($vm.StorageProfile.OsDisk.OsType)" "Gray"
        
        # Get VM network interface
        if ($vm.NetworkProfile.NetworkInterfaces.Count -gt 0) {
            $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
            $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq $nicId }
            if ($nic) {
                $privateIP = $nic.IpConfigurations[0].PrivateIpAddress
                Write-ColorOutput "  Private IP: $privateIP" "Gray"
                Write-ColorOutput "  IP Forwarding: $($nic.EnableIPForwarding)" "Gray"
                
                # Check if IP forwarding is enabled (required for NVA)
                if ($nic.EnableIPForwarding) {
                    Write-ColorOutput "    ✅ IP Forwarding is enabled (good for NVA)" "Green"
                } else {
                    Write-ColorOutput "    ⚠️  IP Forwarding is disabled (should be enabled for NVA)" "Yellow"
                }
                
                # Get subnet information
                $subnetId = $nic.IpConfigurations[0].Subnet.Id
                $subnetName = ($subnetId -split "/")[-1]
                $vnetName = ($subnetId -split "/")[-3]
                Write-ColorOutput "  Subnet: $subnetName in VNet: $vnetName" "Gray"
            }
        }
        
        # Check if this matches the expected NVA VM naming
        if ($vm.Name -like "*spoke1*nva*") {
            Write-ColorOutput "  🎯 This is the expected main NVA VM for BGP peering" "Green"
            Write-ColorOutput "  💡 Should be configured with RRAS and BGP ASN 65001" "Cyan"
        } elseif ($vm.Name -like "*nva*") {
            Write-ColorOutput "  🔧 This appears to be an NVA VM but check if it's the primary one" "Yellow"
        }
    }
} else {
    Write-ColorOutput "❌ No NVA VM found" "Red"
    Write-ColorOutput "🔧 This means Phase 2 (VMs) hasn't been deployed" "Yellow"
    Write-ColorOutput "💡 Expected: vwanlab-spoke1-nva-vm in spoke1 VNet" "Cyan"
    
    # Check for any VMs that might be NVAs
    $allVMs = Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($allVMs) {
        Write-ColorOutput "  Available VMs in resource group:" "Yellow"
        foreach ($vm in $allVMs) {
            Write-ColorOutput "    - $($vm.Name)" "Gray"
        }
    }
}

Write-ColorOutput "`n=== 4. VNet Peering Analysis ===" "Cyan"
$vnets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
$peeringFound = $false
foreach ($vnet in $vnets) {
    if ($vnet.VirtualNetworkPeerings.Count -gt 0) {
        Write-ColorOutput "✅ VNet with Peering: $($vnet.Name)" "Green"
        foreach ($peering in $vnet.VirtualNetworkPeerings) {
            Write-ColorOutput "  Peering: $($peering.Name) → $($peering.RemoteVirtualNetwork.Id.Split('/')[-1])" "Gray"
            Write-ColorOutput "  State: $($peering.PeeringState)" "Gray"
            $peeringFound = $true
        }
    }
}
if (-not $peeringFound) {
    Write-ColorOutput "❌ No VNet peering found between Spoke1 and Spoke3" "Red"
    Write-ColorOutput "🔧 This means Phase 4c (Peering) hasn't been deployed" "Yellow"
}

Write-ColorOutput "`n=== 5. Expected BGP Architecture ===" "Cyan"
Write-ColorOutput "📋 Your VWAN Lab should have the following BGP topology:" "White"
Write-ColorOutput ""
Write-ColorOutput "  🏢 VWAN Hub (ASN: 65515)" "Yellow"
Write-ColorOutput "  ├── Connected to Spoke1 VNet (contains NVA)" "Gray"
Write-ColorOutput "  ├── Connected to Spoke2 VNet (contains test VM)" "Gray"
Write-ColorOutput "  └── No BGP peers (normal for hub-spoke topology)" "Gray"
Write-ColorOutput ""
Write-ColorOutput "  🔧 Azure Route Server in Spoke3 (ASN: 65515)" "Yellow"
Write-ColorOutput "  ├── Name: vwanlab-spoke3-route-server" "Gray"
Write-ColorOutput "  ├── IPs: 10.3.0.4, 10.3.0.5" "Gray"
Write-ColorOutput "  └── BGP Peer: NVA (ASN: 65001, IP: ~10.1.0.10)" "Gray"
Write-ColorOutput ""
Write-ColorOutput "  💻 NVA VM in Spoke1 (ASN: 65001)" "Yellow"
Write-ColorOutput "  ├── Name: vwanlab-spoke1-nva-vm" "Gray"
Write-ColorOutput "  ├── Windows Server with RRAS enabled" "Gray"
Write-ColorOutput "  ├── BGP Peer: Route Server (ASN: 65515)" "Gray"
Write-ColorOutput "  └── Connected via VNet peering (Spoke1 ↔ Spoke3)" "Gray"

Write-ColorOutput "`n=== 6. Deployment Status Summary ===" "Magenta"
if (($vwans.Count -eq 0) -and ($vwanHubs.Count -eq 0)) {
    Write-ColorOutput "❌ Phase 1 (Core): MISSING - No VWAN or VWAN Hub found" "Red"
} else {
    Write-ColorOutput "✅ Phase 1 (Core): DEPLOYED - VWAN/Hub exists" "Green"
}

if ($nvaVms.Count -eq 0) {
    Write-ColorOutput "❌ Phase 2 (VMs): MISSING - No NVA VM found" "Red"
} else {
    Write-ColorOutput "✅ Phase 2 (VMs): DEPLOYED - NVA VM exists" "Green"
}

if ($routeServers.Count -eq 0) {
    Write-ColorOutput "❌ Phase 3 (Route Server): MISSING - No Route Server found" "Red"
} else {
    Write-ColorOutput "✅ Phase 3 (Route Server): DEPLOYED - Route Server exists" "Green"
}

if (-not $peeringFound) {
    Write-ColorOutput "❌ Phase 4c (Peering): MISSING - No VNet peering found" "Red"
} else {
    Write-ColorOutput "✅ Phase 4c (Peering): DEPLOYED - VNet peering exists" "Green"
}

$bgpPeersConfigured = $false
if ($routeServers.Count -gt 0) {
    try {
        # Try to check for BGP peers without using Get-AzRouteServerPeer (which requires peer name)
        foreach ($rs in $routeServers) {
            $routeServerObject = Get-AzRouteServer -ResourceGroupName $ResourceGroupName -RouteServerName $rs.Name -ErrorAction SilentlyContinue
            if ($routeServerObject -and $routeServerObject.BgpConnections -and $routeServerObject.BgpConnections.Count -gt 0) {
                $bgpPeersConfigured = $true
                break
            }
            
            # Also try common peer names
            $commonPeerNames = @("nva-peer", "spoke1-nva", "bgp-peer", "nva-bgp-peer", "nva-connection")
            foreach ($peerName in $commonPeerNames) {
                try {
                    $peer = Get-AzRouteServerPeer -ResourceGroupName $ResourceGroupName -RouteServerName $rs.Name -PeerName $peerName -ErrorAction SilentlyContinue
                    if ($peer) {
                        $bgpPeersConfigured = $true
                        break
                    }
                } catch {
                    # Silently continue
                }
            }
            if ($bgpPeersConfigured) { break }
        }
    } catch {
        # Ignore errors when checking BGP peer status
    }
}

if (-not $bgpPeersConfigured) {
    Write-ColorOutput "❌ Phase 5 (BGP): MISSING - No BGP peers configured" "Red"
} else {
    Write-ColorOutput "✅ Phase 5 (BGP): DEPLOYED - BGP peers configured" "Green"
}

Write-ColorOutput "`n=== 7. Next Steps ===" "Cyan"
if ($routeServers.Count -eq 0) {
    Write-ColorOutput "🔧 Deploy Route Server: .\scripts\Deploy-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName' -Phase 3" "Yellow"
} elseif (-not $peeringFound) {
    Write-ColorOutput "🔧 Deploy VNet Peering: .\scripts\Deploy-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName' -Phase 4c" "Yellow"
} elseif (-not $bgpPeersConfigured) {
    Write-ColorOutput "🔧 Deploy BGP Peering: .\scripts\Deploy-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName' -Phase 5" "Yellow"
} else {
    Write-ColorOutput "🔧 Configure NVA BGP: .\scripts\Configure-NvaBgp.ps1 -ResourceGroupName '$ResourceGroupName'" "Yellow"
    Write-ColorOutput "🔍 Check BGP Status: .\scripts\Get-BgpStatus.ps1 -ResourceGroupName '$ResourceGroupName'" "Yellow"
}

Write-ColorOutput "`nℹ️  Note: The Get-BgpStatus.ps1 script checks the NVA VM's BGP configuration" "Cyan"
Write-ColorOutput "   It does NOT check VWAN Hub BGP (which should be empty in hub-spoke topology)" "Cyan"

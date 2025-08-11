# VWAN Lab Configuration Guide

This guide provides detailed information about configuring the various components of the Azure Virtual WAN lab environment with **automated configuration features** and security enhancements.

## 🚀 **Automatic Configuration Features**

The enhanced deployment system now includes **automatic VM configuration** for streamlined setup:

### **✅ Automated Security & Access Configuration**
- **RDP Access Setup** - Automatic NSG rule creation for deployer IP
- **Windows Firewall Management** - RDP enabled through Windows Firewall
- **Credential Validation** - Azure VM password complexity enforcement
- **Secure Authentication** - IP-restricted access for enhanced security

### **✅ Automated RRAS Installation**
- **Role Installation** - Automatic RRAS and BGP feature installation
- **Configuration Setup** - Pre-configured routing and BGP settings
- **Logging Integration** - Comprehensive installation logging for troubleshooting
- **Validation Checks** - Automatic verification of successful installation

## 🔐 **Security Configuration**

### **Credential Management**
The deployment system now includes comprehensive credential validation:

#### **Username Requirements**
- Cannot be: 'admin', 'administrator', 'root', 'guest'
- Must be valid Azure VM username format
- Automatic validation during deployment

#### **Password Complexity Requirements** 
Azure VM passwords must meet the following criteria:
- **Length**: 8-123 characters
- **Complexity**: Must contain 3 of the following 4 character types:
  - Lowercase letters (a-z)
  - Uppercase letters (A-Z) 
  - Digits (0-9)
  - Special characters (!@#$%^&*()_+-=[]{}|;:,.<>?)
- **Restrictions**: Cannot contain the username

#### **Automatic IP-based Access Control**
The deployment automatically:
1. **Detects deployer's public IP** using external IP detection services
2. **Creates NSG rules** allowing RDP access only from deployer IP
3. **Configures Windows Firewall** to enable RDP through the firewall
4. **Validates access** by testing RDP connectivity

### **Network Security Configuration**
```powershell
# Example NSG rule created automatically for RDP access
New-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP-From-Deployer" `
    -Description "Allow RDP access from deployer IP only" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix $deployerIP `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389
```

## Network Virtual Appliance (NVA) Configuration

### **🔧 Automated RRAS Installation and Setup**

The NVA VM now uses **automated RRAS installation** for BGP routing capabilities with comprehensive logging.

#### **Automatic Installation Process**
The deployment script automatically:
1. **Installs required Windows features**:
   - RemoteAccess role with management tools
   - RSAT-RemoteAccess-PowerShell
   - Routing feature
2. **Configures IP forwarding** in the registry
3. **Sets up BGP routing** with proper ASN configuration
4. **Creates detailed logs** at `C:\Windows\Temp\rras-install.log`

#### **Installation Logging**
The automatic installation creates comprehensive logs for troubleshooting:
```
Log Location: C:\Windows\Temp\rras-install.log
Contents:
- Feature installation status
- Registry modification results
- BGP configuration commands
- Error messages and troubleshooting information
- Installation completion timestamp
```

#### **Manual RRAS Configuration (If Needed)**

If automatic installation fails or manual configuration is required:

```powershell
# Install RRAS role
Install-WindowsFeature -Name RemoteAccess -IncludeManagementTools
Install-WindowsFeature -Name RSAT-RemoteAccess-PowerShell
Install-WindowsFeature -Name Routing

# Enable IP forwarding
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 1

# Configure RRAS
netsh routing ip install
netsh routing ip set global loglevel=error

# Enable BGP routing
netsh routing ip add protocol "BGP" "BGP"
netsh routing ip bgp install
netsh routing ip bgp set global loglevel=error

# Add BGP router with local ASN 65001
netsh routing ip bgp add router "BGP" localas=65001
```

#### BGP Peer Configuration

Configure BGP peering with Azure Route Server:

```powershell
# Get Route Server IPs (replace with actual IPs)
$routeServerIp1 = "10.1.1.4"
$routeServerIp2 = "10.1.1.5"
$remoteAsn = 65515

# Add BGP peers
netsh routing ip bgp add peer "BGP" $routeServerIp1 remoteas=$remoteAsn
netsh routing ip bgp add peer "BGP" $routeServerIp2 remoteas=$remoteAsn

# Enable peers
netsh routing ip bgp set peer "BGP" $routeServerIp1 state=enabled
netsh routing ip bgp set peer "BGP" $routeServerIp2 state=enabled

# Start BGP
netsh routing ip bgp set global state=enabled
```

#### Custom Route Advertisement

To advertise custom routes via BGP:

```powershell
# Add a static route to advertise
route add 192.168.100.0 mask 255.255.255.0 10.1.0.1 metric 1 -p

# Add route to BGP
netsh routing ip bgp add route "BGP" 192.168.100.0/24 nexthop=10.1.0.1 metric=100

# Or advertise a network range
netsh routing ip bgp add network "BGP" 192.168.0.0/16
```

### Monitoring BGP Status

Check BGP peer status and learned routes:

```powershell
# Check BGP peers
netsh routing ip bgp show peer

# Show BGP routes
netsh routing ip bgp show routes

# Show BGP neighbors
netsh routing ip bgp show neighbor

# Show routing table
route print

# Check specific routes
Get-NetRoute | Where-Object {$_.DestinationPrefix -like "10.*"}
```

## Azure Route Server Configuration

### Viewing Route Server Information

```powershell
# Get Route Server details
$routeServer = Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo" | Where-Object {$_.Name -like "*route-server*"}
$routeServer

# Check BGP connections
Get-AzVirtualHubBgpConnection -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $routeServer.Name

# View learned routes (if available)
Get-AzVirtualHubEffectiveRoute -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $routeServer.Name
```

### Managing BGP Connections

```powershell
# Add new BGP connection
New-AzVirtualHubBgpConnection -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $routeServer.Name -Name "additional-peer" -PeerAsn 65002 -PeerIP "10.1.0.20"

# Remove BGP connection
Remove-AzVirtualHubBgpConnection -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $routeServer.Name -Name "peer-name"
```

## Virtual WAN Hub Configuration

### Hub Routing Configuration

```powershell
# Get VWAN Hub
$vwanHub = Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo"

# View hub route tables
Get-AzVirtualHubRouteTable -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $vwanHub.Name

# Check VNet connections
Get-AzVirtualHubVnetConnection -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $vwanHub.Name
```

### Custom Route Tables

Create custom route tables for specific routing scenarios:

```powershell
# Create custom route table
$routeTable = New-AzVirtualHubRouteTable -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $vwanHub.Name -Name "custom-rt" -Label @("custom")

# Add routes to the table
$route = New-AzVirtualHubRoute -Destination @("192.168.0.0/16") -DestinationType "CIDR" -NextHop "10.1.0.10" -NextHopType "IPAddress"
Update-AzVirtualHubRouteTable -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $vwanHub.Name -Name "custom-rt" -Route @($route)
```

## Network Security Group (NSG) Configuration

### Common NSG Rules

```powershell
# Get NSG
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-spoke1-nsg"

# Add custom rule
$nsg | Add-AzNetworkSecurityRuleConfig -Name "AllowHTTP" -Protocol "Tcp" -Direction "Inbound" -Priority 1300 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "80" -Access "Allow"

# Apply changes
$nsg | Set-AzNetworkSecurityGroup
```

### Flow Log Configuration

Enable NSG flow logs for troubleshooting:

```powershell
# Create storage account for flow logs
$storageAccount = New-AzStorageAccount -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlabflowlogs" -Location "East US" -SkuName "Standard_LRS"

# Enable flow logs
Set-AzNetworkWatcherFlowLogV2 -NetworkWatcher (Get-AzNetworkWatcher) -TargetResourceId $nsg.Id -StorageAccountId $storageAccount.Id -Enabled $true
```

## VM Network Configuration

### Effective Routes

Check effective routes on VM network interfaces:

```powershell
# Get VM and NIC
$vm = Get-AzVM -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-test1-vm"
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id

# Get effective routes
Get-AzEffectiveRouteTable -NetworkInterfaceName $nic.Name -ResourceGroupName "rg-vwanlab-demo"

# Get effective security groups
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName $nic.Name -ResourceGroupName "rg-vwanlab-demo"
```

### IP Forwarding

Enable IP forwarding on NVA VM network interface:

```powershell
# Get NVA NIC
$nvaNic = Get-AzNetworkInterface -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-nva-nic"

# Enable IP forwarding
$nvaNic.EnableIPForwarding = $true
Set-AzNetworkInterface -NetworkInterface $nvaNic
```

## Monitoring and Diagnostics

### Network Watcher

Enable Network Watcher for advanced diagnostics:

```powershell
# Create Network Watcher
New-AzNetworkWatcher -ResourceGroupName "rg-vwanlab-demo" -Name "nw-vwanlab" -Location "East US"

# Test connectivity
Test-AzNetworkWatcherConnectivity -NetworkWatcher $nw -SourceResourceId $vm1.Id -DestinationResourceId $vm2.Id -DestinationPort 3389
```

### Connection Monitor

Set up connection monitoring:

```powershell
# Create connection monitor
$source = New-AzNetworkWatcherConnectionMonitorEndpointObject -Name "vm1" -ResourceId $vm1.Id
$destination = New-AzNetworkWatcherConnectionMonitorEndpointObject -Name "vm2" -ResourceId $vm2.Id
$testConfig = New-AzNetworkWatcherConnectionMonitorTestConfigurationObject -Name "http-test" -Protocol "Http" -HttpRequestHeader @{"Host"="bing.com"}

New-AzNetworkWatcherConnectionMonitor -NetworkWatcher $nw -Name "vwan-connectivity-monitor" -Endpoint @($source, $destination) -TestConfiguration @($testConfig)
```

## Troubleshooting Common Configurations

### BGP Session Issues

1. **Check BGP peer status**:
   ```powershell
   netsh routing ip bgp show peer
   ```

2. **Verify Route Server IPs**:
   ```powershell
   $routeServer = Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo" | Where-Object {$_.Name -like "*route-server*"}
   $routeServer.VirtualRouterIps
   ```

3. **Reset BGP sessions**:
   ```powershell
   netsh routing ip bgp set peer "BGP" "route-server-ip" state=disabled
   netsh routing ip bgp set peer "BGP" "route-server-ip" state=enabled
   ```

### Routing Issues

1. **Check effective routes**:
   ```powershell
   Get-AzEffectiveRouteTable -NetworkInterfaceName $nic.Name -ResourceGroupName "rg-vwanlab-demo"
   ```

2. **Verify VWAN hub routes**:
   ```powershell
   Get-AzVirtualHubEffectiveRoute -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $vwanHub.Name
   ```

3. **Test network connectivity**:
   ```powershell
   Test-NetConnection -ComputerName "destination-ip" -Port 80 -InformationLevel Detailed
   ```

### Performance Optimization

1. **Enable Accelerated Networking**:
   ```powershell
   $nic = Get-AzNetworkInterface -ResourceGroupName "rg-vwanlab-demo" -Name "vm-nic"
   $nic.EnableAcceleratedNetworking = $true
   Set-AzNetworkInterface -NetworkInterface $nic
   ```

2. **Optimize VM sizes**:
   - Use compute-optimized VMs for better networking performance
   - Consider Dv3 or Ev3 series for balanced performance

3. **Monitor network metrics**:
   - Use Azure Monitor to track network performance
   - Set up alerts for high latency or packet loss

## Security Hardening

### VM Security

1. **Disable password authentication** (use SSH keys):
   ```powershell
   # Configure during VM creation or update VM configuration
   ```

2. **Enable Just-In-Time access**:
   ```powershell
   # Configure through Azure Security Center
   ```

3. **Use Azure Bastion** for secure VM access:
   ```powershell
   # Deploy Azure Bastion in a dedicated subnet
   ```

### Network Security

1. **Implement micro-segmentation**:
   - Use NSGs for granular traffic control
   - Create separate subnets for different workloads

2. **Enable DDoS protection**:
   ```powershell
   # Configure DDoS protection standard on VNets
   ```

3. **Use Azure Firewall** for advanced filtering:
   ```powershell
   # Deploy Azure Firewall in VWAN hub
   ```

## Advanced Configurations

### Multi-Region Setup

For multi-region deployments:

1. Deploy additional VWAN hubs in other regions
2. Configure hub-to-hub connectivity
3. Implement geo-redundant routing

### Hybrid Connectivity

1. **VPN Gateway integration**:
   - Deploy VPN Gateway in VWAN hub
   - Configure site-to-site connections

2. **ExpressRoute integration**:
   - Connect ExpressRoute circuits to VWAN hub
   - Configure private peering

### Custom Routing Policies

1. **Route filtering**:
   - Control route advertisement between BGP peers
   - Implement route maps for advanced policies

2. **Traffic engineering**:
   - Use BGP attributes to influence routing decisions
   - Implement load balancing across multiple paths

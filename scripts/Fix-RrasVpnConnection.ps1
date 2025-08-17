#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Network

<#
.SYNOPSIS
    Fix RRAS VPN connection and BGP configuration for VWAN lab

.DESCRIPTION
    This script fixes the VPN site and connection configuration to enable
    proper VPN tunnel establishment and BGP peering between RRAS VM and VWAN hub.
    
    Issues Fixed:
    - Updates VPN site with RRAS VM public IP address
    - Configures BGP settings with private ASN (65001)
    - Sets BGP peer IP to RRAS VM private IP
    - Enables BGP on VPN connection

.PARAMETER ResourceGroupName
    Name of the resource group containing the VWAN lab resources

.PARAMETER RrasVmName
    Name of the RRAS VM (default: vm-s3-rras-cus)

.PARAMETER VpnSiteName
    Name of the VPN site (default: vwanlab-spoke3-vpnsite)

.PARAMETER VpnGatewayName
    Name of the VPN gateway (default: vpngw-vwanlab-cus)

.PARAMETER VpnConnectionName
    Name of the VPN connection (default: vwanlab-spoke3-vpnconnection)

.PARAMETER BgpAsn
    BGP ASN for RRAS VM (default: 65001 - private ASN range)

.EXAMPLE
    .\Fix-RrasVpnConnection.ps1 -ResourceGroupName "rg-vwanlab"

.NOTES
    Author: Azure VWAN Lab Team
    Version: 1.0
    Requires: Azure PowerShell, appropriate Azure permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$RrasVmName = "vm-s3-rras-cus",

    [Parameter(Mandatory = $false)]
    [string]$VpnSiteName = "vwanlab-spoke3-vpnsite",

    [Parameter(Mandatory = $false)]
    [string]$VpnGatewayName = "vpngw-vwanlab-cus",

    [Parameter(Mandatory = $false)]
    [string]$VpnConnectionName = "vwanlab-spoke3-vpnconnection",

    [Parameter(Mandatory = $false)]
    [int]$BgpAsn = 65001
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "🔧 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

try {
    Write-Host ""
    Write-Host "🚀 Fixing RRAS VPN Connection and BGP Configuration" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host ""

    # Step 1: Get RRAS VM information
    Write-Step "Getting RRAS VM information..."
    
    $rrasVm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $RrasVmName -Status
    if (-not $rrasVm) {
        throw "RRAS VM '$RrasVmName' not found in resource group '$ResourceGroupName'"
    }

    # Get VM network details
    $vmDetails = az vm show --resource-group $ResourceGroupName --name $RrasVmName --show-details --query "{PublicIPs:publicIps, PrivateIPs:privateIps}" --output json | ConvertFrom-Json
    
    $publicIp = $vmDetails.PublicIPs
    $privateIp = $vmDetails.PrivateIPs

    if (-not $publicIp -or -not $privateIp) {
        throw "Could not retrieve IP addresses for RRAS VM. Public IP: $publicIp, Private IP: $privateIp"
    }

    Write-Success "RRAS VM found - Public IP: $publicIp, Private IP: $privateIp"

    # Step 2: Update VPN Site configuration
    Write-Step "Updating VPN site '$VpnSiteName' with IP address and BGP settings..."
    
    # Update VPN site with public IP and BGP configuration
    $vpnSiteUpdate = az network vpn-site update `
        --resource-group $ResourceGroupName `
        --name $VpnSiteName `
        --ip-address $publicIp `
        --asn $BgpAsn `
        --bgp-peering-address $privateIp `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update VPN site configuration"
    }

    Write-Success "VPN site updated with public IP ($publicIp) and BGP settings (ASN: $BgpAsn, Peer IP: $privateIp)"

    # Step 3: Update VPN Connection to enable BGP
    Write-Step "Updating VPN connection '$VpnConnectionName' to enable BGP..."
    
    $vpnConnectionUpdate = az network vpn-gateway connection update `
        --resource-group $ResourceGroupName `
        --gateway-name $VpnGatewayName `
        --name $VpnConnectionName `
        --enable-bgp true `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update VPN connection BGP settings"
    }

    Write-Success "VPN connection updated with BGP enabled"

    # Step 4: Verify configuration
    Write-Step "Verifying VPN site and connection configuration..."
    
    # Check VPN site
    $vpnSite = az network vpn-site show --resource-group $ResourceGroupName --name $VpnSiteName --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "📋 VPN Site Configuration:" -ForegroundColor White
    Write-Host "  Name: $($vpnSite.name)" -ForegroundColor Gray
    Write-Host "  IP Address: $($vpnSite.ipAddress)" -ForegroundColor Gray
    Write-Host "  BGP ASN: $($vpnSite.bgpProperties.asn)" -ForegroundColor Gray
    Write-Host "  BGP Peer IP: $($vpnSite.bgpProperties.bgpPeeringAddress)" -ForegroundColor Gray

    # Check VPN connection
    $vpnConnection = az network vpn-gateway connection show --resource-group $ResourceGroupName --gateway-name $VpnGatewayName --name $VpnConnectionName --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "📋 VPN Connection Configuration:" -ForegroundColor White
    Write-Host "  Name: $($vpnConnection.name)" -ForegroundColor Gray
    Write-Host "  BGP Enabled: $($vpnConnection.enableBgp)" -ForegroundColor Gray
    Write-Host "  Provisioning State: $($vpnConnection.provisioningState)" -ForegroundColor Gray

    Write-Host ""
    Write-Success "VPN site and connection configuration completed successfully!"
    
    # Step 5: Provide next steps
    Write-Host ""
    Write-Host "🔍 Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Configure RRAS on the VM to establish VPN tunnel:" -ForegroundColor White
    Write-Host "   - Set up VPN connection to VWAN hub" -ForegroundColor Gray
    Write-Host "   - Configure BGP peering inside the tunnel" -ForegroundColor Gray
    Write-Host "2. Use the Configure-NvaBgp.ps1 script to complete RRAS configuration" -ForegroundColor White
    Write-Host "3. Monitor VPN connection status:" -ForegroundColor White
    Write-Host "   az network vpn-gateway connection show --resource-group $ResourceGroupName --gateway-name $VpnGatewayName --name $VpnConnectionName" -ForegroundColor Gray

    Write-Host ""
    Write-Host "📊 BGP Configuration Summary:" -ForegroundColor Yellow
    Write-Host "  RRAS BGP ASN: $BgpAsn (Private ASN range)" -ForegroundColor White
    Write-Host "  RRAS BGP Peer IP: $privateIp" -ForegroundColor White
    Write-Host "  Azure VWAN Hub ASN: 65515 (Default)" -ForegroundColor White
    Write-Host "  VPN Tunnel: $publicIp ↔ VWAN Hub" -ForegroundColor White

} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "🔍 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure you have appropriate Azure permissions" -ForegroundColor White
    Write-Host "2. Verify resource names are correct" -ForegroundColor White
    Write-Host "3. Check that RRAS VM is running and has public IP" -ForegroundColor White
    Write-Host "4. Verify VWAN hub and VPN gateway are deployed" -ForegroundColor White
    exit 1
}

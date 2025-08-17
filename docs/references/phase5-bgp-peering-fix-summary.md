# Phase 5 BGP Peering Fix Summary

## Issue Description

Phase 5 deployment was failing with the following error:
```
The Resource 'Microsoft.Network/virtualHubs/vwanlab-route-server' under resource group 'rg-vwanlab-demo' was not found.
```

## Root Cause

The Phase 5 BGP peering template (`bicep/phases/phase5-bgp-peering.bicep`) was still referencing the old Route Server name `vwanlab-route-server`, which was renamed to `vwanlab-spoke3-route-server` as part of the Spoke 3 naming standardization.

## Solution

Updated the Phase 5 BGP peering template to use the correct Spoke 3 Route Server name.

### Changes Made

1. **Route Server Reference Update**:
   - **Old**: `${environmentPrefix}-route-server`
   - **New**: `${environmentPrefix}-spoke3-route-server`

2. **Resource Comments Update**:
   - Updated comment to clarify "Route Server in Spoke 3"

### Updated Template Structure

```bicep
// Phase 5: BGP Peering Configuration Between NVA and Route Server
// Establishes BGP peering for route exchange and redundancy

// Get existing Route Server in Spoke 3
resource routeServer 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: '${environmentPrefix}-spoke3-route-server'
}

// Get NVA network interface to get private IP
resource nvaNic 'Microsoft.Network/networkInterfaces@2024-05-01' existing = {
  name: '${environmentPrefix}-nva-nic'
}

// Create BGP Connection from Route Server to NVA
resource nvaBgpConnection 'Microsoft.Network/virtualHubs/bgpConnections@2024-05-01' = {
  parent: routeServer
  name: 'nva-bgp-peer'
  properties: {
    peerAsn: nvaAsn // 65001: Private ASN
    peerIp: nvaNic.properties.ipConfigurations[0].properties.privateIPAddress
  }
}
```

## Architecture Context

Phase 5 establishes BGP peering between:
- **NVA VM** in Spoke 1 VNet (`vwanlab-spoke1-nva-vm`)
- **Azure Route Server** in Spoke 3 VNet (`vwanlab-spoke3-route-server`)

This BGP peering enables:
- Route exchange between NVA and Azure Route Server
- Advanced routing scenarios and redundancy
- Dynamic route propagation across the VWAN environment

## Verification

1. **Template Compilation**: ✅ Bicep template compiles successfully
2. **Resource References**: ✅ All resources use correct spoke3 naming
3. **PowerShell Scripts**: ✅ Already updated to use spoke3-route-server naming
4. **BGP Configuration**: ✅ ASN and peering logic unchanged

## Impact

- **Deployment**: Phase 5 will now deploy successfully
- **BGP Functionality**: No change to BGP peering behavior
- **Architecture**: Maintains route exchange between NVA and Route Server
- **Naming**: Consistent with spoke-based naming convention

## Dependencies

Phase 5 requires the following resources to exist:
- ✅ **Spoke 1 VNet** with NVA VM (`vwanlab-spoke1-nva-vm`)
- ✅ **Spoke 3 VNet** with Route Server (`vwanlab-spoke3-route-server`)
- ✅ **VNet Peering** between Spoke 1 and Spoke 3 (Phase 4c)
- ✅ **Network Interface** for NVA (`vwanlab-nva-nic`)

## Files Modified

- `bicep/phases/phase5-bgp-peering.bicep` - Updated Route Server reference

## Next Steps

The Phase 5 deployment should now complete successfully with the updated Route Server reference. This will establish BGP peering between:
- **NVA VM** (ASN 65001) in Spoke 1
- **Azure Route Server** (ASN 65515) in Spoke 3

The BGP peering enables dynamic route exchange and advanced routing scenarios in the VWAN lab environment.

---
*Fixed: January 2025*
*Part of Spoke 3 naming standardization effort*

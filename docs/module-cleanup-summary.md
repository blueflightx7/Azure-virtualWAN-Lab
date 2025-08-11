# Module Cleanup Summary - Phased-Only Architecture

## Overview
Cleaned up the `bicep/modules/` directory to only contain modules actually used by the phased deployment approach.

## ✅ ACTIVE MODULES (Remaining in bicep/modules/)
These modules are actively used by the phase templates:

| Module | Used By | Purpose |
|--------|---------|---------|
| `vwan.bicep` | Phase 1 | Creates Virtual WAN and hub |
| `spoke-vnet-infrastructure-only.bicep` | Phase 1 | Creates spoke VNets (used 3x for spoke1, spoke2, spoke3) |
| `vm-nva.bicep` | Phase 2 | Creates NVA VM in existing spoke1 |
| `vm-test.bicep` | Phase 2 | Creates test VM in existing spoke2 |

## 🗂️ ARCHIVED MODULES (Moved to archive/bicep/modules/)
These modules were only used by the legacy `main.bicep` (not the phased approach):

| Module | Previously Used By | Reason for Archive |
|--------|-------------------|-------------------|
| `spoke-vnet-direct.bicep` | Legacy main.bicep only | Not used in phased deployment |
| `spoke-vnet-route-server.bicep` | Legacy main.bicep only | Route server now deployed inline in Phase 3 |
| `vwan-connections.bicep` | Legacy main.bicep only | Connections now handled inline in phases |
| `vnet-peering.bicep` | Legacy main.bicep only | Peering now handled inline in Phase 4c |
| `spoke-vnet-with-nva.bicep` | Legacy main.bicep only | VM creation separated in phased approach |

## Architecture Benefits
- **Clean Separation**: Modules directory only contains components actively used
- **Phased-Only Focus**: Removed all legacy full-deployment artifacts
- **Maintainability**: Easier to identify which components are actually used
- **Consistency**: All remaining modules follow the spoke-based naming convention

## Current Structure
```
bicep/
├── modules/           # 4 active modules only
├── phases/           # 11 phase-specific deployment templates
├── parameters/       # Parameter files
└── main-validated.json  # Compiled output (can be ignored)

archive/bicep/
├── main.bicep        # Legacy full-deployment template
├── main.json         # Legacy compiled template
└── modules/          # 5 legacy modules
```

## Updated Components
- **VS Code Tasks**: Updated to build/validate phase templates instead of main.bicep
- **Troubleshoot Script**: Updated to reference archived spoke-vnet-with-nva.bicep location
- **Deploy Scripts**: Already using phase templates exclusively

## Next Steps
- Consider updating troubleshooting script to check phase templates for validation
- All active deployment now uses phased-only approach

## Date
2025-01-27

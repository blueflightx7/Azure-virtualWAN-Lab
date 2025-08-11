<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Azure Virtual WAN Lab Environment

This is an Azure Virtual WAN lab environment project for BGP routing and network connectivity testing that includes:

- **Bicep Infrastructure**: Phased deployment templates for VWAN hub-spoke topology
- **BGP Configuration**: RRAS NVA setup with Azure Route Server and VWAN hub peering
- **PowerShell Automation**: VM configuration, BGP setup, and connectivity testing
- **Security Framework**: Automated NSG rules with deployer IP detection
- **Monitoring Tools**: BGP status checking and connectivity validation
- **.NET Automation**: Lab management and resource cleanup utilities
- **Comprehensive Documentation**: Architecture guides and troubleshooting procedures

## Architecture Overview

**Core Components (Default Suggestions):**
- **VWAN Hub**: Central routing point (suggested: 10.0.0.0/16) with default BGP IPs 10.0.32.6, 10.0.32.5
- **Spoke 1**: NVA subnet (suggested: 10.1.0.0/16) with RRAS VM (suggested: 10.1.0.4, ASN 65001)
- **Spoke 2**: Direct VWAN connection (suggested: 10.2.0.0/16) for testing
- **Spoke 3**: Route Server deployment (suggested: 10.3.0.0/16) with default BGP IPs 10.3.0.68, 10.3.0.69

**BGP Peering Architecture:**
- NVA VM ↔ Azure Route Server (Azure default ASN 65515)
- NVA VM ↔ VWAN Hub BGP routers (Azure default ASN 65515)
- Route injection from spoke networks to VWAN hub

**Note**: All IP ranges and ASN values above are suggested defaults that have been tested and work well together. These can be customized based on specific requirements, but should be confirmed with the user before implementation.

## Architecture Decisions and Lessons Learned

### Route Injection Strategy
- **Route Server Limitation**: Azure Route Server does NOT automatically inject routes to VWAN hub
- **Required Configuration**: NVA must establish direct BGP peering with VWAN hub for route injection
- **Dual Peering**: NVA peers with both Route Server (for spoke routes) AND VWAN hub (for injection)

### Security Model
- **NSG Philosophy**: Rely on Azure's implicit deny-all rules instead of explicit deny rules
- **RDP Strategy**: Auto-detect deployer IP and create targeted RDP rules during deployment
- **BGP Security**: Allow BGP (port 179) within VirtualNetwork scope only

### Deployment Strategy
- **Phase-Based**: 5-phase deployment prevents Azure timeout issues on large deployments
- **Conditional Resources**: Check for existing resources before creating new ones
- **Parameter Consistency**: Use `environmentPrefix` parameter across all templates and scripts

## Project Guidelines

When working with this project:

### Default Values Philosophy
**IMPORTANT**: All network configuration values (IP ranges, ASNs, resource names) listed in this document are suggested defaults that have been tested and proven to work together. They should be presented to users as recommendations, not requirements. Always:

1. **Present Suggestions**: Offer the documented defaults as starting points
2. **Confirm with User**: Ask for user approval before using any static values
3. **Allow Customization**: Support user-provided alternatives for all parameters
4. **Validate Compatibility**: Ensure user-provided values will work with the architecture

### Infrastructure and Deployment
1. **Bicep Primary**: Use Bicep templates as the primary deployment method. ARM templates are legacy (archived)
2. **Phased Deployment**: Follow the 5-phase deployment pattern to avoid Azure timeouts:
   - Phase 1: Core infrastructure (VWAN, VNets, NSGs)
   - Phase 2: Virtual machines (NVA, test VMs)  
   - Phase 3: Route Server deployment
   - Phase 4: VWAN connections and peering
   - Phase 5: BGP peering configuration
3. **Conditional Deployment**: Templates check for existing resources to avoid conflicts
4. **Resource Naming**: Use `environmentPrefix` parameter consistently (default: 'vwanlab')

### Security and Access
5. **Automated RDP**: Templates auto-create RDP rules using deployer IP detection
6. **NSG Best Practices**: Don't add explicit deny-all rules (Azure has implicit deny)
7. **Parameter Security**: Use `@secure()` decorator for passwords and sensitive values
8. **IP Restrictions**: Limit access to deployer IP/32 for security
9. **Secure Future Initiative (SFI)**: Enable Just-In-Time (JIT) VM access with `-SfiEnable` switch for enhanced security

### BGP and Networking  
10. **BGP Troubleshooting**: Use `Check-VwanBgpArchitecture.ps1` to validate VWAN and Route Server detection
11. **Route Injection**: NVA must peer directly with VWAN hub for route injection (Route Server doesn't auto-inject)
12. **ASN Management**: Suggest NVA ASN 65001, Azure services use ASN 65515 (confirm with user before implementation)
13. **IP Address Planning**: Follow the suggested subnet allocation for each spoke (confirm ranges with user)

### Default Values and User Confirmation
14. **Suggested IP Ranges**: Use the documented IP ranges as defaults but always confirm with user before deployment
15. **ASN Defaults**: Suggest ASN 65001 for NVA, but verify user preference before BGP configuration  
16. **Parameter Validation**: Present default values and ask for user confirmation on critical network settings
17. **Flexibility**: All static values (IPs, ASNs, naming) should be treated as suggestions, not requirements

### Security Enhancements
18. **JIT Access**: Use `-SfiEnable` switch to configure Just-In-Time VM access (Secure Future Initiative)
19. **Auto-Shutdown**: Use `-EnableAutoShutdown` to reduce costs and improve security posture
20. **Fallback Security**: JIT configuration falls back to restrictive NSG rules if Defender for Cloud unavailable

### Code Quality
21. **Error Handling**: Include comprehensive error handling in PowerShell scripts
22. **Validation**: Always test Bicep templates with `az bicep build` before deployment
23. **Documentation**: Update docs in `/docs` folder when making architectural changes
24. **Legacy Management**: Archive outdated scripts/templates instead of deleting
25. **Flexible Defaults**: Provide suggested values for IP ranges, ASNs, and naming but make them user-configurable

### Critical Knowledge for AI Assistants
26. **VWAN Hub BGP IPs**: Default BGP router addresses are 10.0.32.6 and 10.0.32.5 (Azure auto-assigned)
27. **Route Server Detection**: Use `Get-AzRouteServer` cmdlet, not `Get-AzVirtualNetworkGateway`
28. **Mixed Resource Groups**: VWAN resources may be mixed with other resource types - filter appropriately
29. **Conditional Bicep**: Use `concat()` and conditional arrays for dynamic NSG rule creation
30. **Parameter Passing**: Always pass `deployerPublicIP` parameter through all deployment phases
31. **BGP Architecture**: Route Server peering ≠ VWAN route injection (separate configurations needed)
32. **User Confirmation Required**: Always confirm IP ranges, ASN values, and naming conventions with user before deployment
33. **Suggest Defaults**: Present tested default values but allow user customization for all network parameters
34. **SFI Implementation**: JIT access requires Defender for Cloud; fallback to NSG rules if unavailable

## Common Issues and Solutions

### BGP Troubleshooting
- **VWAN Hub Detection**: If BGP scripts fail to find VWAN hubs, check for mixed resource types in resource groups
- **Route Injection**: Direct NVA-to-VWAN peering required; Route Server doesn't automatically inject routes to VWAN
- **BGP Status**: Use `Get-BgpStatus.ps1` to check peering status and route advertisements

### Deployment Issues  
- **Timeouts**: Use phased deployment approach for large infrastructures
- **VM Creation**: Check existing VMs before deployment to avoid conflicts
- **NSG Rules**: RDP rules are auto-created during deployment based on deployer IP

### Security Configurations
- **RDP Access**: Automatically configured from deployer IP during deployment
- **BGP Ports**: Port 179 allowed within VirtualNetwork scope
- **ICMP**: Enabled for connectivity testing between spokes

### File Organization
- **Active Code**: `/bicep/phases/` for current infrastructure templates
- **Legacy Code**: `/archive/` for outdated scripts and ARM templates  
- **Documentation**: `/docs/` for architecture and troubleshooting guides
- **Automation**: `/src/VwanLabAutomation/` for .NET cleanup utilities

## Key Commands and Scripts

### Primary Deployment
```powershell
# Full lab deployment with auto-RDP configuration
./scripts/Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### BGP Management
```powershell  
# Check BGP architecture and status
./scripts/Check-VwanBgpArchitecture.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Configure BGP peering
./scripts/Configure-NvaBgp.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

### Security Configuration
```powershell
# Configure Just-In-Time (JIT) VM access (SFI)
./scripts/Set-VmJitAccess.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Configure auto-shutdown for cost optimization
./scripts/Set-VmAutoShutdown.ps1 -ResourceGroupName "rg-vwanlab-demo"

# Deploy with SFI and auto-shutdown enabled
./scripts/Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-security" -SfiEnable -EnableAutoShutdown
```

### Troubleshooting
```powershell
# Test connectivity between spokes
./scripts/Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-demo" -Detailed

# Get lab status and health
./scripts/Get-LabStatus.ps1 -ResourceGroupName "rg-vwanlab-demo"
```

## Technologies Used

- Azure Bicep
- Azure Resource Manager (ARM) Templates
- PowerShell
- .NET 8
- Azure CLI
- Azure PowerShell modules

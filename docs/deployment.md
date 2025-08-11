# VWAN Lab Deployment Guide

This guide provides comprehensive step-by-step instructions for deploying the Azure Virtual WAN lab environment using the **enhanced deployment system** with flexible resource management, automated VM configuration, and security features.

## 🚀 **What's New in Enhanced Deployment**

### ✅ **Major Enhancements**
- **Automatic VM Configuration** - RDP access, RRAS installation, and credential management
- **Security Features** - Deployer IP-based RDP access, password complexity validation
- **Enhanced Logging** - Comprehensive RRAS installation logging for troubleshooting
- **Flexible Resource Group Management** - Deploy to new RGs while cleaning up old ones
- **IP Schema Selection** - Choose from predefined schemas or create custom configurations
- **Background Cleanup Integration** - Automatic cleanup of old resources during deployment
- **Prompt-less Operations** - Fully automated workflows for CI/CD integration
- **Real-time Monitoring** - Live progress tracking and status updates
- **Enhanced Error Handling** - Comprehensive validation and recovery mechanisms

### ✅ **New Security & Access Features**
- **Interactive Credential Prompts** - Secure credential collection with validation
- **Password Complexity Enforcement** - Azure VM requirements automatically validated
- **Automatic RDP Configuration** - NSG rules created for deployer IP only
- **Windows Firewall Management** - RDP enabled through Windows Firewall
- **RRAS Automation** - Automatic installation and configuration with detailed logging

### ✅ **Deployment Options**
1. **Unified Deployment** (`Deploy-VwanLab.ps1`) - ⭐ **Recommended** (Updated with new features)
2. **Enhanced Deployment** (`Deploy-VwanLab-Enhanced.ps1`) - Legacy compatibility
3. **Standalone Cleanup** (`Cleanup-ResourceGroups.ps1`) - Independent resource management

## Prerequisites

### Required Tools

- **Azure CLI** or **Azure PowerShell** 
- **Bicep CLI** (for Bicep deployments) - ✅ **Updated to latest version**
- **.NET 8 SDK** (for automation tools) - ✅ **Updated from .NET 6**
- **PowerShell 7+** (recommended) or **Windows PowerShell 5.1**

### Azure Requirements

- **Azure Subscription** with appropriate permissions
- **Resource Group Contributor** role or higher
- **Network Contributor** role for networking resources
- **Virtual Machine Contributor** role for VM operations
- **Subscription-level permissions** for resource group creation (enhanced deployment)

### VM Administrator Credentials

When deploying VMs (Full mode or Phase 2), the script will prompt for:
- **VM Administrator Username** - Cannot be 'admin', 'administrator', 'root', or 'guest'
- **VM Administrator Password** - Must meet Azure VM complexity requirements:
  - 8-123 characters length
  - Must contain 3 of: lowercase, uppercase, digit, special character
  - Cannot contain the username

### Installation Commands

```powershell
# Install Azure CLI and Bicep
winget install -e --id Microsoft.AzureCLI
az bicep install

# Install Azure PowerShell
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Install .NET 8 SDK
winget install -e --id Microsoft.DotNet.SDK.8

# Verify installations
az --version
bicep --version
dotnet --version
```

## 🚀 **Quick Start - Enhanced Deployment (Recommended)**

### **Step 1: Environment Setup**

```powershell
# Clone the repository
git clone <repository-url>
cd vwanlab

# Login to Azure
az login
# OR
Connect-AzAccount

# Set subscription (if needed)
az account set --subscription "your-subscription-id"
# OR
Set-AzContext -SubscriptionId "your-subscription-id"
```

### **Step 2: Enhanced Deployment**

```powershell
# Option A: Interactive deployment with IP schema selection
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-vwanlab-new"

# Option B: Automated deployment with predefined schema
.\scripts\Deploy-VwanLab-Enhanced.ps1 `
    -ResourceGroupName "rg-vwanlab-prod" `
    -IpSchema "enterprise" `
    -Location "East US" `
    -SkipIpPrompt

# Option C: Deployment with automatic cleanup of old resources
.\scripts\Deploy-VwanLab-Enhanced.ps1 `
    -ResourceGroupName "rg-vwanlab-v2" `
    -CleanupResourceGroup "rg-vwanlab-v1" `
    -IpSchema "default"
```

### **Step 3: Monitor Deployment**

```powershell
# Check deployment status
.\scripts\Get-LabStatus.ps1 -ResourceGroupName "rg-vwanlab-new" -ShowDetails

# Monitor cleanup jobs (if using cleanup)
.\scripts\Cleanup-ResourceGroups.ps1 -ListJobs

# Test connectivity after deployment
.\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-new" -Detailed
```

## 🎯 **Available IP Schemas**

The enhanced deployment system supports multiple predefined IP address schemas:

| Schema | Description | Use Case | Hub CIDR | Spoke 1 CIDR | Spoke 2 CIDR |
|--------|-------------|----------|----------|--------------|--------------|
| **default** | Standard lab setup | Development/Testing | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **enterprise** | Enterprise-scale | Production environments | 172.16.0.0/12 | 192.168.1.0/24 | 192.168.2.0/24 |
| **lab** | Compact lab | Resource-constrained | 10.10.0.0/16 | 10.11.0.0/16 | 10.12.0.0/16 |
| **custom** | User-defined | Special requirements | *Interactive* | *Interactive* | *Interactive* |

### **Schema Selection Examples**

```powershell
# Use enterprise schema for production
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-prod-vwanlab" -IpSchema "enterprise"

# Use lab schema for development
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-dev-vwanlab" -IpSchema "lab"

# Interactive custom schema selection
.\scripts\Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-custom-vwanlab" -IpSchema "custom"
```

## 🔄 **Deployment Methods**

### **🔥 Method 1: Unified Deployment (Recommended)**

The enhanced `Deploy-VwanLab.ps1` script provides the most streamlined deployment experience with automatic VM configuration and security features.

#### **Option 1A: Standard Deployment with Interactive Credentials**
```powershell
# Deploy with interactive credential prompts (recommended for first-time deployment)
./scripts/Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -Location "East US"
```

#### **Option 1B: Deployment with Pre-specified Credentials**
```powershell
# Deploy with credentials specified as parameters
$securePassword = ConvertTo-SecureString "YourSecureP@ssw0rd!" -AsPlainText -Force
./scripts/Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -Location "East US" -VmUsername "azureuser" -VmPassword $securePassword
```

#### **Option 1C: Full Deployment with Custom IP Schema**
```powershell
# Deploy with custom IP schema and specific configuration
./scripts/Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -Location "East US" -IpSchema "custom" -Mode "Full" -SkipBgpConfiguration:$false
```

#### **Key Features of Unified Deployment:**
- ✅ **Automatic credential validation** with complexity checks
- ✅ **RDP access configuration** for deployer IP only
- ✅ **RRAS installation and configuration** with comprehensive logging
- ✅ **Windows Firewall management** for secure remote access
- ✅ **Real-time deployment progress** with status updates
- ✅ **Enhanced error handling** and recovery mechanisms

### **🔧 Method 2: Enhanced Deployment (Legacy Compatibility)**

For backward compatibility and advanced scenarios, use the enhanced deployment script:

```powershell
# Enhanced deployment with all features
./scripts/Deploy-VwanLab-Enhanced.ps1 -ResourceGroupName "rg-vwanlab-demo" -Location "East US" -IpSchema "schema1"
```

### **📋 Method 3: Traditional Deployment Methods**

#### **Option 3A: PowerShell Script (Original)**

```powershell
# Deploy using traditional method
.\scripts\Deploy-VwanLab.ps1 -ParameterFile ".\bicep\parameters\lab.bicepparam"

# Or with ARM templates
.\scripts\Deploy-VwanLab.ps1 `
    -TemplateFile ".\arm-templates\main.json" `
    -ParameterFile ".\arm-templates\parameters\lab.parameters.json"
```

#### **Option 3B: Azure CLI with Bicep**

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Create resource group
az group create --name "rg-vwanlab" --location "East US"

# Deploy using Bicep (✅ Fixed templates)
az deployment group create \
  --resource-group "rg-vwanlab" \
  --template-file "./bicep/main.bicep" \
  --parameters "./bicep/parameters/lab.bicepparam"
```

#### **Option 3C: .NET Automation Tool**

```powershell
# Navigate to the automation tool
cd src/VwanLabAutomation

# Build the tool
dotnet build

# Deploy the lab
dotnet run -- deploy \
  --subscription "your-subscription-id" \
  --resource-group "rg-vwanlab-demo" \
  --location "East US"

# Check deployment status
dotnet run -- status \
  --subscription "your-subscription-id" \
  --resource-group "rg-vwanlab-demo"
```

## **🔐 Credential Management**

### **Interactive Credential Collection**
When deploying VMs, the script will securely prompt for credentials:

```
Enter VM Administrator Username: azureuser
Enter VM Administrator Password: [securely masked input]
```

### **Credential Validation**
The deployment script automatically validates:
- **Username restrictions** (cannot be admin, administrator, root, guest)
- **Password complexity** (Azure VM requirements)
- **Character length** (8-123 characters)
- **Character composition** (3 of 4 character types required)

### **Security Features**
- **Deployer IP Detection** - Automatically detects your public IP for RDP access
- **NSG Rule Creation** - Creates RDP rules for deployer IP only
- **Windows Firewall Configuration** - Enables RDP through Windows Firewall
- **Secure Password Handling** - All passwords are handled as SecureString objects

## **⚙️ Automatic VM Configuration**

### **RDP Access Setup**
The deployment automatically configures:
1. **Network Security Group Rules** - RDP access for deployer IP
2. **Windows Firewall** - Enables RDP through Windows Firewall
3. **Remote Desktop Service** - Ensures RDP service is running

### **RRAS Installation and Configuration**
For NVA VMs, the script automatically:
1. **Installs RRAS Role** - Routing and Remote Access Service
2. **Configures BGP** - Sets up BGP routing for VWAN connectivity
3. **Creates Logging** - Detailed logs at `C:\Windows\Temp\rras-install.log`
4. **Validates Installation** - Confirms RRAS is properly configured

## **📋 Deployment Parameters**

### Core Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `ResourceGroupName` | Target resource group name | None | ✅ Yes |
| `Location` | Azure region for deployment | "East US" | No |
| `VmUsername` | VM administrator username | Interactive prompt | No |
| `VmPassword` | VM administrator password (SecureString) | Interactive prompt | No |
| `IpSchema` | IP addressing schema | "schema1" | No |
| `Mode` | Deployment mode (Full/InfraOnly) | "Full" | No |
| `SkipBgpConfiguration` | Skip BGP setup | $false | No |

### Advanced Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `WhatIf` | Preview deployment without execution | $false | No |
| `Force` | Skip confirmation prompts | $false | No |
| `CleanupOldRgs` | Remove old resource groups | $true | No |
| `UseExistingRg` | Use existing resource group | $false | No |

## 🧹 **Standalone Resource Cleanup**

### **Independent Cleanup Operations**

```powershell
# Clean up a single resource group (prompt-less)
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-old-vwanlab" -Force

# Clean up multiple resource groups
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupNames @("rg-old-1", "rg-old-2", "rg-old-3") -Force

# Clean up with completion wait
.\scripts\Cleanup-ResourceGroups.ps1 -ResourceGroupName "rg-temp-vwanlab" -Force -WaitForCompletion -Timeout 90
```

### **Cleanup Monitoring**

```powershell
# List all active cleanup jobs
.\scripts\Cleanup-ResourceGroups.ps1 -ListJobs

# Check specific job details
.\scripts\Cleanup-ResourceGroups.ps1 -CheckJob -JobId 123

# Clean up completed jobs from memory
.\scripts\Cleanup-ResourceGroups.ps1 -CleanupCompletedJobs
```

## 📋 **Detailed Deployment Steps**

### **Step 1: Prepare Configuration**

1. **Review Parameters**
   
   Edit `bicep/parameters/lab.bicepparam`:
   ```bicep
   param environmentPrefix = 'vwanlab'        // Your environment prefix
   param primaryRegion = 'East US'            // Your preferred region
   param adminUsername = 'azureuser'          // VM admin username
   param adminPassword = 'YourSecurePassword' // VM admin password
   ```

2. **Validate Settings**
   
   ```powershell
   # Check available regions
   Get-AzLocation | Where-Object {$_.Providers -contains "Microsoft.Network"}
   
   # Validate VM sizes
   Get-AzVMSize -Location "East US" | Where-Object {$_.Name -like "Standard_D*"}
   ```

### Step 2: Deploy Infrastructure

1. **Validate Template**
   
   ```powershell
   # Test deployment (What-If)
   .\scripts\Deploy-VwanLab.ps1 -ParameterFile ".\bicep\parameters\lab.bicepparam" -WhatIf
   ```

2. **Deploy Resources**
   
   ```powershell
   # Full deployment
   .\scripts\Deploy-VwanLab.ps1 -ParameterFile ".\bicep\parameters\lab.bicepparam"
   ```

3. **Monitor Deployment**
   
   ```powershell
   # Check deployment status
   Get-AzResourceGroupDeployment -ResourceGroupName "rg-vwanlab-demo" | Select-Object DeploymentName, ProvisioningState, Timestamp
   ```

### Step 3: Configure Network Virtual Appliance

1. **Configure RRAS on NVA VM**
   
   ```powershell
   # Configure RRAS and BGP
   .\scripts\Configure-NvaVm.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-nva-vm"
   ```

2. **Verify BGP Configuration**
   
   ```powershell
   # The script will automatically test BGP connectivity
   # Check the output for BGP peer status
   ```

### Step 4: Test Connectivity

1. **Basic Connectivity Tests**
   
   ```powershell
   # Run connectivity tests
   .\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-demo"
   ```

2. **Detailed Analysis**
   
   ```powershell
   # Run detailed tests with routing information
   .\scripts\Test-Connectivity.ps1 -ResourceGroupName "rg-vwanlab-demo" -Detailed
   ```

## Deployment Validation

### Check Resource Creation

```powershell
# List all resources
Get-AzResource -ResourceGroupName "rg-vwanlab-demo" | Format-Table Name, ResourceType, Location

# Check Virtual WAN
Get-AzVirtualWan -ResourceGroupName "rg-vwanlab-demo"

# Check Virtual Hub
Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo"

# Check VNets
Get-AzVirtualNetwork -ResourceGroupName "rg-vwanlab-demo"

# Check VMs
Get-AzVM -ResourceGroupName "rg-vwanlab-demo"
```

### Verify Network Connectivity

```powershell
# Check VNet connections to VWAN Hub
$hub = Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo"
Get-AzVirtualHubVnetConnection -ResourceGroupName "rg-vwanlab-demo" -VirtualHubName $hub.Name
```

### Test VM Access

```powershell
# Get public IP addresses
Get-AzPublicIpAddress -ResourceGroupName "rg-vwanlab-demo" | Select-Object Name, IpAddress

# Test RDP connectivity (from your local machine)
Test-NetConnection -ComputerName "vm-public-ip" -Port 3389
```

## Troubleshooting Common Issues

### Deployment Failures

1. **Insufficient Permissions**
   ```powershell
   # Check current permissions
   Get-AzRoleAssignment -Scope "/subscriptions/your-subscription-id"
   ```

2. **Resource Name Conflicts**
   ```powershell
   # Update environment prefix in parameters
   # Delete existing resources if needed
   ```

3. **Quota Limitations**
   ```powershell
   # Check VM quota
   Get-AzVMUsage -Location "East US"
   
   # Check network quota
   Get-AzNetworkUsage -Location "East US"
   ```

### RRAS Configuration Issues

1. **BGP Peer Connection Failed**
   ```powershell
   # Check Route Server IPs
   $routeServer = Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo" | Where-Object {$_.Name -like "*route-server*"}
   $routeServer.VirtualRouterIps
   
   # Reconfigure BGP on NVA
   .\scripts\Configure-NvaVm.ps1 -ResourceGroupName "rg-vwanlab-demo" -VmName "vwanlab-nva-vm" -RouteServerIps @("ip1", "ip2")
   ```

2. **Routing Issues**
   ```powershell
   # Check effective routes on VM NICs
   $vm = Get-AzVM -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-test1-vm"
   $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
   Get-AzEffectiveRouteTable -NetworkInterfaceName $nic.Name -ResourceGroupName "rg-vwanlab-demo"
   ```

### Connectivity Issues

1. **VMs Not Reachable**
   ```powershell
   # Check NSG rules
   Get-AzNetworkSecurityGroup -ResourceGroupName "rg-vwanlab-demo" | ForEach-Object {
       Write-Host "NSG: $($_.Name)"
       $_.SecurityRules | Select-Object Name, Protocol, SourcePortRange, DestinationPortRange, Access
   }
   ```

2. **Inter-VNet Connectivity Failed**
   ```powershell
   # Check VWAN hub routing
   $hub = Get-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo"
   # Review hub configuration and VNet connections
   ```

## Post-Deployment Configuration

### Optional Enhancements

1. **Add Custom Routes**
   ```powershell
   # Add custom route advertisement on NVA
   # This would be done through RRAS configuration
   ```

2. **Configure Monitoring**
   ```powershell
   # Enable Network Watcher
   New-AzNetworkWatcher -ResourceGroupName "rg-vwanlab-demo" -Name "nw-vwanlab" -Location "East US"
   
   # Create Connection Monitor
   # (Additional configuration required)
   ```

3. **Set Up Alerts**
   ```powershell
   # Create alert rules for BGP session monitoring
   # (Configure through Azure Monitor)
   ```

## Cleanup

### Remove All Resources

```powershell
# Remove the entire resource group
Remove-AzResourceGroup -Name "rg-vwanlab-demo" -Force

# Or use the automation tool
cd src/VwanLabAutomation
dotnet run -- cleanup --subscription "your-subscription-id" --resource-group "rg-vwanlab-demo" --force
```

### Selective Cleanup

```powershell
# Remove only VMs (keep networking)
Get-AzVM -ResourceGroupName "rg-vwanlab-demo" | Remove-AzVM -Force

# Remove only VWAN resources
Remove-AzVirtualHub -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-hub" -Force
Remove-AzVirtualWan -ResourceGroupName "rg-vwanlab-demo" -Name "vwanlab-vwan" -Force
```

## Next Steps

After successful deployment:

1. **Explore BGP Configuration**: Modify BGP settings and observe route propagation
2. **Test Failover Scenarios**: Stop/start NVA VM and test connectivity
3. **Add Additional Spokes**: Deploy more spoke VNets to test scalability
4. **Implement Monitoring**: Set up comprehensive monitoring and alerting
5. **Security Hardening**: Implement additional security controls

## Support and Documentation

- **Azure Virtual WAN Documentation**: [Microsoft Docs](https://docs.microsoft.com/azure/virtual-wan/)
- **Azure Route Server Documentation**: [Microsoft Docs](https://docs.microsoft.com/azure/route-server/)
- **BGP Configuration Guide**: See `docs/configuration.md`
- **Troubleshooting Guide**: See `docs/troubleshooting.md`

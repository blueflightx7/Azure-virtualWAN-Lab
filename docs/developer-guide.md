# 🛠️ Azure Virtual WAN Lab - Developer Guide

<div align="center">

![Developer Guide](https://img.shields.io/badge/Guide-Developer-red?style=for-the-badge&logo=github)
![Architecture](https://img.shields.io/badge/Level-Advanced-orange?style=for-the-badge&logo=microsoft-azure)
![Bicep](https://img.shields.io/badge/IaC-Bicep%20%26%20ARM-blue?style=for-the-badge&logo=azure-devops)
![Automation](https://img.shields.io/badge/Automation-PowerShell%20%26%20.NET-purple?style=for-the-badge&logo=powershell)

*Comprehensive technical documentation for developers working on the Azure Virtual WAN lab project*

</div>

---

## 📋 Table of Contents

- [🏗️ Project Architecture](#️-project-architecture)
- [🧩 Component Deep Dive](#-component-deep-dive)
- [📁 Project Structure](#-project-structure)
- [🔧 Development Environment](#-development-environment)
- [📝 Infrastructure as Code](#-infrastructure-as-code)
- [⚙️ Automation & Scripting](#️-automation--scripting)
- [🔀 Build & Deployment Pipeline](#-build--deployment-pipeline)
- [🧪 Testing Strategy](#-testing-strategy)
- [🐛 Debugging & Troubleshooting](#-debugging--troubleshooting)
- [🚀 Extending the Project](#-extending-the-project)
- [📊 Performance Considerations](#-performance-considerations)
- [🔒 Security Best Practices](#-security-best-practices)
- [📈 Monitoring & Observability](#-monitoring--observability)

---

## 🏗️ Project Architecture

### **🎯 Design Principles**

This project was built following modern DevOps and Infrastructure as Code principles:

#### **1. Modularity & Reusability**
```
bicep/
├── main.bicep                 # Orchestration template
├── modules/
│   ├── vwan.bicep            # Self-contained VWAN module
│   ├── spoke-vnet-with-nva.bicep  # Complex networking with BGP
│   ├── spoke-vnet-direct.bicep    # Simple spoke implementation
│   └── vwan-connections.bicep     # Connection orchestration
└── parameters/
    └── lab.bicepparam        # Environment-specific configuration
```

#### **2. Multi-Tool Ecosystem**
- **Bicep**: Primary IaC with ARM fallback capability
- **PowerShell**: Deployment automation and VM configuration
- **.NET 8**: Advanced automation and monitoring tools
- **Azure CLI**: Cross-platform deployment support

#### **3. Error Resilience**
- **Automatic fallback mechanisms** (Bicep → ARM)
- **Comprehensive error handling** in all scripts
- **Detailed validation** before deployment
- **Rollback capabilities** through infrastructure versioning

### **🌐 Network Architecture Deep Dive**

#### **Addressing Scheme Design**

| Network Segment | CIDR | Purpose | Design Rationale |
|-----------------|------|---------|------------------|
| **VWAN Hub** | `10.0.0.0/16` | Central connectivity | Large address space for scalability |
| **Spoke 1** | `10.1.0.0/16` | NVA + Route Server | /26 subnets for precise control |
| **Spoke 2** | `10.2.0.0/16` | Direct connection | Standard hub-spoke model |

#### **Subnet Breakdown (Spoke 1)**

```bicep
// Calculated subnet architecture
var baseNetwork = '10.1.0'
var nvaSubnet = '${baseNetwork}.0/26'      // 10.1.0.0-10.1.0.63
var arsSubnet = '${baseNetwork}.64/26'     // 10.1.0.64-10.1.0.127  
var vmSubnet = '${baseNetwork}.128/26'     // 10.1.0.128-10.1.0.191
```

**Why /26 subnets?**
- **Azure Route Server**: Requires dedicated `/27` minimum subnet
- **NVA separation**: Isolates routing appliance traffic
- **Future expansion**: Room for additional subnets (64 addresses each)
- **Azure compliance**: Meets all Azure networking requirements

#### **BGP Routing Architecture**

```mermaid
graph TB
    subgraph "BGP Control Plane"
        ARS[Azure Route Server<br/>ASN: 65515<br/>IP: 10.1.0.68/69]
        NVA[Windows RRAS NVA<br/>ASN: 65001<br/>IP: 10.1.0.4]
        
        ARS -.eBGP Session.- NVA
    end
    
    subgraph "Data Plane"
        VWAN[VWAN Hub<br/>10.0.0.0/16]
        SPOKE1[Spoke 1 VNet<br/>10.1.0.0/16]
        SPOKE2[Spoke 2 VNet<br/>10.2.0.0/16]
        
        VWAN === SPOKE1
        VWAN === SPOKE2
    end
    
    subgraph "Route Propagation"
        ARS -.Injects Routes.- SPOKE1
        VWAN -.Hub Routes.- SPOKE2
    end
```

**BGP Session Details:**
- **Protocol**: eBGP (External BGP)
- **Authentication**: None (internal lab environment)
- **Route Filtering**: Accept all routes
- **Timers**: Default BGP timers (Keepalive: 60s, Hold: 180s)

---

## 🧩 Component Deep Dive

### **1. Virtual WAN Hub (`modules/vwan.bicep`)**

#### **Design Decisions**

```bicep
resource virtualWanHub 'Microsoft.Network/virtualHubs@2023-05-01' = {
  name: vwanHubName
  location: location
  properties: {
    addressPrefix: vwanHubAddressPrefix
    virtualWan: {
      id: virtualWan.id
    }
    sku: 'Standard'  // Required for BGP and custom routing
  }
}
```

**Why Standard SKU?**
- **BGP Support**: Basic SKU doesn't support BGP routing
- **Custom Routing**: Required for complex routing scenarios
- **ExpressRoute**: Future-proofs for ExpressRoute connectivity
- **VPN Gateway**: Enables site-to-site VPN scenarios

#### **Resource Dependencies**

```bicep
// Explicit dependency chain
Virtual WAN → Virtual WAN Hub → Route Tables → Connections
```

### **2. NVA Implementation (`modules/spoke-vnet-with-nva.bicep`)**

#### **Windows Server RRAS Configuration**

The NVA uses Windows Server 2022 with Routing and Remote Access Service (RRAS):

```bicep
resource nvaVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  properties: {
    osProfile: {
      computerName: nvaVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false  // Prevents reboot during lab
        provisionVMAgent: true
      }
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [{
        id: nvaNetworkInterface.id
        properties: {
          primary: true
        }
      }]
    }
  }
}
```

#### **IP Forwarding Configuration**

```bicep
resource nvaNetworkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  properties: {
    enableIPForwarding: true  // Critical for NVA functionality
    ipConfigurations: [{
      properties: {
        privateIPAllocationMethod: 'Static'
        privateIPAddress: '10.1.0.4'  // Predictable IP for BGP
        subnet: {
          id: nvaSubnet.id
        }
      }
    }]
  }
}
```

**Why Static IP?**
- **BGP Neighbor Configuration**: Route Server needs predictable peer IP
- **Routing Consistency**: Prevents IP changes from breaking BGP sessions
- **Troubleshooting**: Makes debugging easier with known addresses

### **3. Azure Route Server (`modules/spoke-vnet-with-nva.bicep`)**

#### **Implementation Details**

```bicep
resource azureRouteServer 'Microsoft.Network/virtualHubs@2023-05-01' = {
  name: routeServerName
  location: location
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true  // Enables spoke-to-spoke via NVA
  }
}

resource routeServerSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  name: 'RouteServerSubnet'  // Must be exactly this name
  properties: {
    addressPrefix: arsSubnetPrefix
    delegations: []
  }
}
```

#### **BGP Peering Configuration**

```bicep
resource bgpConnection 'Microsoft.Network/virtualHubs/bgpConnections@2023-05-01' = {
  parent: azureRouteServer
  name: 'bgp-connection-nva'
  properties: {
    peerAsn: 65001  // NVA's BGP ASN
    peerIp: '10.1.0.4'  // NVA's static IP
  }
}
```

**Route Server Technical Details:**
- **Management IP**: Auto-assigned by Azure (typically .68/.69)
- **ASN**: Always 65515 (Microsoft reserved ASN)
- **Route Advertisement**: Automatically advertises VNet routes
- **Route Learning**: Learns routes from BGP peers and injects into VNet

### **4. VWAN Connections (`modules/vwan-connections.bicep`)**

#### **Connection Types**

```bicep
// Spoke 1: Complex routing via Route Server
resource spokeVnet1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet1Id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToHubTransit: true
    enableInternetSecurity: false  // Allows internet access via spoke
  }
}

// Spoke 2: Standard VWAN connectivity
resource spokeVnet2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet2Id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToHubTransit: true
    enableInternetSecurity: false
  }
}
```

**Connection Design Rationale:**
- **Bidirectional Transit**: Enables hub-spoke and spoke-spoke communication
- **Internet Security Disabled**: Maintains existing internet access patterns
- **No Route Tables**: Uses default routing (can be customized later)

---

## 📁 Project Structure

### **📂 Directory Organization**

```
azure-vwan-lab/
├── 📁 bicep/                    # Infrastructure as Code
│   ├── 📄 main.bicep           # Main orchestration template
│   ├── 📄 main.json            # Compiled ARM template (auto-generated)
│   ├── 📁 modules/             # Reusable Bicep modules
│   │   ├── 📄 vwan.bicep       # Virtual WAN and hub
│   │   ├── 📄 spoke-vnet-with-nva.bicep  # Complex spoke with BGP
│   │   ├── 📄 spoke-vnet-direct.bicep    # Simple spoke
│   │   └── 📄 vwan-connections.bicep     # VNet connections
│   └── 📁 parameters/          # Environment configurations
│       └── 📄 lab.bicepparam   # Lab-specific parameters
├── 📁 arm-templates/           # ARM Template fallbacks
│   ├── 📄 main.json           # Compiled ARM template
│   └── 📁 parameters/
│       └── 📄 lab.parameters.json
├── 📁 scripts/                # PowerShell automation
│   ├── 📄 Deploy-VwanLab.ps1         # Main deployment script
│   ├── 📄 Configure-NvaVm.ps1        # NVA post-deployment config
│   ├── 📄 Test-Connectivity.ps1      # Connectivity validation
│   └── 📄 Troubleshoot-VwanLab.ps1   # Diagnostic automation
├── 📁 src/                    # .NET automation tools
│   └── 📁 VwanLabAutomation/  # C# automation project
│       ├── 📄 Program.cs       # CLI entry point
│       ├── 📄 VwanLabDeployer.cs     # Deployment logic
│       ├── 📄 VwanLabMonitor.cs      # Status monitoring
│       ├── 📄 VwanLabTester.cs       # Connectivity testing
│       └── 📄 VwanLabCleaner.cs      # Resource cleanup
├── 📁 docs/                   # Documentation
│   ├── 📄 user-guide.md       # End-user documentation
│   ├── 📄 developer-guide.md  # This document
│   ├── 📄 troubleshooting.md  # Troubleshooting guide
│   └── 📄 architecture.md     # Technical architecture
└── 📁 .vscode/               # VS Code configuration
    └── 📄 tasks.json         # Build and deployment tasks
```

### **🔄 File Relationships**

```mermaid
graph TD
    A[main.bicep] --> B[vwan.bicep]
    A --> C[spoke-vnet-with-nva.bicep]
    A --> D[spoke-vnet-direct.bicep]
    A --> E[vwan-connections.bicep]
    
    F[lab.bicepparam] --> A
    G[Deploy-VwanLab.ps1] --> A
    G --> H[main.json]
    
    I[Configure-NvaVm.ps1] --> C
    J[Test-Connectivity.ps1] --> A
    
    K[VwanLabAutomation] --> A
    K --> G
    
    style A fill:#e1f5fe
    style G fill:#fff3e0
    style K fill:#f3e5f5
```

---

## 🔧 Development Environment

### **🛠️ Required Tools & Versions**

| Tool | Minimum Version | Recommended | Purpose |
|------|----------------|-------------|---------|
| **PowerShell** | 5.1 | 7.3+ | Script execution and Azure automation |
| **Azure CLI** | 2.50.0 | Latest | Cross-platform Azure management |
| **Bicep CLI** | 0.20.0 | Latest | Infrastructure as Code |
| **Azure PowerShell** | 9.0.0 | Latest | PowerShell-based Azure management |
| **.NET SDK** | 8.0 | 8.0 LTS | C# automation tools |
| **VS Code** | 1.80.0 | Latest | Development environment |

### **🔌 VS Code Extensions**

```json
{
  "recommendations": [
    "ms-azuretools.vscode-bicep",     // Bicep language support
    "ms-vscode.azure-account",        // Azure authentication
    "ms-vscode.powershell",           // PowerShell debugging
    "ms-dotnettools.vscode-dotnet-runtime", // .NET support
    "ms-azuretools.vscode-azureresourcegroups" // Resource management
  ]
}
```

### **⚙️ Development Configuration**

#### **VS Code Tasks (`tasks.json`)**

```json
{
  "version": "2.0.0",
  "inputs": [
    {
      "id": "resourceGroupName",
      "description": "Resource Group Name",
      "default": "rg-networking-multi-vwanlab",
      "type": "promptString"
    }
  ],
  "tasks": [
    {
      "label": "Build Bicep Templates",
      "type": "shell",
      "command": "az",
      "args": ["bicep", "build", "--file", "./bicep/main.bicep"],
      "group": "build",
      "problemMatcher": []
    },
    {
      "label": "Validate Bicep Templates", 
      "type": "shell",
      "command": "az",
      "args": [
        "deployment", "group", "validate",
        "--resource-group", "${input:resourceGroupName}",
        "--template-file", "./bicep/main.bicep",
        "--parameters", "./bicep/parameters/lab.bicepparam"
      ],
      "group": "test"
    }
  ]
}
```

**Design Rationale:**
- **Input Prompts**: Dynamic resource group selection
- **Problem Matchers**: Integration with VS Code's error highlighting
- **Task Groups**: Organized by build, test, and deployment phases

---

## 📝 Infrastructure as Code

### **🎯 Bicep Design Patterns**

#### **1. Modular Architecture**

```bicep
// Main template orchestrates modules
module vwan 'modules/vwan.bicep' = {
  name: 'vwan-deployment'
  params: {
    vwanName: vwanName
    vwanHubName: vwanHubName
    vwanHubAddressPrefix: vwanHubAddressPrefix
    location: primaryRegion
    tags: tags
  }
}
```

**Benefits:**
- **Reusability**: Modules can be used in different contexts
- **Maintainability**: Changes isolated to specific components
- **Testing**: Individual modules can be validated separately
- **Collaboration**: Teams can work on different modules independently

#### **2. Parameter Management**

```bicep
// Parameter file structure (lab.bicepparam)
using './main.bicep'

param environmentPrefix = 'vwanlab'
param primaryRegion = 'East US'
param adminUsername = 'azureuser'
param adminPassword = readEnvironmentVariable('ADMIN_PASSWORD', 'SecureP@ssw0rd123!')
param vmSize = 'Standard_D2s_v3'
```

**Parameter Design Principles:**
- **Environment Variables**: Secrets from environment, not hardcoded
- **Sensible Defaults**: Working configuration out-of-the-box
- **Type Safety**: Strong typing prevents deployment errors
- **Documentation**: Clear descriptions for all parameters

#### **3. Resource Naming Strategy**

```bicep
// Consistent naming convention
var vwanName = '${environmentPrefix}-vwan'
var vwanHubName = '${environmentPrefix}-hub'
var spokeVnet1Name = '${environmentPrefix}-spoke1-vnet'
var nvaVmName = '${environmentPrefix}-nva-vm'
```

**Naming Convention:**
- **Format**: `{environmentPrefix}-{component}-{type}`
- **Benefits**: Easy identification, consistent patterns
- **Flexibility**: Environment prefix allows multiple deployments
- **Azure Compliance**: Meets Azure naming requirements

#### **4. Error Handling in Bicep**

```bicep
// Conditional resource creation
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = if (createPublicIP) {
  name: '${vmName}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    sku: {
      name: 'Standard'
    }
  }
}

// Safe property access
var publicIPId = createPublicIP ? publicIP.id : null
```

### **🔄 ARM Template Fallback Strategy**

#### **Compilation Process**

```powershell
# Automatic ARM compilation in deployment script
try {
    # Try Bicep first
    Write-Host "Compiling Bicep template..." -ForegroundColor Yellow
    az bicep build --file $bicepTemplate
    $templateFile = $bicepTemplate.Replace('.bicep', '.json')
} catch {
    # Fallback to pre-compiled ARM
    Write-Warning "Bicep compilation failed, using ARM template fallback"
    $templateFile = $armTemplate
}
```

**Why ARM Fallback?**
- **Bicep CLI Issues**: Not everyone has Bicep installed
- **CI/CD Compatibility**: Some pipelines don't support Bicep
- **Reliability**: Always have a working deployment path
- **Legacy Support**: Works with older Azure CLI versions

---

## ⚙️ Automation & Scripting

### **🔧 PowerShell Architecture**

#### **Main Deployment Script (`Deploy-VwanLab.ps1`)**

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = ".\bicep\parameters\lab.bicepparam",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipNvaConfiguration
)
```

**Script Design Principles:**
- **Parameter Validation**: Strong typing and mandatory parameters
- **Switch Parameters**: Boolean flags for different behaviors
- **Default Values**: Sensible defaults for optional parameters
- **Help Documentation**: Comprehensive help with examples

#### **Error Handling Strategy**

```powershell
function Deploy-Template {
    try {
        # Check if Bicep is available
        $bicepAvailable = Test-BicepAvailability
        
        if ($bicepAvailable) {
            $templateFile = Get-BicepTemplate
        } else {
            $templateFile = Get-ArmFallback
        }
        
        # Deploy template
        $deployment = New-AzResourceGroupDeployment @deploymentParams
        
    } catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        
        # Provide specific troubleshooting guidance
        if ($_.Exception.Message -like "*quota*") {
            Write-Warning "This appears to be a quota issue. Check your subscription limits."
        }
        
        throw
    }
}
```

#### **Path Conversion Logic**

```powershell
function Convert-BicepToArmPath {
    param([string]$BicepPath)
    
    # Handle different path formats
    $armPath = $BicepPath -replace '\.bicep$', '.json'
    $armPath = $armPath -replace '\\bicep\\', '\arm-templates\'
    $armPath = $armPath -replace '/bicep/', '/arm-templates/'
    
    return $armPath
}
```

**Why Complex Path Handling?**
- **Cross-Platform**: Works on Windows, Linux, macOS
- **Relative Paths**: Handles different working directories
- **File System Differences**: Accounts for path separator variations

### **🎯 .NET Automation Tool**

#### **Project Structure (`src/VwanLabAutomation/`)**

```csharp
// Program.cs - CLI entry point
public class Program
{
    public static async Task<int> Main(string[] args)
    {
        var app = new CommandLineApplication();
        app.Name = "VwanLabAutomation";
        app.Description = "Azure Virtual WAN Lab automation tool";
        
        // Register commands
        app.Command("deploy", DeployCommand.Configure);
        app.Command("status", StatusCommand.Configure);
        app.Command("test", TestCommand.Configure);
        app.Command("cleanup", CleanupCommand.Configure);
        
        return await app.ExecuteAsync(args);
    }
}
```

#### **Azure SDK Integration**

```csharp
// VwanLabMonitor.cs - Resource monitoring
public class VwanLabMonitor
{
    private readonly ResourceManagementClient _resourceClient;
    private readonly NetworkManagementClient _networkClient;
    
    public async Task<LabStatus> GetLabStatusAsync(string resourceGroupName)
    {
        var resources = await _resourceClient.Resources.ListByResourceGroupAsync(resourceGroupName);
        
        var status = new LabStatus
        {
            VirtualWan = await CheckVirtualWanAsync(resourceGroupName),
            VirtualHub = await CheckVirtualHubAsync(resourceGroupName),
            SpokeVnets = await CheckSpokeVnetsAsync(resourceGroupName),
            BgpPeering = await CheckBgpPeeringAsync(resourceGroupName)
        };
        
        return status;
    }
}
```

**Why .NET for Automation?**
- **Azure SDK**: Rich, strongly-typed Azure management APIs
- **Performance**: Faster than PowerShell for complex operations
- **Cross-Platform**: Runs on Windows, Linux, macOS
- **Maintainability**: Strong typing reduces runtime errors

---

## 🔀 Build & Deployment Pipeline

### **🚀 Deployment Flow**

```mermaid
graph TD
    A[Start Deployment] --> B{Prerequisites Check}
    B -->|Pass| C[Login to Azure]
    B -->|Fail| Z[Install Prerequisites]
    Z --> B
    
    C --> D{Resource Group Exists?}
    D -->|No| E[Create Resource Group]
    D -->|Yes| F[Validate Template]
    E --> F
    
    F --> G{Validation Pass?}
    G -->|No| H[Show Validation Errors]
    G -->|Yes| I[Deploy Infrastructure]
    H --> END[Exit with Error]
    
    I --> J{Deployment Success?}
    J -->|No| K[Show Deployment Errors]
    J -->|Yes| L[Configure NVA]
    K --> END
    
    L --> M[Test Connectivity]
    M --> N[Generate Report]
    N --> O[Deployment Complete]
```

### **📋 Validation Stages**

#### **1. Pre-deployment Validation**

```powershell
function Test-Prerequisites {
    $checks = @()
    
    # Check Azure CLI
    $checks += Test-AzureCLI
    
    # Check PowerShell modules
    $checks += Test-PowerShellModules
    
    # Check Azure authentication
    $checks += Test-AzureAuthentication
    
    # Check template files
    $checks += Test-TemplateFiles
    
    return $checks | Where-Object { $_.Status -eq 'Failed' }
}
```

#### **2. Template Validation**

```powershell
# Azure template validation
$validation = Test-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $templateFile `
    -TemplateParameterFile $parameterFile
    
if ($validation) {
    Write-Error "Template validation failed:"
    $validation | ForEach-Object {
        Write-Error "  - $($_.Message)"
    }
    return $false
}
```

#### **3. Post-deployment Verification**

```powershell
function Test-DeploymentSuccess {
    # Check resource creation
    $resources = Get-AzResource -ResourceGroupName $ResourceGroupName
    
    $expectedResources = @(
        'Microsoft.Network/virtualWans',
        'Microsoft.Network/virtualHubs', 
        'Microsoft.Network/virtualNetworks',
        'Microsoft.Compute/virtualMachines'
    )
    
    foreach ($type in $expectedResources) {
        if (!($resources | Where-Object ResourceType -eq $type)) {
            throw "Missing resource type: $type"
        }
    }
}
```

---

## 🧪 Testing Strategy

### **🔍 Test Categories**

#### **1. Unit Tests (Template Validation)**

```powershell
# Test individual Bicep modules
Describe "Bicep Module Tests" {
    Context "VWAN Module" {
        It "Should compile without errors" {
            { az bicep build --file "bicep/modules/vwan.bicep" } | Should -Not -Throw
        }
        
        It "Should have valid parameters" {
            $template = Get-Content "bicep/modules/vwan.bicep" -Raw
            $template | Should -Match "@description.*vwanName"
        }
    }
}
```

#### **2. Integration Tests (Full Deployment)**

```powershell
# Test complete deployment workflow
Describe "Integration Tests" {
    BeforeAll {
        $resourceGroupName = "rg-test-$(Get-Random)"
        New-AzResourceGroup -Name $resourceGroupName -Location "East US"
    }
    
    It "Should deploy successfully" {
        $deployment = .\scripts\Deploy-VwanLab.ps1 -ResourceGroupName $resourceGroupName
        $deployment.ProvisioningState | Should -Be "Succeeded"
    }
    
    AfterAll {
        Remove-AzResourceGroup -Name $resourceGroupName -Force
    }
}
```

#### **3. Connectivity Tests**

```csharp
// C# connectivity testing
public class ConnectivityTests
{
    [Test]
    public async Task ShouldPingBetweenSpokes()
    {
        var vm1IP = await GetVmPrivateIP("vwanlab-test-vm1");
        var vm2IP = await GetVmPrivateIP("vwanlab-test-vm2");
        
        var pingResult = await ExecuteRemoteCommand(vm1IP, $"ping {vm2IP}");
        Assert.That(pingResult.ExitCode, Is.EqualTo(0));
    }
    
    [Test]
    public async Task ShouldHaveBgpSession()
    {
        var routeServerStatus = await CheckRouteServerPeering();
        Assert.That(routeServerStatus.State, Is.EqualTo("Connected"));
    }
}
```

### **🎯 Test Automation**

#### **Continuous Testing Pipeline**

```yaml
# GitHub Actions example
name: Lab Testing Pipeline
on: [push, pull_request]

jobs:
  template-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Azure CLI
        uses: azure/CLI@v1
      - name: Validate Bicep templates
        run: |
          az bicep build --file bicep/main.bicep
          az deployment group validate \
            --resource-group ${{ secrets.TEST_RG }} \
            --template-file bicep/main.bicep
```

---

## 🐛 Debugging & Troubleshooting

### **🔍 Common Issues & Solutions**

#### **Issue 1: CIDR Calculation Errors**

**Problem:**
```
Error: The CIDR '10.1.0.1/24' is not valid for a subnet
```

**Root Cause:**
```bicep
// Incorrect - produces invalid CIDR
var invalidSubnet = '${baseNetwork}.1/24'  // Results in 10.1.0.1/24
```

**Solution:**
```bicep
// Correct - produces valid CIDR
var validSubnet = '${baseNetwork}.0/26'    // Results in 10.1.0.0/26
```

**Prevention:**
```bicep
// Use cidrSubnet function for complex calculations
var dynamicSubnet = cidrSubnet(vnetAddressSpace, 26, 0)
```

#### **Issue 2: Template Scope Conflicts**

**Problem:**
```
Error: Resource type 'Microsoft.Resources/resourceGroups' is not supported in scope 'resourceGroup'
```

**Root Cause:**
```bicep
targetScope = 'subscription'  // Wrong scope
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  // This creates resource group, but we're deploying TO a resource group
}
```

**Solution:**
```bicep
targetScope = 'resourceGroup'  // Correct scope
// Remove resource group creation from template
```

#### **Issue 3: BGP Peering Failures**

**Problem:** Route Server and NVA not establishing BGP session

**Diagnostic Commands:**
```powershell
# Check Route Server status
az network routeserver show \
  --name "vwanlab-route-server" \
  --resource-group $resourceGroupName

# Check BGP peer status
az network routeserver peering show \
  --name "bgp-connection-nva" \
  --routeserver "vwanlab-route-server" \
  --resource-group $resourceGroupName
```

**Common Causes:**
1. **NVA not configured**: Run `Configure-NvaVm.ps1`
2. **IP forwarding disabled**: Check network interface settings
3. **NSG blocking traffic**: Verify security group rules
4. **Wrong ASN numbers**: Verify BGP configuration

### **🛠️ Debugging Tools**

#### **Template Debugging**

```powershell
# Enable detailed ARM deployment logging
$deployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFile `
    -DeploymentDebugLogLevel All `
    -Verbose
```

#### **Network Debugging**

```powershell
# Check effective routes on VM
az network nic show-effective-route-table \
  --name "vwanlab-test-vm1-nic" \
  --resource-group $resourceGroupName

# Check NSG effective rules
az network nic list-effective-nsg \
  --name "vwanlab-test-vm1-nic" \
  --resource-group $resourceGroupName
```

---

## 🚀 Extending the Project

### **🔧 Adding New Components**

#### **1. Creating New Bicep Modules**

```bicep
// Template for new module: modules/new-component.bicep
@description('Description of the new component')
param componentName string

@description('Location for resources')
param location string = resourceGroup().location

// Resource definitions
resource newResource 'Microsoft.SomeProvider/resourceType@2023-01-01' = {
  name: componentName
  location: location
  properties: {
    // Configuration
  }
}

// Outputs
output resourceId string = newResource.id
output resourceName string = newResource.name
```

#### **2. Integration with Main Template**

```bicep
// Add to main.bicep
module newComponent 'modules/new-component.bicep' = {
  name: 'new-component-deployment'
  params: {
    componentName: '${environmentPrefix}-new-component'
    location: primaryRegion
  }
}
```

### **📈 Scalability Enhancements**

#### **Multi-Region Deployment**

```bicep
// Support multiple regions
param regions array = ['East US', 'West US 2']

resource multiRegionVwan 'Microsoft.Network/virtualWans@2023-05-01' = {
  name: vwanName
  location: regions[0]  // Primary region
  properties: {
    type: 'Standard'
    allowBranchToBranchTraffic: true
  }
}

// Deploy hubs in each region
resource regionalHubs 'Microsoft.Network/virtualHubs@2023-05-01' = [for (region, i) in regions: {
  name: '${vwanHubName}-${i}'
  location: region
  properties: {
    addressPrefix: cidrSubnet('10.0.0.0/8', 16, i)
    virtualWan: {
      id: multiRegionVwan.id
    }
  }
}]
```

#### **Dynamic Spoke Creation**

```bicep
// Parameter-driven spoke deployment
param spokeConfigurations array = [
  {
    name: 'production'
    addressSpace: '10.1.0.0/16'
    hasNva: true
    region: 'East US'
  }
  {
    name: 'development'
    addressSpace: '10.2.0.0/16' 
    hasNva: false
    region: 'West US 2'
  }
]

module spokes 'modules/spoke-vnet-dynamic.bicep' = [for spoke in spokeConfigurations: {
  name: '${spoke.name}-spoke-deployment'
  params: {
    spokeName: spoke.name
    addressSpace: spoke.addressSpace
    hasNva: spoke.hasNva
    location: spoke.region
  }
}]
```

### **🔒 Security Enhancements**

#### **Network Security Groups**

```bicep
// Enhanced NSG with detailed rules
resource enhancedNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentPrefix}-enhanced-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowBGP'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '10.1.0.64/26'  // Route Server subnet
          destinationAddressPrefix: '10.1.0.0/26'  // NVA subnet
          sourcePortRange: '*'
          destinationPortRange: '179'  // BGP port
        }
      }
      {
        name: 'DenyInternetOutbound'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}
```

---

## 📊 Performance Considerations

### **⚡ Deployment Optimization**

#### **Parallel Resource Creation**

```bicep
// Resources that can be created in parallel
resource vwan 'Microsoft.Network/virtualWans@2023-05-01' = {
  // VWAN definition
}

resource spokeVnet1 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  // Spoke 1 can be created in parallel with VWAN
}

resource spokeVnet2 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  // Spoke 2 can be created in parallel with VWAN
}

// Connections depend on both VWAN and VNets
resource connections 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  dependsOn: [
    vwan
    spokeVnet1
    spokeVnet2
  ]
}
```

#### **Resource Sizing Optimization**

```bicep
// VM size recommendations by use case
var vmSizeMapping = {
  development: 'Standard_B2s'      // Burstable, cost-effective
  testing: 'Standard_D2s_v3'       // Balanced, recommended
  production: 'Standard_D4s_v3'    // Higher performance
  demo: 'Standard_B1s'             // Minimal cost
}

param environmentType string = 'testing'
param vmSize string = vmSizeMapping[environmentType]
```

### **🔄 Network Performance**

#### **BGP Tuning**

```powershell
# NVA BGP optimization
netsh routing ip add routefilter name="AdvertiseSpecific" action=accept
netsh routing ip set interface "BGP_Interface" adv=enable metric=100

# Adjust BGP timers for faster convergence
netsh routing ip bgp set peer name="RouteServer" keepalive=30 holdtime=90
```

#### **Route Server Optimization**

```bicep
resource routeServer 'Microsoft.Network/virtualHubs@2023-05-01' = {
  properties: {
    allowBranchToBranchTraffic: true
    // Enable route propagation optimization
    preferredRoutingGateway: 'VpnGateway'  // or 'ExpressRoute'
  }
}
```

---

## 🔒 Security Best Practices

### **🛡️ Infrastructure Security**

#### **1. Secrets Management**

```bicep
// Use Key Vault for sensitive parameters
param keyVaultName string
param adminPasswordSecretName string = 'vm-admin-password'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: resourceGroup('security-rg')
}

// Reference secret securely
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  properties: {
    osProfile: {
      adminPassword: keyVault.getSecret(adminPasswordSecretName)
    }
  }
}
```

#### **2. Network Segmentation**

```bicep
// Implement micro-segmentation
resource nvaSubnetNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-nva-subnet'
  properties: {
    securityRules: [
      {
        name: 'AllowBGPFromRouteServer'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.1.0.64/26'  // Route Server subnet only
          destinationPort: '179'
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4000
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
```

#### **3. Identity and Access Management**

```bicep
// Managed Identity for VMs
resource vmManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${environmentPrefix}-vm-identity'
  location: location
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${vmManagedIdentity.id}': {}
    }
  }
}

// Role assignment for managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmManagedIdentity.id, 'NetworkContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: vmManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

---

## 📈 Monitoring & Observability

### **📊 Metrics and Alerts**

#### **Virtual WAN Monitoring**

```bicep
// Log Analytics workspace for centralized logging
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${environmentPrefix}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Diagnostic settings for VWAN Hub
resource vwanDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'vwan-diagnostics'
  scope: virtualWanHub
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'RouteServerLog'
        enabled: true
      }
      {
        category: 'GatewayDiagnosticLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
```

#### **BGP Session Monitoring**

```csharp
// C# monitoring service
public class BgpMonitoringService
{
    public async Task<BgpSessionHealth> CheckBgpSessionAsync(string resourceGroupName)
    {
        var routeServer = await _networkClient.VirtualHubs.GetAsync(resourceGroupName, "vwanlab-route-server");
        
        var bgpConnections = await _networkClient.VirtualHubBgpConnections.ListAsync(
            resourceGroupName, 
            "vwanlab-route-server"
        );
        
        var health = new BgpSessionHealth();
        foreach (var connection in bgpConnections)
        {
            health.Sessions.Add(new BgpSession
            {
                PeerIp = connection.PeerIp,
                PeerAsn = connection.PeerAsn,
                ConnectionState = connection.ConnectionState,
                RoutesReceived = connection.ProvisioningState == "Succeeded" ? 
                    await GetReceivedRoutesCountAsync(connection) : 0
            });
        }
        
        return health;
    }
}
```

### **🔍 Troubleshooting Dashboards**

#### **Azure Workbook Template**

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// VWAN Hub Connection Status\nAzureActivity\n| where ResourceProvider == \"Microsoft.Network\"\n| where ResourceType == \"virtualHubs/hubVirtualNetworkConnections\"\n| summarize count() by ActivityStatus, bin(TimeGenerated, 1h)",
        "size": 0,
        "title": "VWAN Connection Activity",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    },
    {
      "type": 3, 
      "content": {
        "version": "KqlItem/1.0",
        "query": "// BGP Session Metrics\nAzureMetrics\n| where ResourceProvider == \"Microsoft.Network\"\n| where MetricName == \"BgpPeerStatus\"\n| summarize avg(Average) by Resource, bin(TimeGenerated, 5m)",
        "title": "BGP Peer Status Over Time"
      }
    }
  ]
}
```

---

## 🎯 Conclusion

This developer guide provides comprehensive technical documentation for the Azure Virtual WAN lab project. The architecture emphasizes:

### **🏗️ Core Design Principles**
- **Modularity**: Reusable Bicep modules for different components
- **Reliability**: Multiple deployment paths and comprehensive error handling
- **Maintainability**: Clear code structure and thorough documentation
- **Extensibility**: Well-defined interfaces for adding new functionality

### **🚀 Key Technical Achievements**
- **Multi-tool ecosystem** supporting different developer preferences
- **Robust error handling** with automatic fallback mechanisms
- **Comprehensive testing strategy** from unit to integration levels
- **Production-ready patterns** for security, monitoring, and scalability

### **📈 Future Development Opportunities**
- **Multi-region deployment** with hub peering
- **Advanced security** with Azure Firewall integration
- **Monitoring enhancements** with custom dashboards
- **CI/CD pipeline** integration for automated testing

The project serves as both a learning platform for Azure Virtual WAN technologies and a reference implementation for enterprise-grade network automation using modern DevOps practices.

---

<div align="center">

**🛠️ Built for Developers, by Developers**

*Comprehensive. Maintainable. Extensible.*

![Made with Azure](https://img.shields.io/badge/Made%20with-Azure-blue?style=for-the-badge&logo=microsoft-azure)
![Powered by Bicep](https://img.shields.io/badge/Powered%20by-Bicep-orange?style=for-the-badge&logo=azure-devops)

</div>

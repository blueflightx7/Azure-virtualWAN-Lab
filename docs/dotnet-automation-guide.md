# .NET Automation Suite for Azure VWAN Lab

## Overview

The .NET automation suite provides advanced programmatic management capabilities for the Azure Virtual WAN lab environment. Built on .NET 8 with modern Azure SDKs, it offers reliable, scalable automation for deployment, monitoring, testing, and cleanup operations.

## Architecture

```
VwanLabAutomation/
├── Program.cs              # Main CLI interface with System.CommandLine
├── VwanLabDeployer.cs      # Deployment automation and orchestration
├── VwanLabMonitor.cs       # Real-time monitoring and status reporting
├── VwanLabTester.cs        # Connectivity testing and validation
├── VwanLabCleaner.cs       # Resource cleanup and management
├── appsettings.json        # Configuration and settings
└── VwanLabAutomation.csproj # Project dependencies and configuration
```

## Key Capabilities

### 🚀 **Deployment Management** (`VwanLabDeployer.cs`)
- **Orchestrated Phased Deployment**: Manages timeout-resistant multi-phase deployments
- **Template Validation**: Pre-deployment validation of Bicep/ARM templates
- **Parameter Management**: Dynamic parameter injection and validation
- **Progress Tracking**: Real-time deployment progress monitoring
- **Error Recovery**: Automatic retry logic and rollback capabilities

```csharp
// Example usage in deployment orchestration
public async Task DeployAsync(string subscription, string resourceGroup, 
    string location, string templateFile, string parametersFile)
{
    // Phase 1: Infrastructure validation and preparation
    await ValidateTemplateAsync(templateFile, parametersFile);
    
    // Phase 2: Resource group and prerequisite setup
    await EnsureResourceGroupAsync(resourceGroup, location);
    
    // Phase 3: Phased deployment execution
    await ExecutePhasedDeploymentAsync(templateFile, parametersFile);
    
    // Phase 4: Post-deployment validation
    await ValidateDeploymentAsync(resourceGroup);
}
```

### 📊 **Real-time Monitoring** (`VwanLabMonitor.cs`)
- **Resource Health Monitoring**: Continuous monitoring of all lab components
- **Performance Metrics**: BGP status, connectivity health, resource utilization
- **Cost Tracking**: Real-time cost analysis and budget monitoring
- **Alert Management**: Automated alerting for issues and thresholds
- **Dashboard Integration**: Integration with Azure Monitor and custom dashboards

```csharp
// Example monitoring capabilities
public async Task<LabStatus> GetStatusAsync(string subscription, string resourceGroup)
{
    var status = new LabStatus();
    
    // Monitor VWAN hub status
    status.VwanHub = await GetVwanHubStatusAsync(resourceGroup);
    
    // Monitor VM health
    status.VirtualMachines = await GetVmHealthAsync(resourceGroup);
    
    // Monitor Route Server BGP status
    status.RouteServer = await GetRouteServerStatusAsync(resourceGroup);
    
    // Monitor connectivity
    status.Connectivity = await TestConnectivityStatusAsync(resourceGroup);
    
    return status;
}
```

### 🧪 **Automated Testing** (`VwanLabTester.cs`)
- **Connectivity Validation**: End-to-end connectivity testing between all components
- **BGP Route Testing**: Validation of BGP route propagation and convergence
- **Performance Testing**: Network latency, throughput, and performance validation
- **Scenario Testing**: Complex multi-path routing scenario validation
- **Compliance Testing**: Security and configuration compliance checks

```csharp
// Example testing scenarios
public async Task<TestResults> TestConnectivityAsync(string subscription, 
    string resourceGroup, bool detailed)
{
    var results = new TestResults();
    
    // Test 1: Basic VM connectivity
    results.VmConnectivity = await TestVmConnectivityAsync(resourceGroup);
    
    // Test 2: VWAN hub routing
    results.VwanRouting = await TestVwanRoutingAsync(resourceGroup);
    
    // Test 3: BGP route propagation
    results.BgpRoutes = await TestBgpRoutePropagationAsync(resourceGroup);
    
    // Test 4: Route Server integration
    results.RouteServerIntegration = await TestRouteServerAsync(resourceGroup);
    
    if (detailed)
    {
        // Advanced performance and security tests
        results.Performance = await RunPerformanceTestsAsync(resourceGroup);
        results.Security = await RunSecurityTestsAsync(resourceGroup);
    }
    
    return results;
}
```

### 🧹 **Intelligent Cleanup** (`VwanLabCleaner.cs`)
- **Dependency-Aware Cleanup**: Intelligent cleanup respecting Azure resource dependencies
- **Selective Cleanup**: Cleanup specific components while preserving others
- **Background Operations**: Non-blocking cleanup with progress tracking
- **Cost Optimization**: Cleanup scheduling to minimize costs
- **Backup and Recovery**: Optional backup before cleanup operations

```csharp
// Example cleanup orchestration
public async Task CleanupAsync(string subscription, string resourceGroup, bool force)
{
    // Phase 1: Identify cleanup candidates
    var resources = await IdentifyCleanupCandidatesAsync(resourceGroup);
    
    // Phase 2: Dependency analysis
    var cleanupPlan = await CreateCleanupPlanAsync(resources);
    
    // Phase 3: Execute cleanup in dependency order
    await ExecuteCleanupPlanAsync(cleanupPlan, force);
    
    // Phase 4: Validate cleanup completion
    await ValidateCleanupAsync(resourceGroup);
}
```

## Command-Line Interface

### **Core Commands**

#### **Deploy Command**
```bash
# Full deployment with monitoring
dotnet run --project .\src\VwanLabAutomation -- deploy \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --location "East US" \
    --template-file ".\bicep\main.bicep" \
    --parameters-file ".\bicep\parameters\lab-demo-optimized.bicepparam"

# Quick deployment with defaults
dotnet run --project .\src\VwanLabAutomation -- deploy \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-demo"
```

#### **Status Monitoring**
```bash
# Quick status check
dotnet run --project .\src\VwanLabAutomation -- status \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod"

# Continuous monitoring mode (watches for changes)
dotnet run --project .\src\VwanLabAutomation -- status \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --watch \
    --interval 30
```

#### **Connectivity Testing**
```bash
# Basic connectivity tests
dotnet run --project .\src\VwanLabAutomation -- test \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod"

# Detailed testing with performance metrics
dotnet run --project .\src\VwanLabAutomation -- test \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --detailed \
    --output-format json \
    --export-results "test-results.json"
```

#### **Resource Cleanup**
```bash
# Interactive cleanup (with confirmation)
dotnet run --project .\src\VwanLabAutomation -- cleanup \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-old"

# Force cleanup (non-interactive)
dotnet run --project .\src\VwanLabAutomation -- cleanup \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-old" \
    --force

# Selective cleanup (preserve specific resources)
dotnet run --project .\src\VwanLabAutomation -- cleanup \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-test" \
    --preserve "vwan-hub,route-server"
```

## Advanced Features

### **Cost Management Integration**
```bash
# Real-time cost analysis
dotnet run --project .\src\VwanLabAutomation -- cost-analysis \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --period "last-7-days"

# Set budget alerts
dotnet run --project .\src\VwanLabAutomation -- set-budget \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --limit 500 \
    --alert-threshold 80 \
    --notification-email "admin@company.com"
```

### **Automated Reporting**
```bash
# Generate deployment report
dotnet run --project .\src\VwanLabAutomation -- generate-report \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --report-type "deployment-summary" \
    --output "deployment-report.html"

# Health status report
dotnet run --project .\src\VwanLabAutomation -- generate-report \
    --subscription "12345678-1234-1234-1234-123456789012" \
    --resource-group "rg-vwanlab-prod" \
    --report-type "health-status" \
    --schedule "daily" \
    --email-recipients "team@company.com"
```

## Integration Scenarios

### **CI/CD Pipeline Integration**

#### **GitHub Actions Example**
```yaml
name: Deploy VWAN Lab
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: '8.0.x'
    
    - name: Deploy VWAN Lab
      run: |
        dotnet run --project ./src/VwanLabAutomation -- deploy \
          --subscription "${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
          --resource-group "rg-vwanlab-${{ github.run_number }}" \
          --template-file "./bicep/main.bicep" \
          --parameters-file "./bicep/parameters/lab-demo-optimized.bicepparam"
    
    - name: Test Deployment
      run: |
        dotnet run --project ./src/VwanLabAutomation -- test \
          --subscription "${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
          --resource-group "rg-vwanlab-${{ github.run_number }}" \
          --detailed \
          --export-results "test-results.json"
    
    - name: Cleanup Previous Deployment
      if: success()
      run: |
        dotnet run --project ./src/VwanLabAutomation -- cleanup \
          --subscription "${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
          --resource-group "rg-vwanlab-${{ github.run_number | minus: 1 }}" \
          --force
```

#### **Azure DevOps Pipeline Example**
```yaml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  resourceGroupName: 'rg-vwanlab-$(Build.BuildNumber)'

stages:
- stage: Deploy
  displayName: 'Deploy VWAN Lab'
  jobs:
  - job: DeployJob
    displayName: 'Deploy Infrastructure'
    steps:
    - task: UseDotNet@2
      displayName: 'Use .NET 8'
      inputs:
        packageType: 'sdk'
        version: '8.0.x'
    
    - script: |
        dotnet run --project ./src/VwanLabAutomation -- deploy \
          --subscription "$(azureSubscriptionId)" \
          --resource-group "$(resourceGroupName)" \
          --template-file "./bicep/main.bicep" \
          --parameters-file "./bicep/parameters/lab-demo-optimized.bicepparam"
      displayName: 'Deploy VWAN Lab'
    
    - script: |
        dotnet run --project ./src/VwanLabAutomation -- test \
          --subscription "$(azureSubscriptionId)" \
          --resource-group "$(resourceGroupName)" \
          --detailed
      displayName: 'Test Deployment'
```

### **Monitoring Integration**

#### **Azure Monitor Integration**
```csharp
// Custom metrics integration
public async Task PublishCustomMetricsAsync(string resourceGroup, LabStatus status)
{
    var telemetryClient = new TelemetryClient();
    
    // Publish connectivity metrics
    telemetryClient.TrackMetric("VWAN.Connectivity.Score", status.ConnectivityScore);
    telemetryClient.TrackMetric("VWAN.BGP.Routes.Count", status.BgpRouteCount);
    telemetryClient.TrackMetric("VWAN.VM.Health.Percentage", status.VmHealthPercentage);
    
    // Publish custom events
    telemetryClient.TrackEvent("VWAN.Deployment.Phase.Completed", new Dictionary<string, string>
    {
        {"ResourceGroup", resourceGroup},
        {"Phase", "All"},
        {"Duration", status.DeploymentDuration.ToString()},
        {"Status", "Success"}
    });
}
```

#### **Power BI Integration**
```csharp
// Export data for Power BI dashboards
public async Task ExportToPowerBIAsync(string subscription, string resourceGroup)
{
    var data = await CollectLabDataAsync(subscription, resourceGroup);
    var powerBIData = new
    {
        Timestamp = DateTime.UtcNow,
        ResourceGroup = resourceGroup,
        VwanHubStatus = data.VwanHub.Status,
        ConnectivityScore = data.ConnectivityScore,
        CostPerHour = data.EstimatedCostPerHour,
        ResourceCount = data.ResourceCount,
        BgpRoutes = data.BgpRoutes.Count
    };
    
    await _powerBIService.PushDataAsync("vwan-lab-dataset", powerBIData);
}
```

## Configuration

### **appsettings.json Configuration**
```json
{
  "Azure": {
    "DefaultLocation": "East US",
    "DefaultVmSize": "Standard_B1s",
    "DefaultStorageType": "Standard_LRS",
    "TimeoutMinutes": 30,
    "RetryAttempts": 3
  },
  "Monitoring": {
    "HealthCheckInterval": 60,
    "MetricsRetentionDays": 30,
    "AlertThresholds": {
      "ConnectivityScore": 80,
      "VmHealthPercentage": 90,
      "CostPerHour": 1.0
    }
  },
  "Testing": {
    "ConnectivityTimeoutSeconds": 30,
    "PerformanceTestDuration": 300,
    "DetailedTestsEnabled": true
  },
  "Cleanup": {
    "AutoCleanupEnabled": false,
    "RetentionDays": 7,
    "PreserveNetworkingResources": true
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "VwanLabAutomation": "Debug"
    }
  }
}
```

### **Environment Variables**
```bash
# Azure authentication
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Application configuration
export VWAN_LAB_DEFAULT_LOCATION="East US"
export VWAN_LAB_DEFAULT_VM_SIZE="Standard_B1s"
export VWAN_LAB_MONITORING_ENABLED="true"
export VWAN_LAB_AUTO_CLEANUP_ENABLED="false"
```

## When to Use Each Component

### **Use the PowerShell Script When:**
- ✅ **Interactive deployments** with user prompts and confirmations
- ✅ **One-time deployments** or manual testing
- ✅ **Learning and experimentation** with different configurations
- ✅ **Quick troubleshooting** and immediate feedback
- ✅ **Local development** and testing scenarios

### **Use the .NET Automation When:**
- ✅ **Automated CI/CD pipelines** requiring programmatic control
- ✅ **Production environments** needing robust error handling
- ✅ **Continuous monitoring** and health checks
- ✅ **Complex orchestration** with multiple Azure subscriptions
- ✅ **Enterprise integration** with existing .NET applications
- ✅ **Advanced reporting** and analytics requirements
- ✅ **Cost management** and budget monitoring
- ✅ **Scheduled operations** and background processing

## Performance Benefits

### **PowerShell vs .NET Comparison**

| Feature | PowerShell Script | .NET Automation | Winner |
|---------|------------------|-----------------|---------|
| **Deployment Speed** | 15-25 minutes | 12-20 minutes | .NET ⚡ |
| **Error Recovery** | Manual retry | Automatic retry | .NET 🔄 |
| **Monitoring** | Basic status | Real-time metrics | .NET 📊 |
| **Resource Usage** | High memory | Optimized | .NET 💾 |
| **Parallel Operations** | Limited | Full async/await | .NET ⚡ |
| **Integration** | Command-line only | API + CLI | .NET 🔗 |
| **Learning Curve** | Easy | Moderate | PowerShell 📚 |
| **Customization** | Script modification | Code extension | .NET 🛠️ |

## Getting Started

### **1. Prerequisites**
```bash
# Install .NET 8 SDK
winget install Microsoft.DotNet.SDK.8

# Verify installation
dotnet --version
```

### **2. Build the Application**
```bash
# Navigate to the project directory
cd src/VwanLabAutomation

# Restore dependencies
dotnet restore

# Build the application
dotnet build

# Run tests (if available)
dotnet test
```

### **3. First Deployment**
```bash
# Deploy with basic configuration
dotnet run -- deploy \
    --subscription "your-subscription-id" \
    --resource-group "rg-vwanlab-test"

# Monitor the deployment
dotnet run -- status \
    --subscription "your-subscription-id" \
    --resource-group "rg-vwanlab-test"
```

### **4. Advanced Usage**
```bash
# Comprehensive testing
dotnet run -- test \
    --subscription "your-subscription-id" \
    --resource-group "rg-vwanlab-test" \
    --detailed

# Cleanup when done
dotnet run -- cleanup \
    --subscription "your-subscription-id" \
    --resource-group "rg-vwanlab-test" \
    --force
```

## Best Practices

### **Development**
- 🔹 Use configuration files for environment-specific settings
- 🔹 Implement comprehensive logging and telemetry
- 🔹 Follow async/await patterns for Azure SDK operations
- 🔹 Use dependency injection for testability
- 🔹 Implement proper error handling and retry logic

### **Operations**
- 🔹 Monitor resource quotas and limits
- 🔹 Implement cost alerts and budgets
- 🔹 Use staging environments for testing
- 🔹 Automate cleanup of temporary resources
- 🔹 Regular health checks and monitoring

### **Security**
- 🔹 Use Managed Identity when possible
- 🔹 Store secrets in Azure Key Vault
- 🔹 Implement least privilege access
- 🔹 Enable audit logging
- 🔹 Regular security reviews and updates

---

The .NET automation suite transforms the Azure VWAN lab from a manual deployment into a fully automated, enterprise-ready infrastructure platform with comprehensive monitoring, testing, and management capabilities.

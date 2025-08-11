#Requires -Version 5.1
<#
.SYNOPSIS
    Azure Virtual WAN Lab Troubleshooting Script
    
.DESCRIPTION
    Comprehensive troubleshooting script that automatically detects and fixes common issues
    encountered during Azure Virtual WAN lab deployment based on resolved issues from development.
    
.PARAMETER ResourceGroupName
    Name of the resource group for deployment (default: rg-networking-multi-vwanlab)
    
.PARAMETER SubscriptionId
    Azure subscription ID (optional)
    
.PARAMETER FixIssues
    Automatically attempt to fix detected issues
    
.PARAMETER SkipBicepInstall
    Skip automatic Bicep installation if not found
    
.PARAMETER Detailed
    Show detailed diagnostic information
    
.EXAMPLE
    .\Troubleshoot-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -FixIssues
    
.EXAMPLE
    .\Troubleshoot-VwanLab.ps1 -Detailed -SubscriptionId "12345678-1234-1234-1234-123456789012"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-networking-multi-vwanlab",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixIssues,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBicepInstall,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Global variables
$script:IssuesFound = @()
$script:IssuesFixed = @()
$script:FixesFailed = @()

# Helper function for colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Cyan" = "Cyan"
        "White" = "White"
        "Magenta" = "Magenta"
    }
    
    if ($colorMap.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colorMap[$Color]
    } else {
        Write-Host $Message
    }
}

# Function to add issue to tracking
function Add-Issue {
    param(
        [string]$Category,
        [string]$Issue,
        [string]$Severity = "Medium",
        [string]$Solution = ""
    )
    
    $issueObj = [PSCustomObject]@{
        Category = $Category
        Issue = $Issue
        Severity = $Severity
        Solution = $Solution
        Timestamp = Get-Date
    }
    
    $script:IssuesFound += $issueObj
    
    $severityColor = switch ($Severity) {
        "High" { "Red" }
        "Medium" { "Yellow" }
        "Low" { "Cyan" }
        default { "White" }
    }
    
    Write-ColorOutput ("[{0}] {1}: {2}" -f $Severity, $Category, $Issue) $severityColor
    if ($Detailed -and $Solution) {
        Write-ColorOutput "  Solution: $Solution" "White"
    }
}

# Function to mark issue as fixed
function Mark-Fixed {
    param([string]$Issue, [string]$Details = "")
    
    $script:IssuesFixed += "$Issue - $Details"
    Write-ColorOutput "✓ FIXED: ${Issue}" "Green"
    if ($Details) {
        Write-ColorOutput "  $Details" "White"
    }
}

# Function to mark fix as failed
function Mark-FixFailed {
    param([string]$Issue, [string]$ErrorMessage)
    
    $script:FixesFailed += "$Issue - $ErrorMessage"
    Write-ColorOutput "✗ FIX FAILED: ${Issue}" "Red"
    Write-ColorOutput "  Error: $ErrorMessage" "Red"
}

# Check Prerequisites
function Test-Prerequisites {
    Write-ColorOutput "`n=== Checking Prerequisites ===" "Cyan"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Add-Issue "Prerequisites" "PowerShell version $($PSVersionTable.PSVersion) is too old" "High" "Upgrade to PowerShell 5.1 or newer"
    } else {
        Write-ColorOutput "✓ PowerShell version: $($PSVersionTable.PSVersion)" "Green"
    }
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy
    if ($executionPolicy -eq "Restricted") {
        Add-Issue "Prerequisites" "PowerShell execution policy is Restricted" "High" "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        
        if ($FixIssues) {
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Mark-Fixed "PowerShell execution policy" "Set to RemoteSigned"
            } catch {
                Mark-FixFailed "PowerShell execution policy" $_.Exception.Message
            }
        }
    } else {
        Write-ColorOutput "✓ PowerShell execution policy: $executionPolicy" "Green"
    }
}

# Check Azure CLI installation and configuration
function Test-AzureCLI {
    Write-ColorOutput "`n=== Checking Azure CLI ===" "Cyan"
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $versionLine = ($azVersion | Select-Object -First 1)
            Write-ColorOutput "✓ Azure CLI installed: $versionLine" "Green"
        } else {
            throw "Azure CLI not found"
        }
    } catch {
        Add-Issue "Azure CLI" "Azure CLI not installed" "High" "Install using: winget install -e --id Microsoft.AzureCLI"
        
        if ($FixIssues) {
            try {
                Write-ColorOutput "Installing Azure CLI..." "Yellow"
                $installResult = winget install -e --id Microsoft.AzureCLI --silent
                if ($LASTEXITCODE -eq 0) {
                    Mark-Fixed "Azure CLI installation" "Installed successfully"
                } else {
                    Mark-FixFailed "Azure CLI installation" "Winget installation failed"
                }
            } catch {
                Mark-FixFailed "Azure CLI installation" $_.Exception.Message
            }
        }
        return
    }
    
    # Check Azure CLI login status
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-ColorOutput "✓ Logged into Azure CLI as: $($account.user.name)" "Green"
            Write-ColorOutput "  Subscription: $($account.name)" "White"
        } else {
            throw "Not logged in"
        }
    } catch {
        Add-Issue "Azure CLI" "Not logged into Azure CLI" "High" "Run: az login"
        
        if ($FixIssues) {
            Write-ColorOutput "Attempting to log into Azure CLI..." "Yellow"
            try {
                az login
                Mark-Fixed "Azure CLI login" "Successfully logged in"
            } catch {
                Mark-FixFailed "Azure CLI login" $_.Exception.Message
            }
        }
    }
}

# Check Bicep CLI
function Test-BicepCLI {
    Write-ColorOutput "`n=== Checking Bicep CLI ===" "Cyan"
    
    try {
        $bicepVersion = az bicep version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Bicep CLI installed: $bicepVersion" "Green"
        } else {
            throw "Bicep CLI not found"
        }
    } catch {
        Add-Issue "Bicep CLI" "Bicep CLI not installed" "Medium" "Run: az bicep install"
        
        if ($FixIssues -and !$SkipBicepInstall) {
            try {
                Write-ColorOutput "Installing Bicep CLI..." "Yellow"
                az bicep install
                if ($LASTEXITCODE -eq 0) {
                    Mark-Fixed "Bicep CLI installation" "Installed successfully"
                } else {
                    Mark-FixFailed "Bicep CLI installation" "Installation command failed"
                }
            } catch {
                Mark-FixFailed "Bicep CLI installation" $_.Exception.Message
            }
        }
    }
}

# Check PowerShell modules
function Test-PowerShellModules {
    Write-ColorOutput "`n=== Checking PowerShell Modules ===" "Cyan"
    
    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Network')
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-ColorOutput "✓ Module installed: $module" "Green"
        } else {
            $missingModules += $module
            Add-Issue "PowerShell Modules" "Missing module: $module" "Medium" "Run: Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser"
        }
    }
    
    if ($missingModules.Count -gt 0 -and $FixIssues) {
        foreach ($module in $missingModules) {
            try {
                Write-ColorOutput "Installing module: $module..." "Yellow"
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
                Mark-Fixed "PowerShell module installation" "Installed $module"
            } catch {
                Mark-FixFailed "PowerShell module installation" "$module - $($_.Exception.Message)"
            }
        }
    }
}

# Check Azure PowerShell authentication
function Test-AzurePowerShell {
    Write-ColorOutput "`n=== Checking Azure PowerShell Authentication ===" "Cyan"
    
    try {
        $context = Get-AzContext
        if ($context) {
            Write-ColorOutput "✓ Logged into Azure PowerShell as: $($context.Account.Id)" "Green"
            Write-ColorOutput "  Subscription: $($context.Subscription.Name)" "White"
            
            # Set subscription if provided
            if ($SubscriptionId -and $context.Subscription.Id -ne $SubscriptionId) {
                try {
                    Set-AzContext -SubscriptionId $SubscriptionId
                    Write-ColorOutput "✓ Switched to subscription: $SubscriptionId" "Green"
                } catch {
                    Add-Issue "Azure PowerShell" "Failed to switch to subscription $SubscriptionId" "Medium" "Verify subscription ID is correct"
                }
            }
        } else {
            throw "Not logged in"
        }
    } catch {
        Add-Issue "Azure PowerShell" "Not logged into Azure PowerShell" "High" "Run: Connect-AzAccount"
        
        if ($FixIssues) {
            try {
                Write-ColorOutput "Attempting to log into Azure PowerShell..." "Yellow"
                Connect-AzAccount
                Mark-Fixed "Azure PowerShell login" "Successfully logged in"
            } catch {
                Mark-FixFailed "Azure PowerShell login" $_.Exception.Message
            }
        }
    }
}

# Check resource group
function Test-ResourceGroup {
    Write-ColorOutput "`n=== Checking Resource Group ===" "Cyan"
    
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        Write-ColorOutput "✓ Resource group exists: $($rg.ResourceGroupName)" "Green"
        Write-ColorOutput "  Location: $($rg.Location)" "White"
        Write-ColorOutput "  Status: $($rg.ProvisioningState)" "White"
    } catch {
        Add-Issue "Resource Group" "Resource group '$ResourceGroupName' not found" "Medium" "Create resource group or use existing one"
        
        if ($FixIssues) {
            try {
                Write-ColorOutput "Creating resource group: $ResourceGroupName..." "Yellow"
                $location = "East US"  # Default location
                New-AzResourceGroup -Name $ResourceGroupName -Location $location -Force
                Mark-Fixed "Resource group creation" "Created $ResourceGroupName in $location"
            } catch {
                Mark-FixFailed "Resource group creation" $_.Exception.Message
            }
        }
    }
}

# Check template files
function Test-TemplateFiles {
    Write-ColorOutput "`n=== Checking Template Files ===" "Cyan"
    
    $bicepMainTemplate = ".\bicep\main.bicep"
    $armMainTemplate = ".\arm-templates\main.json"
    $bicepParams = ".\bicep\parameters\lab.bicepparam"
    $armParams = ".\arm-templates\parameters\lab.parameters.json"
    
    # Check Bicep template
    if (Test-Path $bicepMainTemplate) {
        Write-ColorOutput "✓ Bicep main template found: $bicepMainTemplate" "Green"
        
        # Try to compile Bicep template
        try {
            az bicep build --file $bicepMainTemplate 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ Bicep template compiles successfully" "Green"
            } else {
                Add-Issue "Template Files" "Bicep template compilation failed" "High" "Check template syntax and dependencies"
            }
        } catch {
            Add-Issue "Template Files" "Failed to compile Bicep template" "High" "Verify Bicep CLI is working"
        }
    } else {
        Add-Issue "Template Files" "Bicep main template not found: $bicepMainTemplate" "High" "Ensure you're in the correct directory"
    }
    
    # Check ARM template fallback
    if (Test-Path $armMainTemplate) {
        Write-ColorOutput "✓ ARM template fallback found: $armMainTemplate" "Green"
    } else {
        Add-Issue "Template Files" "ARM template fallback not found: $armMainTemplate" "Medium" "ARM template should be available as fallback"
    }
    
    # Check parameter files
    if (Test-Path $bicepParams) {
        Write-ColorOutput "✓ Bicep parameters found: $bicepParams" "Green"
    } else {
        Add-Issue "Template Files" "Bicep parameters not found: $bicepParams" "Medium" "Parameter file is required for deployment"
    }
    
    if (Test-Path $armParams) {
        Write-ColorOutput "✓ ARM parameters found: $armParams" "Green"
    } else {
        Add-Issue "Template Files" "ARM parameters not found: $armParams" "Medium" "ARM parameters needed for fallback"
    }
}

# Check template scope and structure
function Test-TemplateScope {
    Write-ColorOutput "`n=== Checking Template Scope and Structure ===" "Cyan"
    
    $bicepTemplate = ".\bicep\main.bicep"
    if (Test-Path $bicepTemplate) {
        $content = Get-Content $bicepTemplate -Raw
        
        # Check target scope
        if ($content -match "targetScope\s*=\s*'resourceGroup'") {
            Write-ColorOutput "✓ Template scope is set to 'resourceGroup'" "Green"
        } elseif ($content -match "targetScope\s*=\s*'subscription'") {
            Add-Issue "Template Scope" "Template scope is set to 'subscription' but should be 'resourceGroup'" "High" "Change targetScope to 'resourceGroup' in main.bicep"
            
            if ($FixIssues) {
                try {
                    $updatedContent = $content -replace "targetScope\s*=\s*'subscription'", "targetScope = 'resourceGroup'"
                    Set-Content -Path $bicepTemplate -Value $updatedContent
                    Mark-Fixed "Template scope" "Changed from 'subscription' to 'resourceGroup'"
                } catch {
                    Mark-FixFailed "Template scope" $_.Exception.Message
                }
            }
        }
        
        # Check for resource group creation (should not exist in resource group scope)
        if ($content -match "Microsoft\.Resources/resourceGroups") {
            Add-Issue "Template Structure" "Template contains resource group creation but uses resourceGroup scope" "High" "Remove resource group creation from template"
        }
    }
}

# Check subnet CIDR calculations
function Test-SubnetCIDR {
    Write-ColorOutput "`n=== Checking Subnet CIDR Calculations ===" "Cyan"
    
    # Note: spoke-vnet-with-nva.bicep has been archived as it's not used in phased deployment
    $spokeVnetModule = ".\archive\bicep\modules\spoke-vnet-with-nva.bicep"
    if (Test-Path $spokeVnetModule) {
        $content = Get-Content $spokeVnetModule -Raw
        
        # Check for reserved subnet names
        if ($content -match "name:\s*'GatewaySubnet'") {
            Add-Issue "Subnet Naming" "Template uses reserved subnet name 'GatewaySubnet'" "High" "Rename to 'NvaSubnet' or another valid name"
            
            if ($FixIssues) {
                try {
                    # Fix the subnet name
                    $updatedContent = $content -replace "name:\s*'GatewaySubnet'", "name: 'NvaSubnet'"
                    $updatedContent = $updatedContent -replace "gatewaySubnetPrefix", "nvaSubnetPrefix"
                    $updatedContent = $updatedContent -replace "/subnets/GatewaySubnet", "/subnets/NvaSubnet"
                    Set-Content -Path $spokeVnetModule -Value $updatedContent
                    Mark-Fixed "Subnet naming" "Renamed GatewaySubnet to NvaSubnet"
                } catch {
                    Mark-FixFailed "Subnet naming" $_.Exception.Message
                }
            }
        }
        
        # Check for problematic subnet calculations
        if ($content -match "lastIndexOf.*\.\d+/") {
            Add-Issue "Subnet CIDR" "Template uses problematic subnet calculation that can produce invalid CIDR" "High" "Update subnet calculation logic to use proper CIDR alignment"
            
            if ($FixIssues) {
                Write-ColorOutput "Manual fix required for subnet CIDR calculations" "Yellow"
                    Write-ColorOutput "Please update the subnet calculation logic in archive/bicep/modules/spoke-vnet-with-nva.bicep (if using legacy template)" "Yellow"
            }
        } elseif ($content -match "baseNetwork.*\.0/26" -and $content -match "baseNetwork.*\.64/26") {
            Write-ColorOutput "✓ Subnet CIDR calculations appear to use proper alignment" "Green"
        }
    }
}

# Validate template deployment
function Test-TemplateValidation {
    Write-ColorOutput "`n=== Validating Template Deployment ===" "Cyan"
    
    if (!(Get-AzContext)) {
        Add-Issue "Template Validation" "Cannot validate template - not logged into Azure" "High" "Log into Azure PowerShell first"
        return
    }
    
    try {
        $null = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    } catch {
        Add-Issue "Template Validation" "Cannot validate template - resource group not found" "High" "Create resource group first"
        return
    }
    
    $bicepTemplate = ".\bicep\main.bicep"
    $armTemplate = ".\arm-templates\main.json"
    $armParams = ".\arm-templates\parameters\lab.parameters.json"
    
    if (Test-Path $bicepTemplate) {
        # Try compiling Bicep first
        try {
            az bicep build --file $bicepTemplate
            if ($LASTEXITCODE -eq 0) {
                $templateFile = $bicepTemplate.Replace('.bicep', '.json')
            } else {
                throw "Bicep compilation failed"
            }
        } catch {
            if (Test-Path $armTemplate) {
                Write-ColorOutput "Bicep compilation failed, using ARM template fallback" "Yellow"
                $templateFile = $armTemplate
            } else {
                Add-Issue "Template Validation" "Both Bicep compilation and ARM template fallback failed" "High" "Fix Bicep template or ensure ARM template exists"
                return
            }
        }
        
        # Validate template
        try {
            Write-ColorOutput "Validating template deployment..." "Yellow"
            if (Test-Path $armParams) {
                $validation = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterFile $armParams
            } else {
                $validation = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile
            }
            
            if ($validation.Count -eq 0 -or $null -eq $validation) {
                Write-ColorOutput "✓ Template validation successful" "Green"
            } else {
                $validation | ForEach-Object {
                    Add-Issue "Template Validation" "Validation issue: $($_.Message)" "High" "Review template configuration"
                }
            }
        } catch {
            Add-Issue "Template Validation" "Template validation failed: $($_.Exception.Message)" "High" "Review template and parameters"
        }
    }
}

# Check VS Code tasks configuration
function Test-VSCodeTasks {
    Write-ColorOutput "`n=== Checking VS Code Tasks Configuration ===" "Cyan"
    
    $tasksFile = ".\.vscode\tasks.json"
    if (Test-Path $tasksFile) {
        Write-ColorOutput "✓ VS Code tasks.json found" "Green"
        
        $tasksContent = Get-Content $tasksFile -Raw | ConvertFrom-Json
        
        # Check for proper Bicep build task
        $bicepBuildTask = $tasksContent.tasks | Where-Object { $_.label -eq "Build Bicep Templates" }
        if ($bicepBuildTask) {
            if ($bicepBuildTask.args -contains "--file") {
                Write-ColorOutput "✓ Bicep build task has --file argument" "Green"
            } else {
                Add-Issue "VS Code Tasks" "Bicep build task missing --file argument" "Medium" "Add --file argument to Bicep build task"
            }
        }
        
        # Check for resource group input
        $rgInput = $tasksContent.inputs | Where-Object { $_.id -eq "resourceGroupName" }
        if ($rgInput) {
            Write-ColorOutput "✓ Resource group input configured: default '$($rgInput.default)'" "Green"
        } else {
            Add-Issue "VS Code Tasks" "Resource group input not configured" "Low" "Add resourceGroupName input to tasks.json"
        }
    } else {
        Add-Issue "VS Code Tasks" "VS Code tasks.json not found" "Low" "VS Code tasks provide convenient deployment options"
    }
}

# Main troubleshooting function
function Start-Troubleshooting {
    Write-ColorOutput "=== Azure Virtual WAN Lab Troubleshooting ===" "Magenta"
    Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
    if ($SubscriptionId) {
        Write-ColorOutput "Subscription ID: $SubscriptionId" "White"
    }
    Write-ColorOutput "Fix Issues: $FixIssues" "White"
    Write-ColorOutput "Detailed Output: $Detailed" "White"
    Write-ColorOutput ""
    
    # Run all checks
    Test-Prerequisites
    Test-AzureCLI
    Test-BicepCLI
    Test-PowerShellModules
    Test-AzurePowerShell
    Test-ResourceGroup
    Test-TemplateFiles
    Test-TemplateScope
    Test-SubnetCIDR
    Test-TemplateValidation
    Test-VSCodeTasks
    
    # Summary
    Write-ColorOutput "`n=== Troubleshooting Summary ===" "Magenta"
    
    if ($script:IssuesFound.Count -eq 0) {
        Write-ColorOutput '🎉 No issues found! Your environment appears to be ready for deployment.' "Green"
    } else {
        Write-ColorOutput '📋 Issues Summary:' "White"
        
        $issuesByCategory = $script:IssuesFound | Group-Object Category
        foreach ($category in $issuesByCategory) {
            Write-ColorOutput "`n  $($category.Name) ($($category.Count) issues):" "Yellow"
            foreach ($issue in $category.Group) {
                $severityIcon = switch ($issue.Severity) {
                    "High" { '🔴' }
                    "Medium" { '🟡' }
                    "Low" { '🔵' }
                    default { '⚪' }
                }
                Write-ColorOutput "    $severityIcon $($issue.Issue)" "White"
                if ($Detailed -and $issue.Solution) {
                    Write-ColorOutput "      → $($issue.Solution)" "Cyan"
                }
            }
        }
        
        # Show fixes applied
        if ($script:IssuesFixed.Count -gt 0) {
            Write-ColorOutput "`n✅ Issues Fixed ($($script:IssuesFixed.Count)):" "Green"
            $script:IssuesFixed | ForEach-Object {
                Write-ColorOutput "  • $_" "Green"
            }
        }
        
        # Show failed fixes
        if ($script:FixesFailed.Count -gt 0) {
            Write-ColorOutput "`n❌ Fixes Failed ($($script:FixesFailed.Count)):" "Red"
            $script:FixesFailed | ForEach-Object {
                Write-ColorOutput "  • $_" "Red"
            }
        }
        
        # Recommendations
        Write-ColorOutput "`n📋 Recommendations:" "Cyan"
        
        $highIssues = $script:IssuesFound | Where-Object { $_.Severity -eq "High" }
        if ($highIssues.Count -gt 0) {
            Write-ColorOutput "  1. Address HIGH severity issues first before attempting deployment" "Yellow"
        }
        
        if (!$FixIssues) {
            Write-ColorOutput "  2. Run with -FixIssues to automatically attempt fixes" "Yellow"
        }
        
        Write-ColorOutput "  3. Review the troubleshooting guide: docs\troubleshooting.md" "White"
        Write-ColorOutput "  4. Test deployment with: .\scripts\Deploy-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName' -WhatIf" "White"
    }
    
    # Next steps
    Write-ColorOutput "`n🚀 Next Steps:" "Cyan"
    if ($script:IssuesFound.Count -eq 0 -or ($script:IssuesFound | Where-Object { $_.Severity -eq "High" }).Count -eq 0) {
        Write-ColorOutput "  Ready for deployment! Run:" "Green"
        Write-ColorOutput "    .\scripts\Deploy-VwanLab.ps1 -ResourceGroupName '$ResourceGroupName'" "White"
    } else {
        Write-ColorOutput "  Fix the HIGH severity issues above, then re-run this script" "Yellow"
    }
}

# Export results function
function Export-TroubleshootingResults {
    param([string]$OutputPath = ".\troubleshooting-results.json")
    
    $results = @{
        Timestamp = Get-Date
        ResourceGroupName = $ResourceGroupName
        SubscriptionId = $SubscriptionId
        IssuesFound = $script:IssuesFound
        IssuesFixed = $script:IssuesFixed
        FixesFailed = $script:FixesFailed
        Summary = @{
            TotalIssues = $script:IssuesFound.Count
            HighSeverity = ($script:IssuesFound | Where-Object { $_.Severity -eq "High" }).Count
            MediumSeverity = ($script:IssuesFound | Where-Object { $_.Severity -eq "Medium" }).Count
            LowSeverity = ($script:IssuesFound | Where-Object { $_.Severity -eq "Low" }).Count
            IssuesFixed = $script:IssuesFixed.Count
            FixesFailed = $script:FixesFailed.Count
        }
    }
    
    $results | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-ColorOutput "`n📄 Detailed results exported to: $OutputPath" "Cyan"
}

# Main execution
try {
    Start-Troubleshooting
    
    # Export results if requested
    if ($Detailed) {
        Export-TroubleshootingResults
    }
    
    # Exit with appropriate code
    $highIssues = $script:IssuesFound | Where-Object { $_.Severity -eq "High" }
    if ($highIssues.Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
} catch {
    Write-ColorOutput "`n❌ Troubleshooting script failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 2
}
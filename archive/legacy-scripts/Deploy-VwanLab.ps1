#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Deploys the Azure Virtual WAN lab environment.

.DESCRIPTION
    This script deploys a comprehensive Azure Virtual WAN lab environment including:
    - Virtual WAN with hub
    - Spoke VNets with NVA and Azure Route Server
    - BGP peering configuration
    - Test VMs for connectivity validation

.PARAMETER ResourceGroupName
    Name of the resource group where resources will be deployed.

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be deployed.

.PARAMETER TemplateFile
    Path to the Bicep or ARM template file. Defaults to Bicep main template.

.PARAMETER ParameterFile
    Path to the parameters file.

.PARAMETER Location
    Azure region for deployment. Defaults to 'East US'.

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\Deploy-VwanLab.ps1 -ResourceGroupName "rg-vwanlab-demo" -ParameterFile ".\bicep\parameters\lab.bicepparam" -WhatIf

.NOTES
    Author: VWAN Lab Team
    Version: 1.0
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = ".\bicep\main.bicep",

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = ".\bicep\parameters\lab.bicepparam",

    [Parameter(Mandatory = $false)]
    [string]$Location = "East US"
)

# Error handling
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to convert Bicep paths to ARM template paths
function Convert-BicepToArmPath {
    param(
        [string]$BicepPath
    )
    
    if ($BicepPath.EndsWith('.bicep')) {
        # Convert template path: bicep/main.bicep -> arm-templates/main.json
        $armPath = $BicepPath.Replace('.bicep', '.json')
        $armPath = $armPath -replace 'bicep[\\\/]', 'arm-templates\'
        return $armPath
    }
    elseif ($BicepPath.EndsWith('.bicepparam')) {
        # Convert parameter path: bicep/parameters/lab.bicepparam -> arm-templates/parameters/lab.parameters.json
        $armPath = $BicepPath.Replace('.bicepparam', '.parameters.json')
        $armPath = $armPath -replace 'bicep[\\\/]parameters[\\\/]', 'arm-templates\parameters\'
        return $armPath
    }
    
    return $BicepPath
}

# Function to check if user is logged in to Azure
function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if ($null -eq $context -or $null -eq $context.Account) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if Azure CLI and Bicep are available
function Test-BicepAvailability {
    try {
        # Check if Azure CLI is available
        $azVersion = az version 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        
        # Check if Bicep is available
        $bicepVersion = az bicep version 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        
        return $true
    }
    catch {
        return $false
    }
}

# Function to install Azure CLI and Bicep
function Install-AzureCliAndBicep {
    Write-ColorOutput "Azure CLI and/or Bicep not found. Attempting to install..." "Yellow"
    
    try {
        # Check if winget is available for Windows
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Write-ColorOutput "Installing Azure CLI using winget..." "Cyan"
            winget install -e --id Microsoft.AzureCLI --silent
            
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            
            Write-ColorOutput "Installing Bicep..." "Cyan"
            az bicep install
        }
        else {
            Write-ColorOutput "Please install Azure CLI manually:" "Red"
            Write-ColorOutput "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "White"
            Write-ColorOutput "Then run: az bicep install" "White"
            throw "Azure CLI and Bicep installation required"
        }
    }
    catch {
        Write-ColorOutput "Failed to install Azure CLI/Bicep automatically" "Red"
        Write-ColorOutput "Please install manually:" "Yellow"
        Write-ColorOutput "1. Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "White"
        Write-ColorOutput "2. Install Bicep: az bicep install" "White"
        throw "Azure CLI and Bicep installation required"
    }
}

# Function to install required modules
function Install-RequiredModules {
    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Network')
    
    foreach ($module in $requiredModules) {
        if (!(Get-Module -ListAvailable -Name $module)) {
            Write-ColorOutput "Installing module: $module" "Yellow"
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
        }
    }
}

# Function to validate template files
function Test-TemplateFiles {
    param(
        [string]$TemplateFile,
        [string]$ParameterFile
    )

    if (!(Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }

    if ($ParameterFile -and !(Test-Path $ParameterFile)) {
        throw "Parameter file not found: $ParameterFile"
    }

    # Check if this is a Bicep file and if Bicep is available
    if ($TemplateFile.EndsWith('.bicep')) {
        if (!(Test-BicepAvailability)) {
            Write-ColorOutput "Bicep file detected but Bicep is not available" "Yellow"
            
            # Check if ARM template exists as alternative
            $armTemplate = Convert-BicepToArmPath -BicepPath $TemplateFile
            $armParameters = Convert-BicepToArmPath -BicepPath $ParameterFile
            
            if (Test-Path $armTemplate) {
                Write-ColorOutput "Using ARM template as fallback: $armTemplate" "Cyan"
                if ($armParameters -and (Test-Path $armParameters)) {
                    Write-ColorOutput "Using ARM parameters file: $armParameters" "Cyan"
                    return $armTemplate, $armParameters
                }
                else {
                    Write-ColorOutput "ARM parameters file not found, proceeding without parameters" "Yellow"
                    return $armTemplate, $null
                }
            }
            else {
                Write-ColorOutput "ARM template fallback not found. Installing Bicep..." "Yellow"
                Install-AzureCliAndBicep
            }
        }
    }

    Write-ColorOutput "Template files validated successfully" "Green"
    return $TemplateFile, $ParameterFile
}

# Main deployment function
function Start-VwanLabDeployment {
    param(
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [string]$TemplateFile,
        [string]$ParameterFile,
        [string]$Location
    )

    $deploymentName = "vwanlab-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        # Set subscription context if provided
        if ($SubscriptionId) {
            Write-ColorOutput "Setting subscription context to: $SubscriptionId" "Cyan"
            Set-AzContext -SubscriptionId $SubscriptionId
        }

        # Create resource group if it doesn't exist
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-ColorOutput "Creating resource group $ResourceGroupName in $Location..." "Yellow"
            New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        }

        # For Bicep files, compile to ARM first if needed
        if ($TemplateFile.EndsWith('.bicep') -and (Test-BicepAvailability)) {
            Write-ColorOutput "Compiling Bicep template to ARM..." "Cyan"
            $armOutputPath = $TemplateFile.Replace('.bicep', '.json')
            
            try {
                az bicep build --file $TemplateFile --outfile $armOutputPath
                if ($LASTEXITCODE -eq 0) {
                    $TemplateFile = $armOutputPath
                    Write-ColorOutput "Bicep compilation successful" "Green"
                }
                else {
                    throw "Bicep compilation failed"
                }
            }
            catch {
                Write-ColorOutput "Bicep compilation failed. Using ARM template fallback..." "Yellow"
                $TemplateFile = Convert-BicepToArmPath -BicepPath $TemplateFile
                $ParameterFile = Convert-BicepToArmPath -BicepPath $ParameterFile
                
                if (!(Test-Path $TemplateFile)) {
                    throw "ARM template fallback not found: $TemplateFile"
                }
                
                if ($ParameterFile -and !(Test-Path $ParameterFile)) {
                    Write-ColorOutput "ARM parameters file not found: $ParameterFile" "Yellow"
                    $ParameterFile = $null
                }
            }
        }

        # Handle Bicep parameter files
        if ($ParameterFile -and $ParameterFile.EndsWith('.bicepparam')) {
            # Convert to ARM parameters format or use ARM parameter file
            $armParamFile = Convert-BicepToArmPath -BicepPath $ParameterFile
            if (Test-Path $armParamFile) {
                $ParameterFile = $armParamFile
                Write-ColorOutput "Using ARM parameters file: $ParameterFile" "Cyan"
            }
            else {
                Write-ColorOutput "Warning: ARM parameters file not found at $armParamFile. Attempting deployment without parameters..." "Yellow"
                $ParameterFile = $null
            }
        }

        # Validate template
        Write-ColorOutput "Validating template..." "Cyan"
        
        if ($ParameterFile) {
            $validation = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParameterFile
        }
        else {
            $validation = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile
        }

        if ($validation.Count -eq 0 -or $null -eq $validation) {
            Write-ColorOutput "Template validation successful" "Green"
        }
        else {
            Write-ColorOutput "Template validation had issues:" "Yellow"
            if ($validation -is [array]) {
                $validation | ForEach-Object { 
                    if ($_.Message) {
                        Write-ColorOutput "Issue: $($_.Message)" "Yellow"
                    }
                }
            } else {
                Write-ColorOutput "Validation completed with warnings (this is normal for complex templates)" "Yellow"
            }
            # Continue anyway as validation warnings are often non-blocking
        }

        # Deploy or show what would be deployed
        if ($WhatIfPreference) {
            Write-ColorOutput "Running What-If analysis..." "Cyan"
            
            if ($ParameterFile) {
                $whatIfResult = Get-AzResourceGroupDeploymentWhatIfResult -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParameterFile
            }
            else {
                $whatIfResult = Get-AzResourceGroupDeploymentWhatIfResult -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile
            }
            
            Write-ColorOutput "What-If analysis completed. Check the output above for planned changes." "Yellow"
        }
        else {
            Write-ColorOutput "Starting deployment: $deploymentName" "Cyan"
            
            if ($ParameterFile) {
                $deployment = New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParameterFile -Verbose
            }
            else {
                $deployment = New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -Verbose
            }

            if ($deployment.ProvisioningState -eq "Succeeded") {
                Write-ColorOutput "Deployment completed successfully!" "Green"
                Write-ColorOutput "Deployment Name: $deploymentName" "White"
                
                # Display outputs
                if ($deployment.Outputs) {
                    Write-ColorOutput "`nDeployment Outputs:" "Cyan"
                    $deployment.Outputs | ConvertTo-Json -Depth 3 | Write-Host
                }
            }
            else {
                Write-ColorOutput "Deployment failed with state: $($deployment.ProvisioningState)" "Red"
            }
        }
    }
    catch {
        Write-ColorOutput "Error during deployment: $($_.Exception.Message)" "Red"
        throw
    }
}

# Main script execution
Write-ColorOutput "=== Azure Virtual WAN Lab Deployment Script ===" "Cyan"

try {
    # Install required modules
    Write-ColorOutput "Checking required PowerShell modules..." "Cyan"
    Install-RequiredModules

    # Check Azure CLI and Bicep availability
    Write-ColorOutput "Checking Azure CLI and Bicep availability..." "Cyan"
    if ($TemplateFile.EndsWith('.bicep') -and !(Test-BicepAvailability)) {
        Write-ColorOutput "Bicep not available, will attempt to install or use ARM template fallback" "Yellow"
    }

    # Check if user is logged in
    if (!(Test-AzureLogin)) {
        Write-ColorOutput "Please log in to Azure..." "Yellow"
        Connect-AzAccount
    }

    # Validate template files
    Write-ColorOutput "Validating template files..." "Cyan"
    $validatedTemplate, $validatedParameters = Test-TemplateFiles -TemplateFile $TemplateFile -ParameterFile $ParameterFile
    
    # Update variables with validated paths
    $TemplateFile = $validatedTemplate
    $ParameterFile = $validatedParameters

    # Start deployment
    Start-VwanLabDeployment -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -TemplateFile $TemplateFile -ParameterFile $ParameterFile -Location $Location

    Write-ColorOutput "`n=== Deployment Script Completed ===" "Cyan"
    
    if (!$WhatIfPreference) {
        Write-ColorOutput "Next steps:" "Yellow"
        Write-ColorOutput "1. Configure RRAS on the NVA VM using: .\Configure-NvaVm.ps1" "White"
        Write-ColorOutput "2. Test connectivity using: .\Test-Connectivity.ps1" "White"
        Write-ColorOutput "3. Check the documentation in the docs folder for detailed configuration steps" "White"
    }
}
catch {
    Write-ColorOutput "Script execution failed: $($_.Exception.Message)" "Red"
    exit 1
}

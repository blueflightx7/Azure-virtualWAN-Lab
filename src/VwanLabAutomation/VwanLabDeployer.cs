using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Azure.ResourceManager.Resources.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace VwanLabAutomation;

/// <summary>
/// Handles deployment of the VWAN lab environment
/// </summary>
public class VwanLabDeployer
{
    private readonly ILogger<VwanLabDeployer> _logger;
    private readonly IConfiguration _configuration;
    private readonly ArmClient _armClient;

    public VwanLabDeployer(ILogger logger, IConfiguration configuration)
    {
        _logger = (ILogger<VwanLabDeployer>)logger;
        _configuration = configuration;
        
        // Use DefaultAzureCredential for authentication
        var credential = new DefaultAzureCredential();
        _armClient = new ArmClient(credential);
    }

    /// <summary>
    /// Deploy the VWAN lab environment
    /// </summary>
    public async Task DeployAsync(string subscriptionId, string resourceGroupName, string location, 
        string templateFile, string parametersFile)
    {
        try
        {
            _logger.LogInformation("Starting VWAN lab deployment...");
            _logger.LogInformation("Subscription: {SubscriptionId}", subscriptionId);
            _logger.LogInformation("Resource Group: {ResourceGroupName}", resourceGroupName);
            _logger.LogInformation("Location: {Location}", location);

            // Get subscription
            var subscription = await _armClient.GetDefaultSubscriptionAsync();
            _logger.LogInformation("Connected to subscription: {SubscriptionName}", subscription.Data.DisplayName);

            // Create or get resource group
            var resourceGroup = await CreateOrGetResourceGroupAsync(subscription, resourceGroupName, location);
            
            // Validate template file exists
            if (!File.Exists(templateFile))
            {
                throw new FileNotFoundException($"Template file not found: {templateFile}");
            }

            // Read template content
            var templateContent = await File.ReadAllTextAsync(templateFile);
            _logger.LogInformation("Template file loaded: {TemplateFile}", templateFile);

            // Read parameters if provided
            object? parameters = null;
            if (!string.IsNullOrEmpty(parametersFile) && File.Exists(parametersFile))
            {
                var parametersContent = await File.ReadAllTextAsync(parametersFile);
                
                // Handle both Bicep param files and ARM parameter files
                if (parametersFile.EndsWith(".bicepparam"))
                {
                    _logger.LogInformation("Bicep parameters file detected. Please use Azure CLI or PowerShell for Bicep deployment.");
                    return;
                }
                else
                {
                    var paramDoc = JsonDocument.Parse(parametersContent);
                    parameters = paramDoc.RootElement.GetProperty("parameters");
                }
                
                _logger.LogInformation("Parameters file loaded: {ParametersFile}", parametersFile);
            }

            // Create deployment
            var deploymentName = $"vwanlab-{DateTime.UtcNow:yyyyMMdd-HHmmss}";
            
            var deploymentContent = new ArmDeploymentContent(new ArmDeploymentProperties(ArmDeploymentMode.Incremental)
            {
                Template = BinaryData.FromString(templateContent),
                Parameters = parameters != null ? BinaryData.FromObjectAsJson(parameters) : null
            });

            _logger.LogInformation("Starting deployment: {DeploymentName}", deploymentName);
            
            var deploymentOperation = await resourceGroup.GetArmDeployments()
                .CreateOrUpdateAsync(Azure.WaitUntil.Completed, deploymentName, deploymentContent);

            if (deploymentOperation.Value.Data.Properties.ProvisioningState == ResourcesProvisioningState.Succeeded)
            {
                _logger.LogInformation("Deployment completed successfully!");
                
                // Log outputs
                if (deploymentOperation.Value.Data.Properties.Outputs != null)
                {
                    _logger.LogInformation("Deployment outputs:");
                    var outputs = deploymentOperation.Value.Data.Properties.Outputs.ToObjectFromJson<Dictionary<string, object>>();
                    foreach (var output in outputs)
                    {
                        _logger.LogInformation("  {Key}: {Value}", output.Key, output.Value);
                    }
                }
            }
            else
            {
                _logger.LogError("Deployment failed with state: {State}", 
                    deploymentOperation.Value.Data.Properties.ProvisioningState);
                
                if (deploymentOperation.Value.Data.Properties.Error != null)
                {
                    _logger.LogError("Error: {ErrorMessage}", 
                        deploymentOperation.Value.Data.Properties.Error.Message);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during deployment");
            throw;
        }
    }

    private async Task<ResourceGroupResource> CreateOrGetResourceGroupAsync(
        SubscriptionResource subscription, string resourceGroupName, string location)
    {
        try
        {
            // Try to get existing resource group
            var resourceGroup = await subscription.GetResourceGroupAsync(resourceGroupName);
            _logger.LogInformation("Using existing resource group: {ResourceGroupName}", resourceGroupName);
            return resourceGroup.Value;
        }
        catch
        {
            // Create new resource group
            _logger.LogInformation("Creating new resource group: {ResourceGroupName}", resourceGroupName);
            
            var resourceGroupData = new ResourceGroupData(location)
            {
                Tags = 
                {
                    ["CreatedBy"] = "VwanLabAutomation",
                    ["CreatedDate"] = DateTime.UtcNow.ToString("yyyy-MM-dd"),
                    ["Purpose"] = "VWAN-Lab"
                }
            };

            var resourceGroupOperation = await subscription.GetResourceGroups()
                .CreateOrUpdateAsync(Azure.WaitUntil.Completed, resourceGroupName, resourceGroupData);

            return resourceGroupOperation.Value;
        }
    }
}

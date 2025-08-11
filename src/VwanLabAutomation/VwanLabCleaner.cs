using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace VwanLabAutomation;

/// <summary>
/// Handles cleanup of the VWAN lab environment
/// </summary>
public class VwanLabCleaner
{
    private readonly ILogger<VwanLabCleaner> _logger;
    private readonly IConfiguration _configuration;
    private readonly ArmClient _armClient;

    public VwanLabCleaner(ILogger logger, IConfiguration configuration)
    {
        _logger = (ILogger<VwanLabCleaner>)logger;
        _configuration = configuration;
        
        var credential = new DefaultAzureCredential();
        _armClient = new ArmClient(credential);
    }

    /// <summary>
    /// Clean up the VWAN lab environment
    /// </summary>
    public async Task CleanupAsync(string subscriptionId, string resourceGroupName, bool force)
    {
        try
        {
            _logger.LogInformation("Starting VWAN lab cleanup...");
            _logger.LogInformation("Resource Group: {ResourceGroupName}", resourceGroupName);

            var subscription = await _armClient.GetDefaultSubscriptionAsync();
            var resourceGroup = await subscription.GetResourceGroupAsync(resourceGroupName);

            // List resources that will be deleted
            var resources = new List<string>();
            await foreach (var resource in resourceGroup.Value.GetGenericResources().GetAllAsync())
            {
                resources.Add($"{resource.Data.ResourceType.Type}: {resource.Data.Name}");
            }

            if (resources.Count == 0)
            {
                _logger.LogInformation("No resources found in resource group");
                return;
            }

            _logger.LogWarning("The following {ResourceCount} resources will be deleted:", resources.Count);
            foreach (var resource in resources)
            {
                _logger.LogWarning("  - {Resource}", resource);
            }

            // Confirm deletion unless force flag is used
            if (!force)
            {
                _logger.LogWarning("This action cannot be undone!");
                Console.Write("Are you sure you want to delete all resources? (yes/no): ");
                var confirmation = Console.ReadLine();
                
                if (!string.Equals(confirmation, "yes", StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogInformation("Cleanup cancelled by user");
                    return;
                }
            }

            // Delete the resource group (this will delete all resources within it)
            _logger.LogInformation("Deleting resource group and all resources...");
            var deleteOperation = await resourceGroup.Value.DeleteAsync(Azure.WaitUntil.Started);

            _logger.LogInformation("Cleanup initiated. Resource group deletion is in progress...");
            _logger.LogInformation("You can monitor the progress in the Azure Portal");

            // Wait for completion if requested
            if (force)
            {
                _logger.LogInformation("Waiting for cleanup to complete...");
                await deleteOperation.WaitForCompletionResponseAsync();
                _logger.LogInformation("Cleanup completed successfully");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during cleanup");
            throw;
        }
    }
}

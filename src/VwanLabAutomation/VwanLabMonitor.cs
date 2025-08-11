using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace VwanLabAutomation;

/// <summary>
/// Handles monitoring and status reporting for the VWAN lab environment
/// </summary>
public class VwanLabMonitor
{
    private readonly ILogger<VwanLabMonitor> _logger;
    private readonly IConfiguration _configuration;
    private readonly ArmClient _armClient;

    public VwanLabMonitor(ILogger logger, IConfiguration configuration)
    {
        _logger = (ILogger<VwanLabMonitor>)logger;
        _configuration = configuration;
        
        var credential = new DefaultAzureCredential();
        _armClient = new ArmClient(credential);
    }

    /// <summary>
    /// Get comprehensive status of the VWAN lab environment
    /// </summary>
    public async Task GetStatusAsync(string subscriptionId, string resourceGroupName)
    {
        try
        {
            _logger.LogInformation("Getting VWAN lab status...");
            _logger.LogInformation("Resource Group: {ResourceGroupName}", resourceGroupName);

            var subscription = await _armClient.GetDefaultSubscriptionAsync();
            var resourceGroup = await subscription.GetResourceGroupAsync(resourceGroupName);

            // Get resource counts
            await GetResourceCountsAsync(resourceGroup.Value);

            // Get Virtual WAN status
            await GetVirtualWanStatusAsync(resourceGroup.Value);

            // Get VM status
            await GetVirtualMachineStatusAsync(resourceGroup.Value);

            // Get networking status
            await GetNetworkingStatusAsync(resourceGroup.Value);

            _logger.LogInformation("Status check completed");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting lab status");
            throw;
        }
    }

    private async Task GetResourceCountsAsync(ResourceGroupResource resourceGroup)
    {
        _logger.LogInformation("=== Resource Summary ===");

        var resourceCounts = new Dictionary<string, int>();

        await foreach (var resource in resourceGroup.GetGenericResources().GetAllAsync())
        {
            var resourceType = resource.Data.ResourceType.Type;
            resourceCounts[resourceType] = resourceCounts.GetValueOrDefault(resourceType, 0) + 1;
        }

        foreach (var kvp in resourceCounts.OrderBy(x => x.Key))
        {
            _logger.LogInformation("{ResourceType}: {Count}", kvp.Key, kvp.Value);
        }
    }

    private async Task GetVirtualWanStatusAsync(ResourceGroupResource resourceGroup)
    {
        _logger.LogInformation("=== Virtual WAN Status ===");

        await foreach (var virtualWan in resourceGroup.GetVirtualWans().GetAllAsync())
        {
            _logger.LogInformation("Virtual WAN: {VwanName}", virtualWan.Data.Name);
            _logger.LogInformation("  Location: {Location}", virtualWan.Data.Location);
            _logger.LogInformation("  Type: {VwanType}", virtualWan.Data.VirtualWanType);
            _logger.LogInformation("  Allow Branch to Branch: {AllowBranchToBranch}", virtualWan.Data.AllowBranchToBranchTraffic);
            _logger.LogInformation("  Provisioning State: {ProvisioningState}", virtualWan.Data.ProvisioningState);
        }

        await foreach (var virtualHub in resourceGroup.GetVirtualHubs().GetAllAsync())
        {
            _logger.LogInformation("Virtual Hub: {HubName}", virtualHub.Data.Name);
            _logger.LogInformation("  Location: {Location}", virtualHub.Data.Location);
            _logger.LogInformation("  Address Prefix: {AddressPrefix}", virtualHub.Data.AddressPrefix);
            _logger.LogInformation("  Provisioning State: {ProvisioningState}", virtualHub.Data.ProvisioningState);
            
            if (virtualHub.Data.VirtualRouterAsn.HasValue)
            {
                _logger.LogInformation("  Virtual Router ASN: {RouterAsn}", virtualHub.Data.VirtualRouterAsn);
            }
            
            if (virtualHub.Data.VirtualRouterIPs?.Count > 0)
            {
                _logger.LogInformation("  Virtual Router IPs: {RouterIps}", string.Join(", ", virtualHub.Data.VirtualRouterIPs));
            }
        }
    }

    private async Task GetVirtualMachineStatusAsync(ResourceGroupResource resourceGroup)
    {
        _logger.LogInformation("=== Virtual Machine Status ===");

        await foreach (var vm in resourceGroup.GetVirtualMachines().GetAllAsync())
        {
            _logger.LogInformation("VM: {VmName}", vm.Data.Name);
            _logger.LogInformation("  Location: {Location}", vm.Data.Location);
            _logger.LogInformation("  Size: {VmSize}", vm.Data.HardwareProfile.VmSize);
            _logger.LogInformation("  OS: {OsType}", vm.Data.StorageProfile.OSDisk.OSType);
            _logger.LogInformation("  Provisioning State: {ProvisioningState}", vm.Data.ProvisioningState);

            try
            {
                var instanceView = await vm.InstanceViewAsync();
                var powerState = instanceView.Value.Statuses
                    .FirstOrDefault(s => s.Code?.StartsWith("PowerState") == true)?.DisplayStatus ?? "Unknown";
                _logger.LogInformation("  Power State: {PowerState}", powerState);
            }
            catch (Exception ex)
            {
                _logger.LogWarning("  Error getting power state: {Error}", ex.Message);
            }
        }
    }

    private async Task GetNetworkingStatusAsync(ResourceGroupResource resourceGroup)
    {
        _logger.LogInformation("=== Networking Status ===");

        // Virtual Networks
        await foreach (var vnet in resourceGroup.GetVirtualNetworks().GetAllAsync())
        {
            _logger.LogInformation("VNet: {VnetName}", vnet.Data.Name);
            _logger.LogInformation("  Location: {Location}", vnet.Data.Location);
            
            if (vnet.Data.AddressPrefixes?.Count > 0)
            {
                _logger.LogInformation("  Address Space: {AddressSpace}", string.Join(", ", vnet.Data.AddressPrefixes));
            }
            
            _logger.LogInformation("  Provisioning State: {ProvisioningState}", vnet.Data.ProvisioningState);

            // Subnets
            foreach (var subnet in vnet.Data.Subnets)
            {
                _logger.LogInformation("    Subnet: {SubnetName} - {AddressPrefix}", subnet.Name, subnet.AddressPrefix);
            }
        }

        // Public IP Addresses
        await foreach (var publicIp in resourceGroup.GetPublicIPAddresses().GetAllAsync())
        {
            _logger.LogInformation("Public IP: {PublicIpName}", publicIp.Data.Name);
            _logger.LogInformation("  IP Address: {IpAddress}", publicIp.Data.IPAddress ?? "Not assigned");
            _logger.LogInformation("  Allocation: {AllocationMethod}", publicIp.Data.PublicIPAllocationMethod);
            _logger.LogInformation("  Provisioning State: {ProvisioningState}", publicIp.Data.ProvisioningState);
        }

        // Network Security Groups
        await foreach (var nsg in resourceGroup.GetNetworkSecurityGroups().GetAllAsync())
        {
            _logger.LogInformation("NSG: {NsgName}", nsg.Data.Name);
            _logger.LogInformation("  Security Rules: {RuleCount}", nsg.Data.SecurityRules.Count);
            _logger.LogInformation("  Provisioning State: {ProvisioningState}", nsg.Data.ProvisioningState);
        }
    }
}

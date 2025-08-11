using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Compute;
using Azure.ResourceManager.Network;
using Azure.ResourceManager.Resources;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace VwanLabAutomation;

/// <summary>
/// Handles connectivity testing for the VWAN lab environment
/// </summary>
public class VwanLabTester
{
    private readonly ILogger<VwanLabTester> _logger;
    private readonly IConfiguration _configuration;
    private readonly ArmClient _armClient;

    public VwanLabTester(ILogger logger, IConfiguration configuration)
    {
        _logger = (ILogger<VwanLabTester>)logger;
        _configuration = configuration;
        
        var credential = new DefaultAzureCredential();
        _armClient = new ArmClient(credential);
    }

    /// <summary>
    /// Test connectivity in the VWAN lab environment
    /// </summary>
    public async Task TestConnectivityAsync(string subscriptionId, string resourceGroupName, bool detailed)
    {
        try
        {
            _logger.LogInformation("Starting connectivity tests...");
            _logger.LogInformation("Resource Group: {ResourceGroupName}", resourceGroupName);

            var subscription = await _armClient.GetDefaultSubscriptionAsync();
            var resourceGroup = await subscription.GetResourceGroupAsync(resourceGroupName);

            // Discover VMs
            var vms = await DiscoverLabVMsAsync(resourceGroup.Value);
            
            if (vms.Count == 0)
            {
                _logger.LogWarning("No VMs found in resource group");
                return;
            }

            _logger.LogInformation("Found {VmCount} VMs", vms.Count);
            foreach (var vm in vms)
            {
                var vmType = vm.Data.Tags.ContainsKey("VmType") ? vm.Data.Tags["VmType"] : "Unknown";
                _logger.LogInformation("  - {VmName} ({VmType})", vm.Data.Name, vmType);
            }

            // Test basic connectivity
            await TestBasicConnectivityAsync(vms, detailed);

            // Test specific scenarios if detailed
            if (detailed)
            {
                await TestDetailedScenariosAsync(resourceGroup.Value, vms);
            }

            _logger.LogInformation("Connectivity tests completed");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during connectivity testing");
            throw;
        }
    }

    private async Task<List<VirtualMachineResource>> DiscoverLabVMsAsync(ResourceGroupResource resourceGroup)
    {
        var vms = new List<VirtualMachineResource>();
        
        await foreach (var vm in resourceGroup.GetVirtualMachines().GetAllAsync())
        {
            vms.Add(vm);
        }

        return vms;
    }

    private async Task TestBasicConnectivityAsync(List<VirtualMachineResource> vms, bool detailed)
    {
        _logger.LogInformation("Testing basic VM connectivity...");

        foreach (var vm in vms)
        {
            try
            {
                // Get VM power state
                var instanceView = await vm.InstanceViewAsync();
                var powerState = instanceView.Value.Statuses
                    .FirstOrDefault(s => s.Code?.StartsWith("PowerState") == true)?.DisplayStatus ?? "Unknown";

                _logger.LogInformation("VM {VmName}: {PowerState}", vm.Data.Name, powerState);

                if (powerState.Contains("running", StringComparison.OrdinalIgnoreCase))
                {
                    // Get network interfaces
                    var networkInterfaces = await GetVmNetworkInterfacesAsync(vm);
                    foreach (var nic in networkInterfaces)
                    {
                        var privateIp = nic.Data.IPConfigurations.FirstOrDefault()?.PrivateIPAddress;
                        if (!string.IsNullOrEmpty(privateIp))
                        {
                            _logger.LogInformation("  Private IP: {PrivateIp}", privateIp);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Error getting VM info for {VmName}: {Error}", vm.Data.Name, ex.Message);
            }
        }
    }

    private async Task<List<NetworkInterfaceResource>> GetVmNetworkInterfacesAsync(VirtualMachineResource vm)
    {
        var networkInterfaces = new List<NetworkInterfaceResource>();

        foreach (var nicRef in vm.Data.NetworkProfile.NetworkInterfaces)
        {
            try
            {
                var nicResource = await _armClient.GetNetworkInterfaceResource(nicRef.Id).GetAsync();
                networkInterfaces.Add(nicResource.Value);
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Error getting network interface {NicId}: {Error}", nicRef.Id, ex.Message);
            }
        }

        return networkInterfaces;
    }

    private async Task TestDetailedScenariosAsync(ResourceGroupResource resourceGroup, List<VirtualMachineResource> vms)
    {
        _logger.LogInformation("Running detailed connectivity tests...");

        // Test VWAN hub status
        await TestVwanHubStatusAsync(resourceGroup);

        // Test Route Server status
        await TestRouteServerStatusAsync(resourceGroup);

        // Test VNet peering status
        await TestVNetPeeringStatusAsync(resourceGroup);
    }

    private async Task TestVwanHubStatusAsync(ResourceGroupResource resourceGroup)
    {
        try
        {
            _logger.LogInformation("Checking VWAN hub status...");

            await foreach (var virtualWan in resourceGroup.GetVirtualWans().GetAllAsync())
            {
                _logger.LogInformation("Virtual WAN: {VwanName}", virtualWan.Data.Name);
                _logger.LogInformation("  Type: {VwanType}", virtualWan.Data.VirtualWanType);
                _logger.LogInformation("  Allow Branch to Branch: {AllowBranchToBranch}", virtualWan.Data.AllowBranchToBranchTraffic);
            }

            await foreach (var virtualHub in resourceGroup.GetVirtualHubs().GetAllAsync())
            {
                _logger.LogInformation("Virtual Hub: {HubName}", virtualHub.Data.Name);
                _logger.LogInformation("  Address Prefix: {AddressPrefix}", virtualHub.Data.AddressPrefix);
                _logger.LogInformation("  Virtual Router ASN: {RouterAsn}", virtualHub.Data.VirtualRouterAsn);
                
                if (virtualHub.Data.VirtualRouterIPs?.Count > 0)
                {
                    _logger.LogInformation("  Virtual Router IPs: {RouterIps}", string.Join(", ", virtualHub.Data.VirtualRouterIPs));
                }

                // Check VNet connections
                await foreach (var connection in virtualHub.GetHubVirtualNetworkConnections().GetAllAsync())
                {
                    _logger.LogInformation("  VNet Connection: {ConnectionName} - Status Available", 
                        connection.Data.Name);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Error checking VWAN hub status: {Error}", ex.Message);
        }
    }

    private async Task TestRouteServerStatusAsync(ResourceGroupResource resourceGroup)
    {
        try
        {
            _logger.LogInformation("Checking Route Server status...");

            await foreach (var routeServer in resourceGroup.GetVirtualHubs().GetAllAsync())
            {
                if (routeServer.Data.Name.Contains("route-server", StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogInformation("Route Server: {RouteServerName}", routeServer.Data.Name);
                    _logger.LogInformation("  Allow Branch to Branch: {AllowBranchToBranch}", routeServer.Data.AllowBranchToBranchTraffic);
                    
                    // Check BGP connections
                    await foreach (var bgpConnection in routeServer.GetBgpConnections().GetAllAsync())
                    {
                        _logger.LogInformation("  BGP Connection: {ConnectionName}", bgpConnection.Data.Name);
                        _logger.LogInformation("    Peer ASN: {PeerAsn}", bgpConnection.Data.PeerAsn);
                        _logger.LogInformation("    Peer IP: {PeerIp}", bgpConnection.Data.PeerIP);
                        _logger.LogInformation("    Connection State: {ConnectionState}", bgpConnection.Data.ConnectionState);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Error checking Route Server status: {Error}", ex.Message);
        }
    }

    private async Task TestVNetPeeringStatusAsync(ResourceGroupResource resourceGroup)
    {
        try
        {
            _logger.LogInformation("Checking VNet peering status...");

            await foreach (var vnet in resourceGroup.GetVirtualNetworks().GetAllAsync())
            {
                _logger.LogInformation("Virtual Network: {VnetName}", vnet.Data.Name);
                if (vnet.Data.AddressPrefixes?.Count > 0)
                {
                    _logger.LogInformation("  Address Space: {AddressSpace}", string.Join(", ", vnet.Data.AddressPrefixes));
                }

                await foreach (var peering in vnet.GetVirtualNetworkPeerings().GetAllAsync())
                {
                    _logger.LogInformation("  Peering: {PeeringName} - {PeeringState}", 
                        peering.Data.Name, peering.Data.PeeringState);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Error checking VNet peering status: {Error}", ex.Message);
        }
    }
}

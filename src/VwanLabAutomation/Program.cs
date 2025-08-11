using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Network;
using Azure.ResourceManager.Compute;
using Azure.ResourceManager.Resources;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.CommandLine;

namespace VwanLabAutomation;

/// <summary>
/// Main program for VWAN Lab automation and management
/// </summary>
public class Program
{
    private static ILogger<Program>? _logger;
    private static IConfiguration? _configuration;

    public static async Task<int> Main(string[] args)
    {
        // Build configuration
        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
            .AddEnvironmentVariables()
            .AddCommandLine(args);

        _configuration = builder.Build();

        // Setup logging
        using var loggerFactory = LoggerFactory.Create(logging =>
        {
            logging.AddConsole();
            logging.SetMinimumLevel(LogLevel.Information);
        });
        _logger = loggerFactory.CreateLogger<Program>();

        // Create root command
        var rootCommand = new RootCommand("Azure Virtual WAN Lab Automation Tool");

        // Add subcommands
        rootCommand.AddCommand(CreateDeployCommand());
        rootCommand.AddCommand(CreateTestCommand());
        rootCommand.AddCommand(CreateStatusCommand());
        rootCommand.AddCommand(CreateCleanupCommand());

        return await rootCommand.InvokeAsync(args);
    }

    private static Command CreateDeployCommand()
    {
        var deployCommand = new Command("deploy", "Deploy the VWAN lab environment");
        
        var subscriptionOption = new Option<string>(
            "--subscription",
            "Azure subscription ID") { IsRequired = true };
        
        var resourceGroupOption = new Option<string>(
            "--resource-group",
            "Resource group name") { IsRequired = true };
        
        var locationOption = new Option<string>(
            "--location",
            () => "East US",
            "Azure region for deployment");

        var templateFileOption = new Option<string>(
            "--template-file",
            () => "../../bicep/main.bicep",
            "Path to the Bicep or ARM template file");

        var parametersFileOption = new Option<string>(
            "--parameters-file",
            () => "../../bicep/parameters/lab.bicepparam",
            "Path to the parameters file");

        deployCommand.AddOption(subscriptionOption);
        deployCommand.AddOption(resourceGroupOption);
        deployCommand.AddOption(locationOption);
        deployCommand.AddOption(templateFileOption);
        deployCommand.AddOption(parametersFileOption);

        deployCommand.SetHandler(async (subscription, resourceGroup, location, templateFile, parametersFile) =>
        {
            var deployer = new VwanLabDeployer(_logger!, _configuration!);
            await deployer.DeployAsync(subscription, resourceGroup, location, templateFile, parametersFile);
        }, subscriptionOption, resourceGroupOption, locationOption, templateFileOption, parametersFileOption);

        return deployCommand;
    }

    private static Command CreateTestCommand()
    {
        var testCommand = new Command("test", "Test connectivity in the VWAN lab environment");
        
        var subscriptionOption = new Option<string>(
            "--subscription",
            "Azure subscription ID") { IsRequired = true };
        
        var resourceGroupOption = new Option<string>(
            "--resource-group",
            "Resource group name") { IsRequired = true };

        var detailedOption = new Option<bool>(
            "--detailed",
            () => false,
            "Show detailed test results");

        testCommand.AddOption(subscriptionOption);
        testCommand.AddOption(resourceGroupOption);
        testCommand.AddOption(detailedOption);

        testCommand.SetHandler(async (subscription, resourceGroup, detailed) =>
        {
            var tester = new VwanLabTester(_logger!, _configuration!);
            await tester.TestConnectivityAsync(subscription, resourceGroup, detailed);
        }, subscriptionOption, resourceGroupOption, detailedOption);

        return testCommand;
    }

    private static Command CreateStatusCommand()
    {
        var statusCommand = new Command("status", "Get status of the VWAN lab environment");
        
        var subscriptionOption = new Option<string>(
            "--subscription",
            "Azure subscription ID") { IsRequired = true };
        
        var resourceGroupOption = new Option<string>(
            "--resource-group",
            "Resource group name") { IsRequired = true };

        statusCommand.AddOption(subscriptionOption);
        statusCommand.AddOption(resourceGroupOption);

        statusCommand.SetHandler(async (subscription, resourceGroup) =>
        {
            var monitor = new VwanLabMonitor(_logger!, _configuration!);
            await monitor.GetStatusAsync(subscription, resourceGroup);
        }, subscriptionOption, resourceGroupOption);

        return statusCommand;
    }

    private static Command CreateCleanupCommand()
    {
        var cleanupCommand = new Command("cleanup", "Clean up the VWAN lab environment");
        
        var subscriptionOption = new Option<string>(
            "--subscription",
            "Azure subscription ID") { IsRequired = true };
        
        var resourceGroupOption = new Option<string>(
            "--resource-group",
            "Resource group name") { IsRequired = true };

        var forceOption = new Option<bool>(
            "--force",
            () => false,
            "Force cleanup without confirmation");

        cleanupCommand.AddOption(subscriptionOption);
        cleanupCommand.AddOption(resourceGroupOption);
        cleanupCommand.AddOption(forceOption);

        cleanupCommand.SetHandler(async (subscription, resourceGroup, force) =>
        {
            var cleaner = new VwanLabCleaner(_logger!, _configuration!);
            await cleaner.CleanupAsync(subscription, resourceGroup, force);
        }, subscriptionOption, resourceGroupOption, forceOption);

        return cleanupCommand;
    }
}

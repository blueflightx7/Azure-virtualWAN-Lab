param(
    [string]$ResourceGroupName = "test-rg",
    [switch]$EnableAutoShutdown,
    [string]$AutoShutdownTime = "01:00",
    [string]$AutoShutdownTimeZone = "UTC"
)

Write-Host "Testing Auto-Shutdown Parameters:" -ForegroundColor Cyan
Write-Host "  EnableAutoShutdown: $EnableAutoShutdown" -ForegroundColor Gray
Write-Host "  AutoShutdownTime: $AutoShutdownTime" -ForegroundColor Gray
Write-Host "  AutoShutdownTimeZone: $AutoShutdownTimeZone" -ForegroundColor Gray

if ($EnableAutoShutdown) {
    Write-Host "`n⏰ Auto-Shutdown Configuration" -ForegroundColor Cyan
    Write-Host "   Shutdown Time: $AutoShutdownTime" -ForegroundColor Gray
    Write-Host "   Time Zone: $AutoShutdownTimeZone" -ForegroundColor Gray
    Write-Host "What if: Performing the operation ""Configure auto-shutdown for VMs"" on target ""$ResourceGroupName""." -ForegroundColor Magenta
} else {
    Write-Host "`n❌ Auto-shutdown not enabled" -ForegroundColor Yellow
}

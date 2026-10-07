<#
.SYNOPSIS
  Pings a list of network devices (switches, access points, UPS units, servers),
  logs the results, and builds a colour-coded HTML status report.

.DESCRIPTION
  Devices are read from a CSV with columns: Name, Type, Location, Address.
  Each run appends to a CSV log (useful for spotting recurring outages)
  and overwrites the HTML report with the current status.

.EXAMPLE
  .\Test-NetworkHealth.ps1
  .\Test-NetworkHealth.ps1 -DeviceFile .\devices.csv -ReportFile .\report.html
#>
param(
    [string]$DeviceFile = ".\devices.csv",
    [string]$ReportFile = ".\network-report.html",
    [string]$LogFile    = ".\network-log.csv"
)

$devices = Import-Csv $DeviceFile
$time    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$results = foreach ($d in $devices) {
    Write-Host "Checking $($d.Name) ($($d.Address))..."
    $ping = Test-Connection -ComputerName $d.Address -Count 2 -ErrorAction SilentlyContinue
    $up   = [bool]$ping

    [PSCustomObject]@{
        Time      = $time
        Name      = $d.Name
        Type      = $d.Type
        Location  = $d.Location
        Address   = $d.Address
        Status    = if ($up) { "UP" } else { "DOWN" }
        LatencyMs = if ($up) { [math]::Round(($ping | Measure-Object ResponseTime -Average).Average) } else { "" }
    }
}

# Keep a running history for troubleshooting recurring issues
$results | Export-Csv -Path $LogFile -NoTypeInformation -Append

# Build the HTML report
$down = @($results | Where-Object Status -eq "DOWN").Count
$css = @"
<style>
  body  { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
  table { border-collapse: collapse; }
  th, td { border: 1px solid #ccc; padding: 6px 12px; text-align: left; }
  th    { background: #333; color: #fff; }
  .up   { background: #d4edda; }
  .down { background: #f8d7da; font-weight: bold; }
</style>
"@
$summary = "<h2>Network Health Report</h2><p>Checked: $time &mdash; $($results.Count) devices, $down down</p>"

$html = $results | Select-Object Name, Type, Location, Address, Status, LatencyMs |
    ConvertTo-Html -Head $css -PreContent $summary |
    ForEach-Object {
        $_ -replace '<tr><td>(.*)<td>UP</td>', '<tr class="up"><td>$1<td>UP</td>' `
           -replace '<tr><td>(.*)<td>DOWN</td>', '<tr class="down"><td>$1<td>DOWN</td>'
    }
$html | Out-File -FilePath $ReportFile -Encoding utf8

$results | Format-Table Name, Type, Location, Status, LatencyMs -AutoSize
if ($down -gt 0) {
    Write-Warning "$down device(s) DOWN - see $ReportFile"
} else {
    Write-Host "All devices UP. Report saved to $ReportFile" -ForegroundColor Green
}

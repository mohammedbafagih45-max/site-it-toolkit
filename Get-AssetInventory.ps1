<#
.SYNOPSIS
  Collects hardware and OS details from a Windows PC and appends them to an asset inventory CSV.

.DESCRIPTION
  Run on each workstation/laptop/tablet you support. Every run adds one row,
  so the CSV becomes a simple asset register (serial numbers, models, specs, IP/MAC).

.EXAMPLE
  .\Get-AssetInventory.ps1
  .\Get-AssetInventory.ps1 -OutFile "\\fileserver\it\inventory.csv"
#>
param(
    [string]$OutFile = ".\inventory.csv"
)

$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os   = Get-CimInstance Win32_OperatingSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$nic  = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | Select-Object -First 1

$record = [PSCustomObject]@{
    CollectedAt  = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    Hostname     = $env:COMPUTERNAME
    Manufacturer = $cs.Manufacturer
    Model        = $cs.Model
    SerialNumber = $bios.SerialNumber
    OS           = $os.Caption
    OSBuild      = $os.BuildNumber
    LastBoot     = $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm")
    CPU          = $cpu.Name.Trim()
    RAM_GB       = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    DiskC_GB     = [math]::Round($disk.Size / 1GB, 1)
    DiskC_FreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    IPAddress    = ($nic.IPAddress | Where-Object { $_ -match '^\d+\.' }) -join ', '
    MACAddress   = $nic.MACAddress
}

# Warn about low disk space - a common cause of help desk tickets
if ($record.DiskC_FreeGB -lt 10) {
    Write-Warning "$($record.Hostname) has only $($record.DiskC_FreeGB) GB free on C:"
}

$record | Export-Csv -Path $OutFile -NoTypeInformation -Append
Write-Host "Saved inventory for $($record.Hostname) to $OutFile" -ForegroundColor Green
$record

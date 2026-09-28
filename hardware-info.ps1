# Compatible con Windows PowerShell 5.1 y PowerShell 7 en Windows.
[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'Este script requiere Windows.'
}

function Show-Section {
    param([string]$Title, [scriptblock]$Collect)
    "`n=== $Title ==="
    try {
        $data = & $Collect
        if ($null -eq $data -or @($data).Count -eq 0) {
            'No disponible: el sistema no devuelve datos.'
        } else {
            ($data | Format-List | Out-String -Width 220).TrimEnd()
        }
    } catch {
        "No disponible: $($_.Exception.Message)"
    }
}

function ConvertTo-GiB($Bytes) {
    if ($null -ne $Bytes) { [math]::Round([double]$Bytes / 1GB, 2) }
}

$report = & {
    'INFORME DE HARDWARE - WINDOWS'
    "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    'Los campos vacios o con valor cero pueden no estar informados por el firmware.'
    Show-Section 'Equipo' {
        Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model,
            SystemType, @{n='RAM total (GiB)';e={ConvertTo-GiB $_.TotalPhysicalMemory}}
    }
    Show-Section 'Sistema operativo' {
        Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version,
            BuildNumber, OSArchitecture, LastBootUpTime
    }
    Show-Section 'Procesador (frecuencias en MHz)' {
        Get-CimInstance Win32_Processor | Select-Object Name, Manufacturer, SocketDesignation,
            NumberOfCores, NumberOfLogicalProcessors, CurrentClockSpeed, MaxClockSpeed,
            L2CacheSize, L3CacheSize
    }
    Show-Section 'Modulos de memoria (velocidades declaradas por SMBIOS)' {
        Get-CimInstance Win32_PhysicalMemory | Select-Object DeviceLocator, BankLabel,
            Manufacturer, PartNumber, SerialNumber, @{n='Capacidad (GiB)';e={ConvertTo-GiB $_.Capacity}},
            Speed, ConfiguredClockSpeed, @{n='Tipo';e={
                switch ([int]$_.SMBIOSMemoryType) {
                    20 {'DDR'} 21 {'DDR2'} 24 {'DDR3'} 26 {'DDR4'} 34 {'DDR5'}
                    27 {'LPDDR'} 28 {'LPDDR2'} 29 {'LPDDR3'} 30 {'LPDDR4'} 35 {'LPDDR5'}
                    default {"No identificado (SMBIOS: $($_.SMBIOSMemoryType))"}
                }
            }}
    }
    Show-Section 'Discos fisicos' {
        Get-CimInstance Win32_DiskDrive | Select-Object Index, Model, SerialNumber,
            InterfaceType, MediaType, FirmwareRevision,
            @{n='Capacidad (GiB)';e={ConvertTo-GiB $_.Size}}
    }
    Show-Section 'Tipo de almacenamiento (informacion complementaria)' {
        Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, MediaType, BusType,
            @{n='Capacidad (GiB)';e={ConvertTo-GiB $_.Size}}
    }
    Show-Section 'Volumenes locales' {
        Get-CimInstance Win32_Volume -Filter 'DriveType = 3' | Select-Object DriveLetter,
            Label, Name, FileSystem, @{n='Capacidad (GiB)';e={ConvertTo-GiB $_.Capacity}},
            @{n='Libre (GiB)';e={ConvertTo-GiB $_.FreeSpace}}
    }
    Show-Section 'Graficos (AdapterRAM puede ser inexacto, especialmente con mas de 4 GiB)' {
        Get-CimInstance Win32_VideoController | Select-Object Name, VideoProcessor,
            DriverVersion, DriverDate, @{n='Memoria declarada (GiB)';e={ConvertTo-GiB $_.AdapterRAM}},
            CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate
    }
    Show-Section 'Tarjeta madre' {
        Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product, Version, SerialNumber
    }
    Show-Section 'BIOS / firmware' {
        Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion,
            ReleaseDate, SerialNumber
    }
    Show-Section 'Adaptadores de red (incluye virtuales)' {
        Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -or $_.NetConnectionID } |
            Select-Object Name, Manufacturer, MACAddress, NetConnectionID,
                @{n='Velocidad declarada (Mbps)';e={if ($null -ne $_.Speed) {[math]::Round([double]$_.Speed / 1e6, 2)}}}
    }
    Show-Section 'Audio' {
        Get-CimInstance Win32_SoundDevice | Select-Object Name, Manufacturer, Status
    }
    Show-Section 'Bateria (puede no existir)' {
        Get-CimInstance Win32_Battery | Select-Object Name, DeviceID, BatteryStatus,
            EstimatedChargeRemaining, EstimatedRunTime, DesignCapacity, FullChargeCapacity
    }
} | Out-String -Width 220

Write-Output $report
if ($OutputPath) {
    try {
        Set-Content -LiteralPath $OutputPath -Value $report -Encoding UTF8 -NoNewline
    } catch {
        Write-Error "No se pudo guardar el informe: $($_.Exception.Message)"
    }
}

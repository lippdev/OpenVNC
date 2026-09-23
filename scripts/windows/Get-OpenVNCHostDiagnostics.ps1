#Requires -Version 5.1
<#
.SYNOPSIS
Collects read-only host information for the virtual display investigation.
.DESCRIPTION
Run in the Windows user's interactive desktop session. Writes only the selected
JSON report. Does not install drivers, change displays, read VNC passwords,
modify services/firewall/tailnet policy, or collect screenshots.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This diagnostic must run on Windows.' }
if (Test-Path -LiteralPath $OutputPath) { throw 'Choose a new output path; the report already exists.' }

$report = [ordered]@{
    schemaVersion = 1
    collectedAtUtc = [DateTime]::UtcNow.ToString('o')
    sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    os = $null
    graphics = @()
    screens = @()
    displayDrivers = @()
    vncServices = @()
    listeners = @()
    tailnetInterfaces = @()
    warnings = @()
}

try {
    $report.os = Get-CimInstance Win32_OperatingSystem |
        Select-Object Caption, Version, BuildNumber, OSArchitecture
} catch { $report.warnings += 'OS inventory unavailable.' }

try {
    $report.graphics = @(Get-CimInstance Win32_VideoController |
        Select-Object Name, DriverVersion, VideoProcessor, Status)
} catch { $report.warnings += 'GPU inventory unavailable.' }

try {
    Add-Type -AssemblyName System.Windows.Forms
    if (-not ('OpenVNC.DpiContext' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace OpenVNC {
    public static class DpiContext {
        [DllImport("user32.dll")]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    }
}
'@
    }
    # Thread-local DPI awareness for physical pixel bounds, restored afterward.
    $previousDpi = [OpenVNC.DpiContext]::SetThreadDpiAwarenessContext([IntPtr](-4))
    try {
        if ($previousDpi -eq [IntPtr]::Zero) {
            $report.warnings += 'DPI context could not be set; screen bounds may be virtualized.'
        }
        $report.screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
            [ordered]@{
                deviceName = $_.DeviceName
                primary = $_.Primary
                x = $_.Bounds.X
                y = $_.Bounds.Y
                width = $_.Bounds.Width
                height = $_.Bounds.Height
                bitsPerPixel = $_.BitsPerPixel
            }
        })
    } finally {
        if ($previousDpi -ne [IntPtr]::Zero) {
            [void][OpenVNC.DpiContext]::SetThreadDpiAwarenessContext($previousDpi)
        }
    }
} catch { $report.warnings += 'Interactive screen inventory unavailable.' }

try {
    $report.displayDrivers = @(Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceClass -in @('DISPLAY', 'MONITOR') } |
        Select-Object DeviceName, Manufacturer, DriverVersion, IsSigned, Signer)
} catch { $report.warnings += 'Display driver inventory unavailable.' }

try {
    $report.vncServices = @(Get-CimInstance Win32_Service |
        Where-Object { $_.Name -match '(?i)vnc' } |
        Select-Object Name, State, StartMode)
} catch { $report.warnings += 'VNC service inventory unavailable.' }

try {
    $report.listeners = @(Get-NetTCPConnection -State Listen |
        Where-Object { $_.LocalPort -in @(5900, 6080) } |
        Select-Object LocalAddress, LocalPort)
} catch { $report.warnings += 'Listener inventory unavailable.' }

try {
    $report.tailnetInterfaces = @(Get-NetIPAddress |
        Where-Object { $_.InterfaceAlias -match '(?i)tailscale' } |
        Select-Object InterfaceAlias, IPAddress, AddressFamily)
} catch { $report.warnings += 'Tailscale interface inventory unavailable.' }

if ($report.sessionId -eq 0) {
    $report.warnings += 'Session 0: run again from the interactive Windows desktop.'
}
$report.warnings += 'RDP can change the visible topology. Collect from the local console or existing VNC session.'
$report.warnings += 'IsSigned is inventory metadata, not verification of a candidate installer or catalog.'
$report | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $OutputPath -Encoding utf8 -NoClobber
Write-Host 'Diagnostic report saved. No display or driver configuration was changed.'

#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Build this package on Windows.' }
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$previousRustFlags = $env:RUSTFLAGS
try {
    # Bundle the C runtime into this portable executable.
    $env:RUSTFLAGS = "$previousRustFlags -C target-feature=+crt-static"
    cargo build --locked --release --target x86_64-pc-windows-msvc -p openvnc-host
    if ($LASTEXITCODE -ne 0) { throw 'Rust build failed.' }
    $package = Join-Path $root 'dist\OpenVNC-Host-windows-x64'
    New-Item -ItemType Directory -Force -Path $package | Out-Null
    Copy-Item 'target\x86_64-pc-windows-msvc\release\openvnc-host.exe' (Join-Path $package 'OpenVNC-Host.exe')
    Copy-Item 'LICENSE' $package
    Copy-Item 'apps\windows-host\README.md' $package
    Copy-Item 'apps\windows-host\THIRD-PARTY-NOTICES.txt' $package
    $exe = Join-Path $package 'OpenVNC-Host.exe'
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLowerInvariant()
    "$hash  OpenVNC-Host.exe" | Out-File (Join-Path $package 'SHA256SUMS.txt') -Encoding ascii
    Write-Host "Host package: $package"
} finally {
    $env:RUSTFLAGS = $previousRustFlags
    Pop-Location
}

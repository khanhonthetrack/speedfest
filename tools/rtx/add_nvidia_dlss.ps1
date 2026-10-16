# Adds NVIDIA's DLSS / Streamline runtime (Streamline SDK v2.10.0, bin\x64, not development) and its
# licence files next to SpeedFest.exe. Uses a local SDK folder if there is one (-Sdk <folder>, or
# C:\dev\streamline-2.10.0), otherwise downloads the official SDK zip (213 MB) from NVIDIA's GitHub
# release and extracts only the runtime files.
param([string]$Sdk = "")
$ErrorActionPreference = "Stop"
$dest = $PSScriptRoot
$url = "https://github.com/NVIDIA-RTX/Streamline/releases/download/v2.10.0/streamline-sdk-v2.10.0.zip"
$want = '^bin/x64/[^/]+\.(dll|license\.txt)$|^license\.txt$|^3rd-party-licenses\.md$'

$local = @($Sdk, "C:\dev\streamline-2.10.0", "C:\dev\streamline-sdk-v2.10.0") |
    Where-Object { $_ -and (Test-Path (Join-Path $_ "bin\x64\sl.interposer.dll")) } | Select-Object -First 1
if ($local) {
    Write-Host "Copying the NVIDIA runtime from $local"
    Copy-Item (Join-Path $local "bin\x64\*.dll") $dest -Force
    Copy-Item (Join-Path $local "bin\x64\*.license.txt") $dest -Force
    foreach ($f in "license.txt", "3rd-party-licenses.md") {
        if (Test-Path (Join-Path $local $f)) { Copy-Item (Join-Path $local $f) $dest -Force }
    }
} else {
    $zip = Join-Path $env:TEMP "streamline-sdk-v2.10.0.zip"
    if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 200MB) {
        Write-Host "Downloading NVIDIA Streamline SDK v2.10.0 (213 MB) from github.com/NVIDIA-RTX ..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($e in $z.Entries) {
            if ($e.FullName -match $want) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $dest $e.Name), $true)
            }
        }
    } finally { $z.Dispose() }
}
if (-not (Test-Path (Join-Path $dest "sl.interposer.dll"))) { throw "sl.interposer.dll is still missing" }
Write-Host "Done: the NVIDIA DLSS / Streamline files are next to SpeedFest.exe."

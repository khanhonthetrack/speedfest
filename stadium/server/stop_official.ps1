# Stops the official server and its tunnel started by run_official.ps1.
$logs = Join-Path $env:LOCALAPPDATA "SpeedFestStadium"
if (Test-Path "$logs\pids.txt") {
    foreach ($p in (Get-Content "$logs\pids.txt").Split(" ")) { Stop-Process -Id ([int]$p) -Force -ErrorAction SilentlyContinue }
    Remove-Item "$logs\pids.txt"
}

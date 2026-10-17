# Restarts only the official server's node process (after pulling new server code or tracks),
# keeping the Cloudflare tunnel and so its address: nothing to publish again.
#   powershell -ExecutionPolicy Bypass -File stadium\server\restart_server.ps1
# Started by run_official.ps1 (its pids are in %LOCALAPPDATA%\SpeedFestStadium\pids.txt).
param([int]$Port = 8090, [string]$Name = "SpeedFest Stadium (official)")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$logs = Join-Path $env:LOCALAPPDATA "SpeedFestStadium"
$pids = (Get-Content "$logs\pids.txt" -ErrorAction Stop).Trim().Split(" ")
$old = Get-Process -Id ([int]$pids[0]) -ErrorAction SilentlyContinue
if ($old -and $old.ProcessName -eq "node") { Stop-Process -Id $old.Id -Force; Start-Sleep -Seconds 1 }
$node = (Get-Command node).Source
$srv = Start-Process -FilePath $node -ArgumentList @("`"$here\server.js`"", "--port=$Port", "--host=127.0.0.1", "--name=`"$Name`"") `
    -WorkingDirectory $here -RedirectStandardOutput "$logs\server.log" -RedirectStandardError "$logs\server.err.log" -WindowStyle Hidden -PassThru
Set-Content -Path "$logs\pids.txt" -Value "$($srv.Id) $($pids[1])"
Start-Sleep -Seconds 2
Write-Host "Server restarted (pid $($srv.Id)); tunnel pid $($pids[1]) kept."
Get-Content "$logs\server.log" -Tail 1

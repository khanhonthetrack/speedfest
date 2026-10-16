# Runs the official SpeedFest Stadium server on this PC and makes it reachable from the internet
# through a Cloudflare quick tunnel (free, no account; the address changes every start).
#   powershell -ExecutionPolicy Bypass -File stadium\server\run_official.ps1 [-Publish] [-Cloudflared C:\path\cloudflared.exe]
# -Publish writes the tunnel's address to stadium\server\official.json and commits and pushes just
# that file, so every player's game finds the server ("Join the official server").
# Logs: %LOCALAPPDATA%\SpeedFestStadium\. Stop: stop_official.ps1 (or end the node/cloudflared processes).
param([switch]$Publish, [string]$Cloudflared = "C:\dev\tools\cloudflared\cloudflared.exe", [int]$Port = 8090,
      [string]$Name = "SpeedFest Stadium (official)")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$logs = Join-Path $env:LOCALAPPDATA "SpeedFestStadium"
New-Item -ItemType Directory -Force $logs | Out-Null
if (-not (Test-Path (Join-Path $here "node_modules\ws"))) { Push-Location $here; npm install --omit=dev; Pop-Location }
$node = (Get-Command node).Source
$srv = Start-Process -FilePath $node -ArgumentList @("`"$here\server.js`"", "--port=$Port", "--host=127.0.0.1", "--name=`"$Name`"") `
    -WorkingDirectory $here -RedirectStandardOutput "$logs\server.log" -RedirectStandardError "$logs\server.err.log" -WindowStyle Hidden -PassThru
$tun = Start-Process -FilePath $Cloudflared -ArgumentList @("tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:$Port") `
    -RedirectStandardOutput "$logs\tunnel.log" -RedirectStandardError "$logs\tunnel.err.log" -WindowStyle Hidden -PassThru
Set-Content -Path "$logs\pids.txt" -Value "$($srv.Id) $($tun.Id)"
$url = $null
for ($i = 0; $i -lt 60 -and -not $url; $i++) {
    Start-Sleep -Seconds 1
    $m = Select-String -Path "$logs\tunnel.err.log", "$logs\tunnel.log" -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($m) { $url = $m.Matches[0].Value }
}
if (-not $url) { Write-Error "The tunnel gave no address (see $logs\tunnel.err.log)" }
Write-Host "Official server: $url  (server pid $($srv.Id), tunnel pid $($tun.Id))"
if ($Publish) {
    $json = "{`n  `"name`": `"$Name`",`n  `"url`": `"$url`",`n  `"started`": `"$((Get-Date).ToUniversalTime().ToString('s'))Z`"`n}`n"
    $file = Join-Path $here "official.json"
    [System.IO.File]::WriteAllText($file, $json)
    $repo = (Resolve-Path (Join-Path $here "..\..")).Path
    git -C $repo add -- "stadium/server/official.json"
    git -C $repo commit -m "stadium: official server address $url" -- "stadium/server/official.json"
    git -C $repo push origin HEAD
}

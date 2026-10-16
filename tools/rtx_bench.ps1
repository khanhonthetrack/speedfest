# SpeedFest GPU benchmark runner for Windows (M7 RTX tests, docs/RTX.md "Benchmarks").
# Runs res://tests/integration/gpu_bench.tscn once per config of a set and collects the BENCH lines,
# a JSON file and a screenshot per config in -OutDir. Exclusive fullscreen configs take over the screen.
#   powershell -ExecutionPolicy Bypass -File tools\rtx_bench.ps1 -Godot C:\dev\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe -Set baseline
#   powershell -ExecutionPolicy Bypass -File tools\rtx_bench.ps1 -Godot <fork console exe> -Project C:\dev\speedfest-rtx\game -Set dlss
param(
	[Parameter(Mandatory = $true)] [string]$Godot,
	[string]$Project = "",                  # default: this repo's game/
	[ValidateSet("baseline", "dlss", "pt", "smoke")] [string]$Set = "baseline",
	[string]$OutDir = "C:\dev\bench",
	[string]$Track = "downtown",
	[string]$Weather = "rain",
	[int]$Seconds = 20,
	[string]$Only = ""
)

# name, window (0 window / 2 exclusive fullscreen), window size, extra user args
$sets = @{
	"smoke"    = @(
		@("smoke_q2_720", 0, "1280x720", @("--quality=2"))
	)
	"baseline" = @(
		@("q0_1440", 2, "", @("--quality=0")),
		@("q1_1440", 2, "", @("--quality=1")),
		@("q2_1440", 2, "", @("--quality=2")),
		@("q3_1440", 2, "", @("--quality=3")),
		@("q2_1440_fsr2_67", 2, "", @("--quality=2", "--aa=FSR2", "--render_scale=0.67")),
		@("q2_1080", 0, "1920x1080", @("--quality=2"))
	)
	"dlss"     = @(
		@("q2_1440_native", 2, "", @("--quality=2")),
		@("q2_1440_dlaa", 2, "", @("--quality=2", "--dlss=DLAA")),
		@("q2_1440_dlss_q", 2, "", @("--quality=2", "--dlss=Quality")),
		@("q2_1440_dlss_b", 2, "", @("--quality=2", "--dlss=Balanced")),
		@("q2_1440_dlss_p", 2, "", @("--quality=2", "--dlss=Performance")),
		@("q3_1440_dlss_q", 2, "", @("--quality=3", "--dlss=Quality"))
	)
	"pt"       = @(
		@("pt_1440_dlss_q", 2, "", @("--quality=2", "--rtx", "--dlss=Quality")),
		@("pt_1440_dlss_p", 2, "", @("--quality=2", "--rtx", "--dlss=Performance")),
		@("pt_1080_dlss_q", 0, "1920x1080", @("--quality=2", "--rtx", "--dlss=Quality")),
		@("pt_1080_dlss_p", 0, "1920x1080", @("--quality=2", "--rtx", "--dlss=Performance"))
	)
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$log = Join-Path $OutDir "$Set.txt"
if ($Project -eq "") { $Project = Join-Path $PSScriptRoot "..\game" }    # PS 5.1: $PSScriptRoot is empty in param()
$project = (Resolve-Path $Project).Path
foreach ($c in $sets[$Set]) {
	$name, $window, $size, $extra = $c
	if ($Only -ne "" -and $name -notlike $Only) { continue }
	$shot = (Join-Path $OutDir "$Set-$name.png") -replace '\\', '/'
	$json = (Join-Path $OutDir "$Set-$name.json") -replace '\\', '/'
	$engineArgs = @("--path", $project, "--audio-driver", "Dummy")
	if ($size -ne "") { $engineArgs += @("--resolution", $size) }
	$userArgs = @("--track=$Track", "--weather=$Weather", "--window=$window", "--seconds=$Seconds",
		"--bench_shot=$shot", "--out=$json") + $extra
	Write-Host "== $Set/$name"
	$out = & $Godot @engineArgs "res://tests/integration/gpu_bench.tscn" -- @userArgs 2>&1 | ForEach-Object { "$_" }
	$lines = $out | Where-Object { $_ -match "^BENCH|SCRIPT ERROR|DLSS|Streamline|ray ?tracing" }
	if (-not ($lines -match "^BENCH ")) { $lines = @("BENCH_FAIL $name") + ($out | Select-Object -Last 15) }
	$lines | ForEach-Object { Write-Host $_ }
	(@("== $Set/$name") + $lines) | Add-Content -Encoding utf8 $log
}
Write-Host "results: $log"

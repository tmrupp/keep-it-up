param(
    [int]$TimeoutSeconds = 10
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Godot = $env:GODOT_BIN

function Stop-ProcessTree {
    param([int]$ProcessId)

    Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-ProcessTree -ProcessId $_.ProcessId
    }

    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Resolve-GodotExecutable {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    $command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    if (-not (Test-Path $Candidate)) {
        return $null
    }

    $item = Get-Item $Candidate
    if (-not $item.PSIsContainer) {
        return $item.FullName
    }

    $consoleExe = Get-ChildItem -Path $item.FullName -Filter "*Godot*console.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($consoleExe) {
        return $consoleExe.FullName
    }

    $regularExe = Get-ChildItem -Path $item.FullName -Filter "*Godot*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($regularExe) {
        return $regularExe.FullName
    }

    return $null
}

$Godot = Resolve-GodotExecutable $Godot

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $candidates = @(
        "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe",
        "godot"
    )

    foreach ($candidate in $candidates) {
        $resolved = Resolve-GodotExecutable $candidate
        if ($resolved) {
            $Godot = $resolved
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Godot) -or -not (Test-Path $Godot)) {
    throw "Could not find Godot. Set GODOT_BIN to the Godot executable path."
}

Write-Host "Using Godot: $Godot"
Write-Host "Project: $ProjectRoot"
Write-Host "Timeout: $TimeoutSeconds seconds"

$resultDir = Join-Path $ProjectRoot "artifacts\results"
New-Item -ItemType Directory -Force $resultDir | Out-Null

$stdoutPath = Join-Path $resultDir "godot_stdout.log"
$stderrPath = Join-Path $resultDir "godot_stderr.log"
Remove-Item $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

$arguments = @(
    "--path",
    $ProjectRoot,
    "--script",
    "res://scripts/test_runner.gd"
)

$process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$finished = $process.WaitForExit($TimeoutSeconds * 1000)

if (-not $finished) {
    Write-Warning "Godot verification exceeded $TimeoutSeconds seconds. Killing process tree for PID $($process.Id)."
    Stop-ProcessTree -ProcessId $process.Id

    if (Test-Path $stdoutPath) {
        Get-Content $stdoutPath | Write-Host
    }
    if (Test-Path $stderrPath) {
        Get-Content $stderrPath | Write-Host
    }

    exit 124
}

$process.Refresh()
$exitCode = $process.ExitCode

if (Test-Path $stdoutPath) {
    Get-Content $stdoutPath | Write-Host
}
if (Test-Path $stderrPath) {
    Get-Content $stderrPath | Write-Host
}

$resultPath = Join-Path $ProjectRoot "artifacts\results\latest.json"
if (Test-Path $resultPath) {
    Get-Content $resultPath | Write-Host
}

exit $exitCode

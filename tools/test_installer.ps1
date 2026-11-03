param(
    [ValidateSet('all', 'install', 'launch-installed', 'reinstall', 'launch-reinstalled', 'uninstall')]
    [string]$Phase = 'all'
)
$ErrorActionPreference = 'Stop'
$installer = (Get-ChildItem build/installer/*-Setup.exe | Select-Object -First 1).FullName
if (!$installer) { throw 'Installer artifact is missing' }
# Exercise Unicode and spaces in paths. This is a disposable Windows CI runner.
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\One More Try 테스트'
$recordsDir = Join-Path $env:APPDATA 'Godot\app_userdata\한 번만 더!'
$recordsPath = Join-Path $recordsDir 'records.json'
New-Item -ItemType Directory -Path $recordsDir -Force | Out-Null
$sentinel = '{"version":1,"deaths":123,"attempts":7,"clears":2,"best_time":15.25,"no_death":true,"secret":true,"music":false,"sfx":false}'
if ($Phase -in @('all', 'install')) { [IO.File]::WriteAllText($recordsPath, $sentinel) }

function Assert-Records {
    if (!(Test-Path $recordsPath) -or [IO.File]::ReadAllText($recordsPath) -ne $sentinel) {
        throw 'Installer changed or removed saved records'
    }
}

function Invoke-SmokeProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$Phase,
        [int]$TimeoutSeconds = 120,
        [string]$StdoutPath = '',
        [string]$StderrPath = ''
    )
    Write-Output "START: $Phase ($TimeoutSeconds seconds maximum)"
    $options = @{ FilePath = $FilePath; ArgumentList = $ArgumentList; PassThru = $true; NoNewWindow = $true }
    if ($StdoutPath) { $options.RedirectStandardOutput = $StdoutPath }
    if ($StderrPath) { $options.RedirectStandardError = $StderrPath }
    $process = Start-Process @options
    # Retain the process handle so ExitCode remains available after it exits.
    $null = $process.Handle
    if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
        & taskkill.exe /PID $process.Id /T /F | Out-Host
        throw "$Phase timed out after $TimeoutSeconds seconds"
    }
    # Refresh the process object after waiting to read its final exit status.
    $process.Refresh()
    if ($process.ExitCode -ne 0) { throw "$Phase exited with $($process.ExitCode)" }
    Write-Output "PASS: $Phase"
}

try {
    foreach ($installPhase in @('install', 'reinstall')) {
        if ($Phase -in @('all', $installPhase)) {
            $logPath = Join-Path $PWD "installer-$installPhase.log"
            $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$installDir`"", "/LOG=`"$logPath`"")
            Invoke-SmokeProcess -FilePath $installer -ArgumentList $arguments -Phase "$installPhase installer"
            foreach ($file in @('OneMoreTry.exe', 'README.txt', 'licenses\Godot.txt', 'licenses\NotoSansCJK.txt', 'unins000.exe')) {
                if (!(Test-Path (Join-Path $installDir $file))) { throw "Installed file missing: $file" }
            }
            Assert-Records
        }
        $launchPhase = if ($installPhase -eq 'install') { 'launch-installed' } else { 'launch-reinstalled' }
        if ($Phase -in @('all', $launchPhase)) {
            Assert-Records
            Invoke-SmokeProcess -FilePath (Join-Path $installDir 'OneMoreTry.exe') -ArgumentList @('--headless','--audio-driver','Dummy','--quit-after','120','--','--test') -Phase "$installPhase game launch" -TimeoutSeconds 45 -StdoutPath "installer-$installPhase-stdout.log" -StderrPath "installer-$installPhase-stderr.log"
            $errors = Select-String -Path "installer-$installPhase-stdout.log","installer-$installPhase-stderr.log" -Pattern 'SCRIPT ERROR|ERROR:'
            if ($errors) { throw "Installed game errors: $errors" }
            Assert-Records
        }
    }

    if ($Phase -in @('all', 'uninstall')) {
        $uninstallLog = Join-Path $PWD 'installer-uninstall.log'
        Invoke-SmokeProcess -FilePath (Join-Path $installDir 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=`"$uninstallLog`"") -Phase 'uninstall'
        if (Test-Path (Join-Path $installDir 'OneMoreTry.exe')) { throw 'Uninstall left the game executable behind' }
        Assert-Records
    }
    Write-Output "PASS: smoke phase $Phase with saved-record preservation"
} finally {
    # Preserve useful diagnostics even if a child process hangs before exiting.
    Get-ChildItem -Path $PWD -Filter 'installer-*.log' | ForEach-Object {
        Write-Output "Log: $($_.Name)"
        Get-Content -Path $_.FullName -Tail 60 -ErrorAction Continue
    }
}

$ErrorActionPreference = 'Stop'
$installer = (Get-ChildItem build/installer/*-Setup.exe | Select-Object -First 1).FullName
if (!$installer) { throw 'Installer artifact is missing' }
# Exercise Unicode and spaces in paths. This is a disposable Windows CI runner.
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\One More Try 테스트'
$recordsDir = Join-Path $env:APPDATA 'Godot\app_userdata\한 번만 더!'
$recordsPath = Join-Path $recordsDir 'records.json'
New-Item -ItemType Directory -Path $recordsDir -Force | Out-Null
$sentinel = '{"version":1,"deaths":123,"attempts":7,"clears":2,"best_time":15.25,"no_death":true,"secret":true,"music":false,"sfx":false}'
[IO.File]::WriteAllText($recordsPath, $sentinel)

function Assert-Records {
    if (!(Test-Path $recordsPath) -or [IO.File]::ReadAllText($recordsPath) -ne $sentinel) {
        throw 'Installer changed or removed saved records'
    }
}

foreach ($phase in @('install', 'reinstall')) {
    $logPath = Join-Path $PWD "installer-$phase.log"
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$installDir`"", "/LOG=`"$logPath`"")
    $process = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Installer $phase exited with $($process.ExitCode)" }
    foreach ($file in @('OneMoreTry.exe', 'README.txt', 'licenses\Godot.txt', 'licenses\NotoSansCJK.txt', 'unins000.exe')) {
        if (!(Test-Path (Join-Path $installDir $file))) { throw "Installed file missing: $file" }
    }
    Assert-Records
    $process = Start-Process -FilePath (Join-Path $installDir 'OneMoreTry.exe') -ArgumentList '--headless','--audio-driver','Dummy','--quit-after','120','--','--test' -PassThru -Wait -RedirectStandardOutput "installer-$phase-stdout.log" -RedirectStandardError "installer-$phase-stderr.log"
    if ($process.ExitCode -ne 0) { throw "Installed game exited with $($process.ExitCode)" }
    $errors = Select-String -Path "installer-$phase-stdout.log","installer-$phase-stderr.log" -Pattern 'SCRIPT ERROR|ERROR:'
    if ($errors) { throw "Installed game errors: $errors" }
    Assert-Records
}

$uninstallLog = Join-Path $PWD 'installer-uninstall.log'
$process = Start-Process -FilePath (Join-Path $installDir 'unins000.exe') -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=`"$uninstallLog`"" -PassThru -Wait
if ($process.ExitCode -ne 0) { throw "Uninstall exited with $($process.ExitCode)" }
if (Test-Path (Join-Path $installDir 'OneMoreTry.exe')) { throw 'Uninstall left the game executable behind' }
Assert-Records
Write-Output 'PASS: install, reinstall, installed game launch, uninstall and saved-record preservation'

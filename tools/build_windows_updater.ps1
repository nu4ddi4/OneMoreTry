$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$references = @('/r:System.IO.Compression.dll', '/r:System.IO.Compression.FileSystem.dll', '/r:System.Runtime.Serialization.dll')
& $compiler /nologo /target:winexe /out:build/windows/OneMoreTry.Update.exe @references tools/windows-updater/Updater.cs
if ($LASTEXITCODE -ne 0) { throw 'Updater compilation failed' }
& $compiler /nologo /target:exe /main:UpdaterTests /out:build/Updater.Tests.exe @references tools/windows-updater/Updater.cs tools/windows-updater/Tests.cs
if ($LASTEXITCODE -ne 0) { throw 'Updater tests compilation failed' }
$info = Get-Content build/release-info.json -Raw | ConvertFrom-Json
@{schema=1; version=$info.version; channel=$info.channel} | ConvertTo-Json | Set-Content build/windows/update-manifest.json -Encoding utf8
'public static class Crash { public static int Main() { return 1; } }' | Set-Content build/Crash.cs
& $compiler /nologo /target:winexe /out:build/Crash.exe build/Crash.cs
if ($LASTEXITCODE -ne 0) { throw 'Crash fixture compilation failed' }
& ./build/Updater.Tests.exe ./build/windows *> updater-native.log
$result = $LASTEXITCODE
Get-Content updater-native.log
if ($result -ne 0) { throw 'Native updater tests failed' }

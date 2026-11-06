$ErrorActionPreference = 'Stop'
$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compiler = Join-Path $framework 'csc.exe'
$windowsDir = (Resolve-Path 'build/windows').Path
$buildDir = (Resolve-Path 'build').Path
$source = (Resolve-Path 'tools/windows-updater/Updater.cs').Path
$testSource = (Resolve-Path 'tools/windows-updater/Tests.cs').Path
$helper = Join-Path $windowsDir 'OneMoreTry.Update.exe'
$tests = Join-Path $buildDir 'Updater.Tests.exe'
$references = @('System.IO.Compression.dll', 'System.IO.Compression.FileSystem.dll', 'System.Runtime.Serialization.dll') | ForEach-Object { '/r:' + (Join-Path $framework $_) }
$arguments = @('/nologo', '/target:winexe', "/out:$helper") + $references + @($source)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Updater compilation failed' }
$arguments = @('/nologo', '/target:exe', '/main:UpdaterTests', "/out:$tests") + $references + @($source, $testSource)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Updater tests compilation failed' }
$info = Get-Content build/release-info.json -Raw | ConvertFrom-Json
@{schema=1; version=$info.version; channel=$info.channel} | ConvertTo-Json | Set-Content (Join-Path $windowsDir 'update-manifest.json') -Encoding utf8
$crashSource = Join-Path $buildDir 'Crash.cs'
$crashExe = Join-Path $buildDir 'Crash.exe'
'public static class Crash { public static int Main() { return 1; } }' | Set-Content $crashSource
& $compiler /nologo /target:winexe "/out:$crashExe" $crashSource
if ($LASTEXITCODE -ne 0) { throw 'Crash fixture compilation failed' }
& $tests $windowsDir *> updater-native.log
$result = $LASTEXITCODE
Get-Content updater-native.log
if ($result -ne 0) { throw 'Native updater tests failed' }

# Windows PowerShell on Windows, or PowerShell 7 on Debian/Ubuntu.
$ErrorActionPreference = 'Stop'
$apt = 'https://nu4ddi4.github.io/OneMoreTry/apt'
$windows = $env:OS -eq 'Windows_NT'
if (($windows -and [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') -or (-not $windows -and -not $IsLinux)) {
    throw 'Supported platforms are Windows x64 and Debian/Ubuntu amd64.'
}
if (-not $windows) {
    $architecture = & dpkg --print-architecture
    if ($LASTEXITCODE -ne 0 -or $architecture -ne 'amd64') { throw 'A Debian amd64 installation is required.' }
}
$debVersion = ([string](Invoke-RestMethod -Uri "$apt/version.txt")).Trim()
if ($debVersion -notmatch '^(?<version>[0-9]+\.[0-9]+\.[0-9]+)-[1-9][0-9]*$') { throw 'Invalid Debian version.' }
$version = $Matches.version
if ([version]$version -lt [version]'0.8.1') { throw 'The matching Windows and Linux release is not available yet.' }
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/nu4ddi4/OneMoreTry/releases/tags/v$version"
$file = "OneMoreTry-v$version-Windows-x64-Setup.exe"
$url = "https://github.com/nu4ddi4/OneMoreTry/releases/download/v$version/$file"
$asset = $release.assets | Where-Object { $_.name -eq $file }
if ($release.draft -or $release.prerelease -or $asset.browser_download_url -ne $url -or $asset.digest -notmatch '^sha256:([a-f0-9]{64})$') {
    throw 'The matching verified Windows installer is not available yet.'
}
$hash = $Matches[1]

function Invoke-RootCommand {
    param([string[]] $Command)
    & sudo @Command
    if ($LASTEXITCODE -ne 0) { throw "$($Command[0]) failed with exit code $LASTEXITCODE." }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
New-Item -Path $work -ItemType Directory | Out-Null
try {
    if ($windows) {
        $installer = Join-Path $work $file
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installer
        if ((Get-FileHash $installer -Algorithm SHA256).Hash -ne $hash) { throw 'Windows installer checksum verification failed.' }
        $setup = Start-Process -FilePath $installer -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait -PassThru
        if ($setup.ExitCode -ne 0) { throw "Windows setup failed with exit code $($setup.ExitCode)." }
    } else {
        $key = Join-Path $work 'onemoretry.asc'
        $source = Join-Path $work 'onemoretry.list'
        Invoke-WebRequest -Uri "$apt/onemoretry-archive-keyring.asc" -OutFile $key
        if ((Get-FileHash $key -Algorithm SHA256).Hash -ne '8EB6F8BF99427F8B265853CB6F828001AD43470D215C31B26BB9A08D89736F35') {
            throw 'The APT public key differs from the key pinned in this installer.'
        }
        Set-Content -Path $source -Encoding Ascii -Value "deb [arch=amd64 signed-by=/etc/apt/keyrings/onemoretry.asc] $apt stable main"
        Invoke-RootCommand -Command @('install', '-D', '-m', '644', $key, '/etc/apt/keyrings/onemoretry.asc')
        Invoke-RootCommand -Command @('install', '-D', '-m', '644', $source, '/etc/apt/sources.list.d/onemoretry.list')
        Invoke-RootCommand -Command @('apt-get', 'update')
        Invoke-RootCommand -Command @('apt-get', 'install', '-y', "onemoretry=$debVersion")
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}

# Windows PowerShell on Windows, or PowerShell 7 on Debian/Ubuntu.
$ErrorActionPreference = 'Stop'
$windows = $env:OS -eq 'Windows_NT'
if (($windows -and [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') -or (-not $windows -and -not $IsLinux)) {
    throw 'Supported platforms are Windows x64 and Debian/Ubuntu amd64.'
}
if (-not $windows) {
    $architecture = & dpkg --print-architecture
    if ($LASTEXITCODE -ne 0 -or $architecture -ne 'amd64') { throw 'A Debian amd64 installation is required.' }
}

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/nu4ddi4/OneMoreTry/releases/latest'
if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^v([0-9]+\.[0-9]+\.[0-9]+)$') {
    throw 'The current stable release is unavailable.'
}
$version = $Matches[1]
$windowsFile = "OneMoreTry-v$version-Windows-x64-Setup.exe"
$linuxPattern = '^onemoretry_' + [regex]::Escape($version) + '-[1-9][0-9]*_amd64\.deb$'
$windowsAssets = @($release.assets | Where-Object { $_.name -eq $windowsFile })
$linuxAssets = @($release.assets | Where-Object { $_.name -match $linuxPattern })
if ($windowsAssets.Count -ne 1 -or $linuxAssets.Count -ne 1) {
    throw 'The matching Windows and Linux installers are not available yet.'
}
$asset = if ($windows) { $windowsAssets[0] } else { $linuxAssets[0] }
$url = "https://github.com/nu4ddi4/OneMoreTry/releases/download/v$version/$($asset.name)"
if ($asset.browser_download_url -ne $url -or $asset.digest -notmatch '^sha256:([a-f0-9]{64})$') {
    throw 'The installer download URL or checksum is invalid.'
}
$hash = $Matches[1]

$work = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
New-Item -Path $work -ItemType Directory | Out-Null
try {
    $installer = Join-Path $work $asset.name
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installer
    if ((Get-FileHash $installer -Algorithm SHA256).Hash -ne $hash) {
        throw 'Installer checksum verification failed.'
    }
    if ($windows) {
        $setup = Start-Process -FilePath $installer -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait -PassThru
        if ($setup.ExitCode -ne 0) { throw "Windows setup failed with exit code $($setup.ExitCode)." }
    } else {
        & sudo apt-get install -y $installer
        if ($LASTEXITCODE -ne 0) { throw "Debian package installation failed with exit code $LASTEXITCODE." }
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}

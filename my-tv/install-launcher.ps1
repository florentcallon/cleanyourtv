# Build and install the launcher on the Philips 55OLED855 without Android Studio.
#
# BUILD: every push to main that touches launcher/ (for example the dock in
#   launcher/app/src/main/res/values/config.xml) makes the "Build launcher APK" GitHub Actions workflow
#   of github.com/florentcallon/cleanyourtv build the APK and publish it as a release
#   "launcher-<commit>" with its sha256 in the notes. Watch it under the repo's Actions tab (~3 min).
# INSTALL: turn USB debugging on on the TV, then from the cleanyourtv work folder:
#   powershell -ExecutionPolicy Bypass -File install-launcher.ps1              # newest release
#   powershell -ExecutionPolicy Bypass -File install-launcher.ps1 -Tag launcher-029a9cafc0
# The APK is downloaded, checked against the sha256 in the release notes, pushed in base64 chunks with
# an md5 check (tools\b64push.py), installed with pm install -r, compiled, started, and made Home.
param(
    [string]$TvHost = '192.168.1.160',
    [string]$Tag = '',
    [string]$Repo = 'florentcallon/cleanyourtv'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$api = if ($Tag) { "https://api.github.com/repos/$Repo/releases/tags/$Tag" } else { "https://api.github.com/repos/$Repo/releases/latest" }
$rel = Invoke-RestMethod -UseBasicParsing -Uri $api -Headers @{ 'User-Agent' = 'cleanyourtv' }
$sha = [regex]::Match($rel.body, 'sha256: ([0-9a-f]{64})').Groups[1].Value
if (-not $sha) { throw "release $($rel.tag_name) has no sha256 in its notes" }
Write-Host "Release $($rel.tag_name), sha256 $sha"
# Home already belongs to this launcher after the first install, so nothing else is disabled.
$stock = 'none'
$owner = (& (Join-Path $root 'repo\tools\venv\Scripts\python.exe') -I (Join-Path $root 'repo\tools\tv.py') `
    'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' 2>$null | Select-Object -Last 1)
if ("$owner" -match '^com\.google\.android\.tvlauncher/') { $stock = 'com.google.android.tvlauncher' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'repo\launcher\install-prebuilt.ps1') `
    -TvHost $TvHost -Tag $rel.tag_name -Sha256 $sha -Repo $Repo -StockLauncher $stock

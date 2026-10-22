# Install a launcher APK built elsewhere (this fork's "Build launcher APK" GitHub Actions workflow
# publishes one per commit as a release) without Android Studio, then make it the default Home. The
# steps after the build are the same as build-and-install.ps1, except that the APK is compiled with
# `cmd package compile -m speed` BEFORE the first start: on this 32-bit MT5887 board the first cold
# start of an uncompiled launcher takes longer than `am start -W` waits (examples/philips-75pus8505).
#
# Usage: launcher\install-prebuilt.ps1 -TvHost 192.168.1.50 -Tag launcher-<commit> -Sha256 <hash>
#        launcher\install-prebuilt.ps1 -TvHost 192.168.1.50 -Apk C:\path\app-release.apk
#        [-Repo owner/name] [-StockLauncher <package>|none] [-InputKeyService] [-HomeKeyService] [-BootHomeService]
param(
    [string]$TvHost = $env:TV_HOST,
    [string]$Apk = '',
    [string]$Tag = '',
    [string]$Sha256 = '',
    [string]$Repo = 'florentcallon/cleanyourtv',
    [string]$StockLauncher = '',
    [switch]$InputKeyService,
    [switch]$HomeKeyService,
    [switch]$BootHomeService
)
$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
if (-not $TvHost) { throw 'pass -TvHost <tv ip> or set $env:TV_HOST' }
$env:TV_HOST = $TvHost
Set-Location $PSScriptRoot

if (-not $Apk) {
    if (-not $Tag) { throw 'pass -Apk <file> or -Tag launcher-<commit> (see the Releases page of your fork)' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    $Apk = Join-Path $env:TEMP "tvhome-$Tag.apk"
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/releases/download/$Tag/app-release.apk" -OutFile $Apk
}
$hash = (Get-FileHash -Algorithm SHA256 $Apk).Hash.ToLower()
Write-Host "APK $Apk sha256 $hash"
if ($Sha256 -and $hash -ne $Sha256.ToLower()) { throw "sha256 mismatch: expected $Sha256 (release notes), got $hash" }

$py = '..\tools\venv\Scripts\python.exe'
# Which app owns Home differs by build; ask the TV, but only accept a launcher we recognise (the answer
# can also be Android's chooser "android", the setup wizard, or another third-party launcher).
$knownStock = @('com.google.android.tvlauncher', 'com.google.android.apps.tv.launcherx', 'com.google.android.leanbacklauncher', 'com.mitv.tvhome')
if (-not $StockLauncher) {
    $homePkg = & $py -I ..\tools\tv.py 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0 -or -not $homePkg) { throw 'could not ask the TV which launcher owns Home; check -TvHost and the debugging prompt, or pass -StockLauncher <package>' }
    $homePkg = "$homePkg".Trim().Split('/')[0]
    if ($knownStock -contains $homePkg) { $StockLauncher = $homePkg }
    elseif ($homePkg -eq 'com.gathin.tvhome') { $StockLauncher = 'none'; Write-Host 'Home already belongs to this launcher; nothing will be disabled.' }
    elseif ($homePkg -eq 'android') {
        # Android's chooser: launchers tie and no default is set (a restore followed by a re-applied list
        # ends here). Take the one known stock launcher among the HOME claimants, if there is exactly one.
        $claimants = (& $py -I ..\tools\tv.py 'cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -join "`n"
        $found = @($knownStock | Where-Object { $claimants -match ([regex]::Escape($_) + '/') })
        if ($found.Count -eq 1) { $StockLauncher = $found[0]; Write-Host "Home is Android's chooser; the stock launcher among the candidates is $StockLauncher." }
        else { throw "Home is Android's launcher chooser and $($found.Count) known stock launchers claim Home: pick a default on the TV first, or run again with -StockLauncher <package to disable> or -StockLauncher none." }
    }
    else { throw "Home currently resolves to '$homePkg', which is not a stock launcher this script knows (android = launcher chooser, com.google.android.tungsten.setupwraith = setup wizard, see README Troubleshooting; anything else = another launcher is the default). Run again with -StockLauncher <package to disable> or -StockLauncher none." }
}
Write-Host "Stock launcher: $StockLauncher"
$disableStock = if ($StockLauncher -eq 'none') { 'echo stock launcher left alone' } else { "pm disable-user --user 0 $StockLauncher" }

& $py -I ..\tools\b64push.py $Apk /data/local/tmp/tvhome.apk
if ($LASTEXITCODE -ne 0) { throw 'APK upload failed' }
$out = & $py -I ..\tools\tv.py 'pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk'
Write-Host $out
if ("$out" -notmatch 'Success') { throw 'pm install failed; the stock launcher was left untouched' }
# Android 9 only accepts a component here; Android 10+ also takes a bare package name.
$out = & $py -I ..\tools\tv.py 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity'
Write-Host $out
if ("$out" -match 'Error') { throw 'could not set the new launcher as home; the stock launcher was left untouched' }
# Start the launcher on its own, before the stock Home is touched (see build-and-install.sh, #239):
# in the batch a failed start only prints an Error line and the stock launcher would be disabled anyway.
& $py -I ..\tools\tv.py 'cmd package compile -m speed -f com.gathin.tvhome' | Write-Host
$start = (& $py -I ..\tools\tv.py 'am start -W -n com.gathin.tvhome/.MainActivity') -join "`n"
Write-Host $start
if ($start -notmatch 'Status: ok' -or $start -match '(?m)^Error') { throw "the new launcher did not start (see above); $StockLauncher was left enabled" }
@(
    'pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION 2>/dev/null; echo location-granted',
    'cmd package compile -m speed -f com.gathin.tvhome',
    $disableStock,
    'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity'
) | & $py -I ..\tools\tv.py --batch
# Order matters, see build-and-install.sh: start the new launcher, disable the stock one, set the
# preference last, then check where Home ended up and put the stock launcher back if it is not ours.
$homeNow = (& $py -I ..\tools\tv.py 'cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN' | Select-Object -Last 1).Trim()
if ($homeNow -notlike 'com.gathin.tvhome/*') {
    if ($StockLauncher -ne 'none') {
        & $py -I ..\tools\tv.py "pm enable --user 0 $StockLauncher" | Out-Null
        # set-home-activity needs pkg/activity on Android 9, so resolve the stock component on the TV.
        & $py -I ..\tools\tv.py "cmd package set-home-activity --user 0 `$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME $StockLauncher | tail -n 1)" | Out-Null
    }
    throw "Home resolves to '$homeNow', not to the new launcher; $StockLauncher was re-enabled. On Google TV this usually means com.google.android.tungsten.setupwraith also claims Home: add it to your debloat list (see README, Troubleshooting), apply it, then run this script again."
}
Write-Host "Home now resolves to $homeNow"
# Optional accessibility services, appended to enabled_accessibility_services without dropping others.
function Enable-Service([string]$Name) {
    $svc = "com.gathin.tvhome/.$Name"
    # Through stdin: Windows PowerShell 5.1 drops the inner double quotes from a native argument, and the
    # TV's shell then fails with "no closing quote" while the service stays off.
    ('s=$(settings get secure enabled_accessibility_services); case "$s" in *' + $Name + '*) ;; null|"") settings put secure enabled_accessibility_services ' + $svc + ' ;; *) settings put secure enabled_accessibility_services "$s:' + $svc + '" ;; esac; settings put secure accessibility_enabled 1; echo ' + $Name + ' enabled') |
        & $py -I ..\tools\tv.py --batch
}
if ($InputKeyService) { Enable-Service 'InputKeyService' }
if ($HomeKeyService) { Enable-Service 'HomeKeyService' }
if ($BootHomeService) { Enable-Service 'BootHomeService' }
Write-Host 'Installed. Press Home on the remote to see it.'

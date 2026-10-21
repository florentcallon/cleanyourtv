# Undo the debloat of the Philips 55OLED855 (TPM191E) and give Home back to the stock Google launcher.
#
# Turn USB debugging (and Network debugging if shown) back on on the TV first, then run from the
# cleanyourtv work folder (the one holding repo\, python\ and this script):
#
#   powershell -ExecutionPolicy Bypass -File restore-tv.ps1                 # re-enable everything we disabled
#   powershell -ExecutionPolicy Bypass -File restore-tv.ps1 -UndoDns        # ...and turn the AdGuard DNS off
#   powershell -ExecutionPolicy Bypass -File restore-tv.ps1 -RemoveLauncher # ...and uninstall the new launcher
#   powershell -ExecutionPolicy Bypass -File restore-tv.ps1 -Force          # ignore the recovery record and
#                                                                           # pm enable every listed package
#
# Normal mode replays the record that tools\disable.ps1 wrote before the first change
# (%USERPROFILE%\.cleanyourtv\recovery-<tv ip>-*.json, copy kept in backup\): packages that were already
# disabled before (the 16 Freeview packages) stay disabled, everything else comes back, and Home goes
# back to com.google.android.tvlauncher. -Force does not need the record.
param(
    [string]$TvHost = '192.168.1.160',
    [switch]$Force,
    [switch]$UndoDns,
    [switch]$RemoveLauncher
)
$ErrorActionPreference = 'Continue'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = $PSScriptRoot
$repo = Join-Path $root 'repo'
$py = Join-Path $repo 'tools\venv\Scripts\python.exe'
if (-not (Test-Path $py)) { $py = Join-Path $root 'python\python.exe' }
$tv = Join-Path $repo 'tools\tv.py'
$list = Join-Path $repo 'examples\philips-55oled855\debloat.txt'
$stock = 'com.google.android.tvlauncher'
$env:TV_HOST = $TvHost

$probe = (& $py -I $tv 'echo connected' 2>&1) -join ' '
if ($probe -notmatch 'connected') {
    throw "Cannot reach the TV at ${TvHost}:5555 ($probe). Turn USB debugging on (Settings > Device Preferences > Developer options) and accept the prompt on the TV."
}

$done = $false
if (-not $Force) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\restore.ps1') -TvHost $TvHost -Stock $stock $list
    $done = ($LASTEXITCODE -eq 0)
    if (-not $done) { Write-Warning 'The recorded restore failed; falling back to enabling every listed package.' }
}
if (-not $done) {
    $pkgs = Get-Content $list | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ } |
        ForEach-Object { ($_ -split '\s+')[0] }
    $cmds = @($pkgs | ForEach-Object { "pm enable $_" })
    $cmds += "pm enable $stock"
    $cmds += "cmd package set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity"
    $cmds += 'pm list packages -d'
    $cmds | & $py -I $tv --batch
}
if ($UndoDns) {
    @('settings put global private_dns_mode opportunistic', 'settings delete global private_dns_specifier',
      'settings get global private_dns_mode') | & $py -I $tv --batch
}
if ($RemoveLauncher) {
    @('pm uninstall com.gathin.tvhome',
      'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') | & $py -I $tv --batch
}
& $py -I $tv 'input keyevent HOME' | Out-Null
Write-Host 'Done. Press Home on the remote. Switch USB debugging off again when you are finished.'

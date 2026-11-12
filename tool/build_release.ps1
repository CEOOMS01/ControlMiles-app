# Olympus Mont Systems LLC - ControlMiles
# tool/build_release.ps1
#
# Builds the Play bundle (AAB) with the Dart code obfuscated (2026-11-10): class and
# function names inside the app become letters, so a decompiled app does not show how
# trips, gig segments or the odometer audit work. The Android (Kotlin) part is already
# shrunk and renamed by R8 in every release build.
#
# The symbol files are the only way to read a stack trace from an obfuscated build
# (for example one inside a diagnostic). They are kept per version in
# release-symbols/<version>/, outside build/ so `flutter clean` does not delete them,
# and out of git. Do not delete a version's folder while that version is in use.
#
#   powershell -ExecutionPolicy Bypass -File tool\build_release.ps1
#
# Reading an obfuscated stack trace saved to trace.txt:
#   flutter symbolize -i trace.txt -d release-symbols\<version>\app.android-arm64.symbols

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$line = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $line) { throw 'No version line in pubspec.yaml' }
$version = $line.Matches[0].Groups[1].Value            # e.g. 1.3.33+73
$tag = $version -replace '\+', '-'                      # e.g. 1.3.33-73

$symbols = Join-Path $root "release-symbols\$version"
if (Test-Path $symbols) { throw "release-symbols\$version already exists: bump the version in pubspec.yaml first" }

flutter build appbundle --release --obfuscate --split-debug-info="$symbols"
if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }

$aab = Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
$out = Join-Path ([Environment]::GetFolderPath('Desktop')) "ControlMiles-gig-$tag.aab"
Copy-Item $aab $out -Force
Get-Item $out | Select-Object FullName, Length, LastWriteTime | Format-List
Get-ChildItem $symbols | Select-Object Name, Length | Format-Table -AutoSize

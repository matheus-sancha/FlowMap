<#
.SYNOPSIS
  Packages a FlowMap drop: one zip, one label, one commit.

.DESCRIPTION
  Run from the repo root:

    powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1 -Label 2.1-2026-09-13

  In order, it:
    1. refuses if the tag for this drop already exists, or the tree is dirty,
       because then the tag would not describe what is in the zip;
    2. builds release with --dart-define=BUILD_LABEL=<Label> (a release build
       without one refuses to start, see lib/src/app/build_info.dart);
    3. stages the build and adds the three Visual C++ runtime DLLs, which Flutter
       links dynamically and does not ship, so a PC that never had Visual Studio
       cannot start the app without them;
    4. adds READ ME FIRST.txt, manual.html and example.flowmap from tool\drop;
    5. zips to dist\FlowMap-<Label>.zip and prints its size and SHA-256;
    6. prints the git tag command. It does not run it: a packaging script does
       not create refs in the repo.

  It does NOT run flutter analyze or flutter test. That is a decision: run them
  before packaging, the way the phase plan says.

  Users unzip a new version over the old one. That is safe because the app's
  data lives in %APPDATA%\com.sancha\flowmap (lib/src/data/app_directory.dart)
  and projects are .flowmap files the user placed, never in the program folder.

  ASCII only: Windows PowerShell 5.1 reads a .ps1 as ANSI.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Label,

  # The git tag this drop is recorded under. Defaults to v<label up to the first dash>.
  [string]$Tag,

  [switch]$SkipBuild,
  [switch]$AllowDirty,
  [switch]$AllowExistingTag
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path 'pubspec.yaml')) {
  throw 'Run this from the repo root (where pubspec.yaml is).'
}
if ($Label -notmatch '^[0-9A-Za-z][0-9A-Za-z.\-]*$') {
  throw "Label '$Label' must be letters, digits, dots and dashes, e.g. 2.1-2026-09-13."
}
if (-not $Tag) { $Tag = 'v' + ($Label -split '-')[0] }

# 1. Refusals, each with its remedy.
if (-not $AllowExistingTag) {
  $existing = git tag --list $Tag
  if ($existing) {
    throw "Tag $Tag already exists: that drop is already out. Use a new -Label/-Tag, or -AllowExistingTag for a throwaway build."
  }
}
if (-not $AllowDirty) {
  $dirty = git status --porcelain
  if ($dirty) {
    throw 'The working tree is dirty, so the tag would not describe the zip. Commit first, or pass -AllowDirty for a throwaway build.'
  }
}
$commit = (git rev-parse --short HEAD).Trim()

# 2. Build.
if (-not $SkipBuild) {
  flutter build windows --release "--dart-define=BUILD_LABEL=$Label"
  if ($LASTEXITCODE -ne 0) { throw 'flutter build failed.' }
}
$release = 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'flowmap.exe'))) {
  throw "No build at $release. Run without -SkipBuild."
}

# 3. Stage. Only the staging folder is cleared: the zips already in dist are the
#    drops already handed out.
$dist = 'dist'
$stage = Join-Path $dist 'stage'
$app = Join-Path $stage 'FlowMap'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $app | Out-Null
Copy-Item -Recurse -Force (Join-Path $release '*') $app

# The newest MSVC redist, by parsed version: a string sort puts 14.44 below 14.9.
$roots = @(
  "${env:ProgramFiles}\Microsoft Visual Studio",
  "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
) | Where-Object { $_ -and (Test-Path $_) }
$crt = Get-ChildItem -Path $roots -Recurse -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\VC\\Redist\\MSVC\\([0-9.]+)\\x64\\' } |
  Sort-Object { [version]([regex]::Match($_.FullName, '\\MSVC\\([0-9.]+)\\').Groups[1].Value) } -Descending |
  Select-Object -First 1
if (-not $crt) {
  throw 'Visual C++ redistributable DLLs not found under Visual Studio\...\VC\Redist\MSVC\*\x64. Install the C++ desktop workload.'
}
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item -Force (Join-Path $crt.FullName $dll) $app
}

# 4. What rides with the app.
foreach ($file in 'READ ME FIRST.txt', 'manual.html', 'example.flowmap') {
  $source = Join-Path 'tool\drop' $file
  if (-not (Test-Path $source)) { throw "Missing $source." }
  Copy-Item -Force $source $app
}

# 5. Zip.
$zip = Join-Path $dist "FlowMap-$Label.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $app -DestinationPath $zip
Remove-Item -Recurse -Force $stage

$item = Get-Item $zip
$hash = (Get-FileHash -Algorithm SHA256 $zip).Hash
Write-Host ''
Write-Host "Drop     $Label"
Write-Host "Commit   $commit"
Write-Host "Zip      $($item.FullName)"
Write-Host ("Size     {0:N1} MB" -f ($item.Length / 1MB))
Write-Host "SHA-256  $hash"
Write-Host "Runtime  $($crt.FullName)"
Write-Host ''
Write-Host 'Now tag the commit you packaged:'
Write-Host "  git tag -a $Tag -m `"FlowMap $Label`" $commit"
Write-Host "  git push origin $Tag"

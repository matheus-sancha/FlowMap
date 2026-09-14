<#
.SYNOPSIS
  Packages a FlowMap drop: one zip, one label, one commit, signed if a
  certificate is given.

.DESCRIPTION
  Run from the repo root:

    powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1 -Label 2.1.2-2026-09-13

  In order, it:
    1. refuses if the tag for this drop already exists, the tree is dirty, or
       pubspec.yaml's version disagrees with the label, because then the tag,
       or the version Windows reads off the exe, would not describe the zip;
    2. builds release with --dart-define=BUILD_LABEL=<Label> (a release build
       without one refuses to start, see lib/src/app/build_info.dart);
    3. stages the build and adds the three Visual C++ runtime DLLs, which Flutter
       links dynamically and does not ship, so a PC that never had Visual Studio
       cannot start the app without them;
    4. adds READ ME FIRST.txt, manual.html and example.flowmap from tool\drop;
    5. signs flowmap.exe and every unsigned DLL beside it, if a certificate was
       given, and says loudly that Windows will call the drop's publisher
       unknown if one was not (docs\SIGNING.md);
    6. zips to dist\FlowMap-<Label>.zip and prints its size and SHA-256;
    7. prints the git tag command. It does not run it: a packaging script does
       not create refs in the repo.

  It does NOT run flutter analyze or flutter test. That is a decision: run them
  before packaging, the way the phase plan says.

  Signing, which is what stops SmartScreen calling the app an unknown publisher.
  One of three, and docs\SIGNING.md says which to buy and why:

    # Azure Trusted Signing (no token to carry, the certificate is Microsoft's)
    ... -AzureSignDlib C:\ats\bin\x64\Azure.CodeSigning.Dlib.dll `
        -AzureSignMetadata C:\ats\metadata.json

    # A certificate on a hardware token or in the user's certificate store
    ... -CertificateThumbprint A1B2C3...

    # A .pfx file. The password comes from $env:FLOWMAP_CERT_PASSWORD, or is
    # asked for, so it never lands in the shell history.
    ... -CertificatePath C:\certs\flowmap.pfx

  Users unzip a new version over the old one. That is safe because the app's
  data lives in %APPDATA%\com.sancha\flowmap (lib/src/data/app_directory.dart)
  and projects are .flowmap files the user placed, never in the program folder.

  ASCII only: Windows PowerShell 5.1 reads a .ps1 as ANSI.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Label,

  # The git tag this drop is recorded under. Defaults to v<label up to the first dash>.0.
  [string]$Tag,

  [switch]$SkipBuild,
  [switch]$AllowDirty,
  [switch]$AllowExistingTag,
  [switch]$AllowVersionMismatch,

  # Signing. At most one of these three may be given; none means an unsigned
  # drop, which still builds and still warns.
  [string]$AzureSignMetadata,
  [string]$AzureSignDlib,
  [string]$CertificateThumbprint,
  [string]$CertificatePath,

  # Only for -CertificatePath. Prefer $env:FLOWMAP_CERT_PASSWORD.
  [string]$CertificatePassword,

  # A signature with no countersignature dies with the certificate, about a year
  # out; a timestamped one outlives it. Not optional, therefore, only defaulted.
  [string]$TimestampUrl,

  [string]$SignToolPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path 'pubspec.yaml')) {
  throw 'Run this from the repo root (where pubspec.yaml is).'
}
if ($Label -notmatch '^[0-9A-Za-z][0-9A-Za-z.\-]*$') {
  throw "Label '$Label' must be letters, digits, dots and dashes, e.g. 2.1-2026-09-13."
}
if (-not $Tag) { $Tag = 'v' + ($Label -split '-')[0] + '.0' }

# A tag named like a branch makes every ref that names it ambiguous: work for
# v2.1 happens on a branch called v2.1, so the drop is tagged v2.1.0.
if (git branch --list $Tag) {
  throw "Tag $Tag would share its name with a branch. Pass -Tag with a different name."
}

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

# pubspec.yaml's version is what Flutter compiles into flowmap.exe's FileVersion
# (windows\runner\Runner.rc), so it is the version Explorer, Windows and an IT
# allow-list read off the file. A label that disagrees with it ships an exe that
# misreports which drop it is.
$pubspecVersion = ''
foreach ($line in Get-Content 'pubspec.yaml') {
  if ($line -match '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { $pubspecVersion = $Matches[1]; break }
}
if (-not $pubspecVersion) {
  throw 'No version: x.y.z line in pubspec.yaml, so flowmap.exe would carry no version.'
}
$labelVersion = ($Label -split '-')[0]
if ($labelVersion -ne $pubspecVersion -and -not $AllowVersionMismatch) {
  throw "pubspec.yaml says version $pubspecVersion but the label says $labelVersion, so flowmap.exe would report the wrong one. Set 'version: $labelVersion+<build>' in pubspec.yaml and commit it, or pass -AllowVersionMismatch for a throwaway build."
}

$commit = (git rev-parse --short HEAD).Trim()

# How the drop will be signed, settled before the build so an unusable
# certificate fails in seconds rather than after a release build.
$modes = @()
if ($AzureSignMetadata) { $modes += 'azure' }
if ($CertificateThumbprint) { $modes += 'thumbprint' }
if ($CertificatePath) { $modes += 'pfx' }
if ($modes.Count -gt 1) {
  throw "Give at most one of -AzureSignMetadata, -CertificateThumbprint, -CertificatePath. Got: $($modes -join ', ')."
}
$signMode = if ($modes.Count -eq 1) { $modes[0] } else { 'none' }

$signTool = ''
if ($signMode -ne 'none') {
  if (-not $TimestampUrl) {
    # Each CA runs its own; Microsoft's is the one Azure Trusted Signing expects.
    $TimestampUrl = if ($signMode -eq 'azure') { 'http://timestamp.acs.microsoft.com' } else { 'http://timestamp.digicert.com' }
  }

  if ($SignToolPath) {
    if (-not (Test-Path $SignToolPath)) { throw "No signtool.exe at $SignToolPath." }
    $signTool = (Resolve-Path $SignToolPath).Path
  }
  else {
    $onPath = Get-Command 'signtool.exe' -ErrorAction SilentlyContinue
    if ($onPath) {
      $signTool = $onPath.Source
    }
    else {
      $kits = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "${env:ProgramFiles}\Windows Kits\10\bin"
      ) | Where-Object { $_ -and (Test-Path $_) }
      $candidate = $null
      if ($kits) {
        # Newest SDK, by parsed version: a string sort puts 10.0.26100 below 10.0.9.
        $candidate = Get-ChildItem -Path $kits -Recurse -Filter 'signtool.exe' -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
          Sort-Object {
            $m = [regex]::Match($_.FullName, '\\bin\\([0-9.]+)\\')
            if ($m.Success) { [version]$m.Groups[1].Value } else { [version]'0.0.0.0' }
          } -Descending | Select-Object -First 1
      }
      if (-not $candidate) {
        throw 'signtool.exe not found. Install the Windows SDK (Windows App Certification Kit component is enough), or pass -SignToolPath.'
      }
      $signTool = $candidate.FullName
    }
  }

  if ($signMode -eq 'azure') {
    if (-not $AzureSignDlib) { throw 'Pass -AzureSignDlib alongside -AzureSignMetadata: it is the Azure.CodeSigning.Dlib.dll signtool loads.' }
    if (-not (Test-Path $AzureSignDlib)) { throw "No dlib at $AzureSignDlib." }
    if (-not (Test-Path $AzureSignMetadata)) { throw "No metadata json at $AzureSignMetadata." }
    $AzureSignDlib = (Resolve-Path $AzureSignDlib).Path
    $AzureSignMetadata = (Resolve-Path $AzureSignMetadata).Path
  }
  if ($signMode -eq 'pfx') {
    if (-not (Test-Path $CertificatePath)) { throw "No certificate at $CertificatePath." }
    $CertificatePath = (Resolve-Path $CertificatePath).Path
    if (-not $CertificatePassword) { $CertificatePassword = $env:FLOWMAP_CERT_PASSWORD }
    if (-not $CertificatePassword) {
      $secure = Read-Host -AsSecureString "Password for $CertificatePath"
      $CertificatePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    }
  }
}

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

# 5. Sign. Signing the staged copy rather than the build output keeps the build
#    tree reproducible and means a re-zip never ships a half-signed folder.
$signedAs = ''
$signedCount = 0
if ($signMode -ne 'none') {
  # flowmap.exe is the only file SmartScreen weighs, because it is the file the
  # user launches. The DLLs beside it are signed too, so that a WDAC or AppLocker
  # publisher rule can cover the whole folder with one rule. The Visual C++
  # runtime is already signed by Microsoft and is left alone: re-signing it would
  # replace Microsoft's signature with ours, which is strictly worse.
  $targets = @((Join-Path $app 'flowmap.exe'))
  $targets += Get-ChildItem -Path $app -Filter '*.dll' -File |
    Where-Object { (Get-AuthenticodeSignature $_.FullName).Status -ne 'Valid' } |
    ForEach-Object { $_.FullName }

  $signArgs = @('sign', '/fd', 'SHA256', '/tr', $TimestampUrl, '/td', 'SHA256',
                '/d', 'FlowMap', '/du', 'https://github.com/matheus-sancha/FlowMap')
  switch ($signMode) {
    'azure'      { $signArgs += @('/dlib', $AzureSignDlib, '/dmdf', $AzureSignMetadata) }
    'thumbprint' { $signArgs += @('/sha1', $CertificateThumbprint) }
    'pfx'        { $signArgs += @('/f', $CertificatePath, '/p', $CertificatePassword) }
  }

  Write-Host ''
  Write-Host "Signing $($targets.Count) files with $signMode, timestamped by $TimestampUrl ..."
  & $signTool @signArgs @targets
  if ($LASTEXITCODE -ne 0) {
    throw "signtool sign failed ($LASTEXITCODE). The drop is not signed; nothing was zipped."
  }

  # Verify as Windows will: /pa uses the Authenticode policy rather than the
  # driver one, so a certificate that signs but does not chain to a root the
  # machine trusts fails here instead of on a user's PC.
  $verify = & $signTool 'verify' '/pa' '/all' (Join-Path $app 'flowmap.exe') 2>&1
  if ($LASTEXITCODE -ne 0) {
    # signtool says which link in the chain failed, and that is the whole
    # diagnosis; swallowing it would leave only "does not chain".
    $verify | ForEach-Object { Write-Host $_ }
    throw 'signtool verify /pa failed: the signature does not chain to a trusted root. See docs\SIGNING.md.'
  }
  $sig = Get-AuthenticodeSignature (Join-Path $app 'flowmap.exe')
  if ($sig.Status -ne 'Valid') { throw "Signature status is $($sig.Status), not Valid." }
  $signedAs = $sig.SignerCertificate.Subject
  $signedCount = $targets.Count
}

# 6. Zip.
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
if ($signMode -eq 'none') {
  Write-Host "Signed   NO"
  Write-Host ''
  Write-Host 'An unsigned drop is the one Windows blocks: SmartScreen calls it an unknown'
  Write-Host 'publisher, and a user has to click More info > Run anyway on every machine.'
  Write-Host 'docs\SIGNING.md says which certificate to buy and how to pass it here.'
  Write-Host 'Until then, the release notes have to tell people to unblock the zip before'
  Write-Host 'unzipping it, which is what actually spares most of them the prompt.'
}
else {
  Write-Host "Signed   $signedAs ($signedCount files, timestamped)"
}
Write-Host ''
Write-Host 'Now tag the commit you packaged:'
Write-Host "  git tag -a $Tag -m `"FlowMap $Label`" $commit"
Write-Host "  git push origin $Tag"

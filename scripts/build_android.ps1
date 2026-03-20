# build_android.ps1
# Build release APK and prepare artifact for Firebase Storage OTA.
# Usage: .\scripts\build_android.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$appName = "QRecauda"
$storageBasePath = "releases/android"
$projectRoot = Join-Path $PSScriptRoot ".."

# Read pubspec.yaml and parse version/build.
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$pubspec = Get-Content $pubspecPath -Raw

if ($pubspec -match "(?m)^version:\s+(\d+\.\d+\.\d+)\+(\d+)") {
    $version = $Matches[1]
    $buildNumber = [int]$Matches[2]
} else {
    Write-Error "Could not parse 'version' from pubspec.yaml. Expected X.Y.Z+BUILD."
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  App:           $appName"
Write-Host "  Build version: $version+$buildNumber"
Write-Host "================================================" -ForegroundColor Cyan

# Build APK using the same build-name/build-number from pubspec.
Write-Host "`n[1/3] Building release APK..." -ForegroundColor Yellow
Set-Location $projectRoot
flutter build apk --release --build-name $version --build-number $buildNumber
$buildExitCode = $LASTEXITCODE

if ($buildExitCode -ne 0) {
    Write-Error "APK build failed. Stopping to avoid reusing stale artifacts."
    exit $buildExitCode
}

# Prepare output directory.
$outputDir = Join-Path $projectRoot "build\releases\android"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Copy and rename APK with exact built version/build.
$sourceApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $sourceApk)) {
    Write-Error "Build output not found: $sourceApk"
    exit 1
}

$targetName = "${appName}_${version}+${buildNumber}.apk"
$targetPath = Join-Path $outputDir $targetName

Write-Host "[2/3] Copying APK to: $targetPath" -ForegroundColor Yellow
Copy-Item $sourceApk $targetPath -Force
$fileSize = [math]::Round((Get-Item $targetPath).Length / 1MB, 2)

Write-Host "[3/3] Done." -ForegroundColor Green
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  File:      $targetName"
Write-Host "  Size:      ${fileSize} MB"
Write-Host "  Location:  $targetPath"
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEP:" -ForegroundColor Yellow
Write-Host "1) Upload this APK to Firebase Storage at:" -ForegroundColor Yellow
Write-Host "   $storageBasePath/$targetName" -ForegroundColor Yellow
Write-Host "2) Update Firestore doc: app_releases/latest" -ForegroundColor Yellow
Write-Host "   android.version     = `"$version`"" -ForegroundColor Yellow
Write-Host "   android.buildNumber = $buildNumber" -ForegroundColor Yellow
Write-Host "   android.storagePath = `"$storageBasePath/$targetName`"" -ForegroundColor Yellow
Write-Host "   android.fileName    = `"$targetName`"" -ForegroundColor Yellow
Write-Host ""

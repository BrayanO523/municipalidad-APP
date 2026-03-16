# build_android.ps1
# Script para construir el APK de release y prepararlo para subir a Firebase Storage.
# Uso: .\scripts\build_android.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Leer pubspec.yaml
$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
$pubspec = Get-Content $pubspecPath -Raw
$appName = "QRecauda"

# Extraer versión y build number
if ($pubspec -match "(?m)^version:\s+(\d+\.\d+\.\d+)\+(\d+)") {
    $version = $Matches[1]
    $buildNumber = $Matches[2]
} else {
    Write-Error "No se encontró 'version' en pubspec.yaml con formato X.Y.Z+BUILD"
    exit 1
}

# Incrementar versionCode en android/local.properties
$localPropsPath = Join-Path $PSScriptRoot "..\android\local.properties"
if (-not (Test-Path $localPropsPath)) {
    Write-Error "No se encontró android/local.properties"
    exit 1
}
$localProps = Get-Content $localPropsPath -Raw
if ($localProps -match "(?m)^flutter\.versionCode=(\d+)") {
    $androidVersionCode = [int]$Matches[1]
} else {
    Write-Error "No se encontró 'flutter.versionCode' en android/local.properties"
    exit 1
}
$nextAndroidVersionCode = $androidVersionCode + 1
$localProps = $localProps -replace "(?m)^flutter\.versionCode=\d+", "flutter.versionCode=$nextAndroidVersionCode"
Set-Content -Path $localPropsPath -Value $localProps

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  App:     $appName"
Write-Host "  Version: $version+$buildNumber"
Write-Host "================================================" -ForegroundColor Cyan

# Construir APK
Write-Host "`n[1/3] Construyendo APK de release..." -ForegroundColor Yellow
$projectRoot = Join-Path $PSScriptRoot ".."
Set-Location $projectRoot
flutter build apk --release --build-number $nextAndroidVersionCode
$buildExitCode = $LASTEXITCODE

# Asegurar que el archivo local.properties conserva el nuevo versionCode,
# incluso si Flutter/Gradle lo reescribe durante el build.
$localProps = Get-Content $localPropsPath -Raw
$localProps = $localProps -replace "(?m)^flutter\.versionCode=\d+", "flutter.versionCode=$nextAndroidVersionCode"
Set-Content -Path $localPropsPath -Value $localProps

if ($buildExitCode -ne 0) {
    Write-Error "La construccion del APK fallo. Se detiene el script para no reutilizar un APK anterior."
    exit $buildExitCode
}

# Preparar directorio de salida
$outputDir = Join-Path $projectRoot "build\releases\android"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Copiar y renombrar APK
$sourceApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$targetName = "${appName}_${version}+${buildNumber}.apk"
$targetPath = Join-Path $outputDir $targetName

Write-Host "[2/3] Copiando APK a: $targetPath" -ForegroundColor Yellow
Copy-Item $sourceApk $targetPath -Force

$fileSize = [math]::Round((Get-Item $targetPath).Length / 1MB, 2)

Write-Host "[3/3] ¡Listo!" -ForegroundColor Green
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Archivo generado: $targetName"
Write-Host "  Tamaño: ${fileSize} MB"
Write-Host "  Ubicación: $targetPath"
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  SIGUIENTE PASO:" -ForegroundColor Yellow
Write-Host "  Sube este archivo manualmente a Firebase Storage" -ForegroundColor Yellow
Write-Host "  en la ruta: releases/android/$targetName" -ForegroundColor Yellow
Write-Host ""

# BS 8110 Solid Slab Designer — Windows PowerShell Release APK Builder (v1.0.0)
# للتخطي الطارئ للاختبارات:  powershell -ExecutionPolicy Bypass -File scripts/build_release_apk.ps1 -SkipTests
param([switch]$SkipTests)

$ErrorActionPreference = "Stop"

# تشغيل السكربت من أي مجلد: ننتقل إلى جذر المشروع
Set-Location (Join-Path $PSScriptRoot "..")

# ملاحظة: $ErrorActionPreference لا يوقف السكربت عند فشل الأوامر الخارجية (flutter/dart)،
# لذلك نفحص $LASTEXITCODE يدوياً بعد كل أمر.
function Invoke-Native {
    param([Parameter(Mandatory = $true)][string]$Description, [Parameter(Mandatory = $true)][scriptblock]$Command)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "FAILED ($LASTEXITCODE): $Description"
    }
}

$MinMajor = 3
$MinMinor = 24

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  BS 8110 Solid Slab Designer — Release APK Builder (v1.0.0)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 0. التحقق من إصدار Flutter (flutter_lints ^5 يتطلب Dart 3.5 = Flutter 3.24+)
$verOut = (flutter --version 2>&1 | Out-String)
if ($verOut -match 'Flutter\s+(\d+)\.(\d+)') {
    $fMajor = [int]$Matches[1]
    $fMinor = [int]$Matches[2]
    if ($fMajor -lt $MinMajor -or ($fMajor -eq $MinMajor -and $fMinor -lt $MinMinor)) {
        throw "Flutter $fMajor.$fMinor detected; this project needs Flutter $MinMajor.$MinMinor or newer. Run: flutter upgrade"
    }
    Write-Host "[0/7] Flutter $fMajor.$fMinor OK (>= $MinMajor.$MinMinor)." -ForegroundColor Green
} else {
    throw "Could not detect Flutter version. Is 'flutter' on your PATH?"
}

# 1. Generate Android platform files matching local Flutter SDK if not present
if (-not (Test-Path "android")) {
    Write-Host "[1/7] Generating Android project scaffold..." -ForegroundColor Yellow
    Invoke-Native "flutter create" { flutter create --platforms=android --org com.bs8110.slabdesigner . }
} else {
    Write-Host "[1/7] Android directory already exists — skipping scaffold." -ForegroundColor Green
}

# 2. Apply clean offline AndroidManifest.xml and ProGuard rules
Write-Host "[2/7] Applying Offline AndroidManifest.xml & ProGuard rules..." -ForegroundColor Yellow
Copy-Item -Force "android_release_config/AndroidManifest.xml" "android/app/src/main/AndroidManifest.xml"
Copy-Item -Force "android_release_config/proguard-rules.pro" "android/app/proguard-rules.pro"

# 3. Fetch dependencies
Write-Host "[3/7] Fetching dependencies (flutter pub get)..." -ForegroundColor Yellow
Invoke-Native "flutter pub get" { flutter pub get }

# 4. Link proguard-rules.pro + release signing (key.properties) into android/app/build.gradle(.kts)
Write-Host "[4/7] Patching android/app/build.gradle (ProGuard link + release signing)..." -ForegroundColor Yellow
Invoke-Native "patch_android_gradle" { dart tool/patch_android_gradle.dart android }

# 5. Generate launcher icons & native splash screen
Write-Host "[5/7] Generating Launcher Icons & Native Splash Screen..." -ForegroundColor Yellow
Invoke-Native "flutter_launcher_icons" { dart run flutter_launcher_icons }
Invoke-Native "flutter_native_splash" { dart run flutter_native_splash:create }

# 6. Static analysis (errors only are fatal) & automated tests
Write-Host "[6/7] Running flutter analyze & flutter test..." -ForegroundColor Yellow
Invoke-Native "flutter analyze" { flutter analyze --no-fatal-infos --no-fatal-warnings }
if ($SkipTests) {
    Write-Host "      -SkipTests -> skipping flutter test." -ForegroundColor DarkYellow
} else {
    Invoke-Native "flutter test" { flutter test }
}

# 7. Build split-per-ABI release APKs
Write-Host "[7/7] Building Release APKs (--split-per-abi)..." -ForegroundColor Yellow
Invoke-Native "flutter build apk" { flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCEEDED! Output APKs:" -ForegroundColor Green
Get-ChildItem "build/app/outputs/flutter-apk/*.apk" | Select-Object Name, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB, 2)}} | Format-Table -AutoSize
Write-Host "============================================================" -ForegroundColor Green
if (Test-Path "android/key.properties") {
    Write-Host "Signed with YOUR release key (android/key.properties)." -ForegroundColor Cyan
} else {
    Write-Host "NOTE: signed with the DEBUG key (android/key.properties not found)." -ForegroundColor DarkYellow
    Write-Host "      Fine for personal install; create a release key before publishing (see RELEASE_GUIDE.md)." -ForegroundColor DarkYellow
}
Write-Host "Keep build/debug-info/ if you want to de-obfuscate crash stack traces later."
Write-Host "Install on modern Android phones using: app-arm64-v8a-release.apk" -ForegroundColor Cyan

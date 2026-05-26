# build_and_upload.ps1
# Script di automazione per KCALcolatore: Test, Build APK e Upload su Cloud

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   KCALcolatore Automation Pipeline 🚀   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Esecuzione dei Test
Write-Host "`n[1/3] Esecuzione dei Test Unitari... 🧪" -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Errore: I test unitari sono falliti! Risolvi gli errori prima di compilare." -ForegroundColor Red
    exit 1
}
Write-Host "✓ Tutti i test sono passati con successo!" -ForegroundColor Green

# 2. Compilazione dell'APK
Write-Host "`n[2/3] Compilazione Release APK... 📦 (Questo potrebbe richiedere alcuni minuti)" -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Errore: La compilazione dell'APK è fallita!" -ForegroundColor Red
    exit 1
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path $apkPath)) {
    Write-Host "❌ Errore: File APK non trovato a: $apkPath" -ForegroundColor Red
    exit 1
}
Write-Host "✓ APK compilato con successo!" -ForegroundColor Green

# 3. Caricamento Online (tramite transfer.sh)
Write-Host "`n[3/3] Caricamento dell'APK online... ☁️" -ForegroundColor Yellow
$fileName = "KCALcolatore-$(Get-Date -Format 'yyyyMMdd-HHmmss').apk"

try {
    # Utilizziamo Invoke-RestMethod per caricare il file su transfer.sh (hosting temporaneo gratuito e sicuro)
    $response = Invoke-RestMethod -Uri "https://transfer.sh/$fileName" -Method Put -InFile $apkPath -Headers @{"Max-Days"="7"}
    $cleanResponse = $response.Trim()
    
    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host "🎉 COMPILAZIONE E DISTRIBUZIONE COMPLETATE! 🎉" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "Scarica e installa l'applicazione direttamente sul tuo telefono:" -ForegroundColor White
    Write-Host "Link di Download: " -NoNewline -ForegroundColor White
    Write-Host $cleanResponse -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Green
    
    # Genera ed espone un link di QR Code istantaneo per inquadrare lo schermo col telefono!
    $qrLink = "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$( [Uri]::EscapeDataString($cleanResponse) )"
    Write-Host "Scansiona questo link per generare il QR Code di download:" -ForegroundColor White
    Write-Host $qrLink -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Green
} catch {
    Write-Host "❌ Errore durante il caricamento dell'APK online: $_" -ForegroundColor Red
    exit 1
}

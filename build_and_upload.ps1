# build_and_upload.ps1
# Script di automazione per KCALcolatore: Test, Build APK e Upload su Cloud

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   KCALcolatore Automation Pipeline       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Esecuzione dei Test
Write-Host "`n[1/3] Esecuzione dei Test Unitari... [TEST]" -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRORE] I test unitari sono falliti! Risolvi gli errori prima di compilare." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Tutti i test sono passati con successo!" -ForegroundColor Green

# 2. Compilazione dell'APK
Write-Host "`n[2/3] Compilazione Release APK... [BUILD] (Questo potrebbe richiedere alcuni minuti)" -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRORE] La compilazione dell'APK è fallita!" -ForegroundColor Red
    exit 1
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path $apkPath)) {
    Write-Host "[ERRORE] File APK non trovato a: $apkPath" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] APK compilato con successo!" -ForegroundColor Green

# 3. Caricamento Online (con fallbacks e supporto TLS 1.2)
Write-Host "`n[3/3] Caricamento dell'APK online... [UPLOAD]" -ForegroundColor Yellow
$fileName = "KCALcolatore-$(Get-Date -Format 'yyyyMMdd-HHmmss').apk"

# Forza TLS 1.2 per connessioni stabili in PowerShell su Windows
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Host "Nota: Impossibile impostare TLS 1.2 in modo nativo, proseguo con i default di sistema." -ForegroundColor Cyan
}

$uploaded = $false
$cleanResponse = ""

# Prova 1: transfer.sh
try {
    Write-Host "Tentativo di caricamento su transfer.sh..." -ForegroundColor White
    $response = Invoke-RestMethod -Uri "https://transfer.sh/$fileName" -Method Put -InFile $apkPath -Headers @{"Max-Days"="7"} -TimeoutSec 30
    $cleanResponse = $response.Trim()
    $uploaded = $true
} catch {
    Write-Host "Transfer.sh non raggiungibile. Tento il server di riserva..." -ForegroundColor Yellow
}

# Prova 2: bashupload.com (Fallback)
if (!$uploaded) {
    try {
        Write-Host "Tentativo di caricamento su bashupload.com..." -ForegroundColor White
        $response = Invoke-RestMethod -Uri "https://bashupload.com/$fileName" -Method Put -InFile $apkPath -TimeoutSec 30
        $rawResponse = $response.Trim()
        
        # Estraiamo il link https dalla risposta testuale di bashupload
        if ($rawResponse -match 'https://\S+') {
            $cleanResponse = $matches[0]
            $uploaded = $true
        }
    } catch {
        Write-Host "[ERRORE] Impossibile caricare il file online: $_" -ForegroundColor Red
        exit 1
    }
}

if ($uploaded) {
    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host "    COMPILAZIONE E DISTRIBUZIONE COMPLETATE!    " -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "Scarica e installa l'applicazione direttamente sul tuo telefono:" -ForegroundColor White
    Write-Host "Link di Download: " -NoNewline -ForegroundColor White
    Write-Host $cleanResponse -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Green
    
    # Genera ed espone un link di QR Code istantaneo per inquadrare lo schermo col telefono!
    $escapedData = [Uri]::EscapeDataString($cleanResponse)
    $qrLink = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=' + $escapedData
    
    Write-Host "Scansiona questo link per generare il QR Code di download:" -ForegroundColor White
    Write-Host $qrLink -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Host "[ERRORE] Il caricamento online è fallito su tutti i server di test." -ForegroundColor Red
    exit 1
}

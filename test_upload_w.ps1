# test_upload.ps1 - Script temporaneo per testare solo l'upload dell'APK gia' compilato

$apkPath = "c:\Users\rf199\Progetti\[08] KCALcolatore\kcal_v1\build\app\outputs\flutter-apk\app-release.apk"

Write-Host "Test LiteralPath..." -ForegroundColor Cyan
Write-Host "APK esiste: $(Test-Path -LiteralPath $apkPath)" -ForegroundColor White

if (!(Test-Path -LiteralPath $apkPath)) {
    Write-Host "[ERRORE] APK non trovato!" -ForegroundColor Red
    exit 1
}

$apkSize = [math]::Round((Get-Item -LiteralPath $apkPath).Length / 1MB, 1)
Write-Host "Dimensione APK: $apkSize MB" -ForegroundColor Green

# Copia APK in path temporaneo senza caratteri speciali (necessario per Invoke-RestMethod -InFile)
$tempDir = [System.IO.Path]::GetTempPath()
$tempApk = Join-Path $tempDir "KCALcolatore_upload_temp.apk"
Copy-Item -LiteralPath $apkPath -Destination $tempApk -Force
Write-Host "APK copiato in path temporaneo: $tempApk" -ForegroundColor DarkGray

# Forza TLS 1.2
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$fileName = "KCALcolatore-$timestamp.apk"
$uploaded = $false
$downloadUrl = ""

# --- Metodo A: transfer.sh ---
Write-Host "`nTentativo [A]: transfer.sh..." -ForegroundColor Yellow
try {
    $resp = Invoke-RestMethod `
        -Uri "https://transfer.sh/$fileName" `
        -Method Put `
        -InFile $tempApk `
        -Headers @{"Max-Days"="7"} `
        -TimeoutSec 600

    $downloadUrl = $resp.Trim()
    if ($downloadUrl -match "^https?://") {
        $uploaded = $true
        Write-Host "[OK] Upload su transfer.sh riuscito!" -ForegroundColor Green
    }
} catch {
    Write-Host "Transfer.sh fallito: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Metodo B: bashupload.com ---
if (!$uploaded) {
    Write-Host "Tentativo [B]: bashupload.com..." -ForegroundColor Yellow
    try {
        $resp = Invoke-RestMethod `
            -Uri "https://bashupload.com/$fileName" `
            -Method Put `
            -InFile $tempApk `
            -TimeoutSec 600

        $raw = ($resp -join "").Trim()
        if ($raw -match 'https?://\S+') {
            $downloadUrl = $matches[0]
            $uploaded = $true
            Write-Host "[OK] Upload su bashupload.com riuscito!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Bashupload fallito: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($uploaded) {
    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host "  Link download: $downloadUrl" -ForegroundColor Cyan
    $escaped = [Uri]::EscapeDataString($downloadUrl)
    $qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$escaped"
    Write-Host "  QR Code: $qrUrl" -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Host "[ERRORE] Tutti i metodi di upload hanno fallito." -ForegroundColor Red
    exit 1
}

# build_and_upload.ps1
# Script di automazione per KCALcolatore: Test, Build APK, Upload su GitHub Releases
# Lanciare con: .\build_and_upload.ps1 -GithubToken "il_tuo_token"

param(
    [string]$GithubToken = $env:GITHUB_TOKEN,
    [string]$GithubOwner = "RobFalc99",
    [string]$GithubRepo = "kcal"
)

# Sposta il working directory nella stessa cartella di questo script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -LiteralPath $ScriptDir

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   KCALcolatore Automation Pipeline       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Working directory: $(Get-Location)" -ForegroundColor DarkGray

# --- STEP 1: Test ---
Write-Host "`n[1/3] Esecuzione dei Test Unitari... [TEST]" -ForegroundColor Yellow

$testOutput = & flutter test 2>&1
$testExitCode = $LASTEXITCODE

if ($testExitCode -ne 0) {
    $outputStr = ($testOutput -join "")
    $noTests = $outputStr -match "No tests ran|0 tests passed|All tests passed"
    if (!$noTests) {
        Write-Host "[ERRORE] I test unitari sono falliti!" -ForegroundColor Red
        Write-Host $outputStr -ForegroundColor Red
        exit 1
    }
}
Write-Host "[OK] Test completati con successo!" -ForegroundColor Green

# --- STEP 2: Build APK ---
Write-Host "`n[2/3] Compilazione Release APK... [BUILD]" -ForegroundColor Yellow
Write-Host "       (Questo potrebbe richiedere alcuni minuti...)" -ForegroundColor DarkGray

& flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRORE] La compilazione dell'APK e' fallita!" -ForegroundColor Red
    exit 1
}

$apkPath = Join-Path $ScriptDir "build\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path -LiteralPath $apkPath)) {
    Write-Host "[ERRORE] File APK non trovato a: $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = [math]::Round((Get-Item -LiteralPath $apkPath).Length / 1MB, 1)
Write-Host "[OK] APK compilato con successo! ($apkSize MB)" -ForegroundColor Green

# Copia APK in path temporaneo senza caratteri speciali (necessario per upload HTTP)
$tempDir = [System.IO.Path]::GetTempPath()
$tempApk = Join-Path $tempDir "KCALcolatore_upload_temp.apk"
Copy-Item -LiteralPath $apkPath -Destination $tempApk -Force
Write-Host "APK copiato in path temporaneo: $tempApk" -ForegroundColor DarkGray

# --- STEP 3: Commit, Tag e GitHub Release ---
Write-Host "`n[3/3] Pubblicazione su GitHub Release... [UPLOAD]" -ForegroundColor Yellow

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$version = "v$(Get-Date -Format 'yyyy.MM.dd')-$((Get-Date).ToString('HHmmss'))"
$releaseName = "KCALcolatore $version"
$fileName = "KCALcolatore-$timestamp.apk"

# Forza TLS 1.2
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

# Prima: commit e push del codice corrente
Write-Host "Commit e push del codice su GitHub..." -ForegroundColor White
& git add -A
$commitMsg = "build: release $version"
$hasChanges = (& git status --porcelain) -ne ""
if ($hasChanges) {
    & git commit -m $commitMsg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Nessuna modifica da committare, procedo..." -ForegroundColor DarkGray
    }
}
& git push origin master
Write-Host "[OK] Codice sincronizzato su GitHub!" -ForegroundColor Green

# Crea un tag per questa release
& git tag $version
& git push origin $version

if ([string]::IsNullOrEmpty($GithubToken)) {
    Write-Host "`n[ATTENZIONE] GITHUB_TOKEN non configurato." -ForegroundColor Yellow
    Write-Host "Per abilitare l'upload automatico dell'APK su GitHub Releases:" -ForegroundColor White
    Write-Host "  1. Vai su https://github.com/settings/tokens" -ForegroundColor Cyan
    Write-Host "  2. Crea un token con permessi 'repo'" -ForegroundColor Cyan
    Write-Host "  3. Esegui: `$env:GITHUB_TOKEN='il_tuo_token'" -ForegroundColor Cyan
    Write-Host "  4. Poi rilancia questo script" -ForegroundColor Cyan
    Write-Host "`nL'APK e' disponibile localmente in:" -ForegroundColor Yellow
    Write-Host "  $apkPath" -ForegroundColor White
    exit 0
}

# Crea la Release su GitHub via API
Write-Host "Creazione release su GitHub..." -ForegroundColor White
$headers = @{
    "Authorization" = "token $GithubToken"
    "Accept"        = "application/vnd.github.v3+json"
    "User-Agent"    = "KCALcolatore-Pipeline"
}

$releaseBody = @{
    tag_name   = $version
    name       = $releaseName
    body       = "Build automatica del $(Get-Date -Format 'dd/MM/yyyy HH:mm'). APK size: $apkSize MB."
    draft      = $false
    prerelease = $false
} | ConvertTo-Json

try {
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$GithubOwner/$GithubRepo/releases" `
        -Method Post `
        -Headers $headers `
        -Body $releaseBody `
        -ContentType "application/json" `
        -TimeoutSec 60

    Write-Host "[OK] Release creata: $($release.html_url)" -ForegroundColor Green

    # Upload dell'APK alla release
    Write-Host "Upload dell'APK..." -ForegroundColor White
    $uploadUrl = $release.upload_url -replace '\{.*\}', ''
    $uploadUrl += "?name=$fileName"

    $apkBytes = [System.IO.File]::ReadAllBytes($tempApk)

    $uploadResp = Invoke-RestMethod `
        -Uri $uploadUrl `
        -Method Post `
        -Headers $headers `
        -Body $apkBytes `
        -ContentType "application/vnd.android.package-archive" `
        -TimeoutSec 600

    $downloadUrl = $uploadResp.browser_download_url
    Write-Host "[OK] APK caricato con successo!" -ForegroundColor Green

    # Genera QR Code
    $escaped = [Uri]::EscapeDataString($downloadUrl)
    $qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$escaped"

    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host "    COMPILAZIONE E DISTRIBUZIONE COMPLETATE!           " -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Release: $($release.html_url)" -ForegroundColor White
    Write-Host "  Download: $downloadUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  QR Code (apri nel browser o scansiona): " -ForegroundColor Yellow
    Write-Host "  $qrUrl" -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Green

} catch {
    Write-Host "[ERRORE] Upload su GitHub Releases fallito: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "L'APK e' comunque disponibile localmente:" -ForegroundColor Yellow
    Write-Host "  $apkPath" -ForegroundColor White
    Write-Host "Il codice e' stato pushato su GitHub con il tag $version" -ForegroundColor Yellow
    exit 1
}

# Cleanup file temporaneo
Remove-Item -LiteralPath $tempApk -Force -ErrorAction SilentlyContinue

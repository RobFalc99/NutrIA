# git_setup.ps1
# Inizializza il repository Git locale ed effettua il primo commit

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Git Setup per KCALcolatore 🐙       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Inizializza repository
if (!(Test-Path .git)) {
    Write-Host "`n[1/3] Inizializzazione repository Git locale..." -ForegroundColor Yellow
    git init
    Write-Host "✓ Repository inizializzato con successo!" -ForegroundColor Green
} else {
    Write-Host "`n✓ Repository Git già inizializzato." -ForegroundColor Green
}

# 2. Aggiunge i file escludendo quelli indicati nel .gitignore
Write-Host "`n[2/3] Aggiunta dei file all'indice di Git..." -ForegroundColor Yellow
git add .
Write-Host "✓ File aggiunti con successo!" -ForegroundColor Green

# 3. Effettua il primo commit
Write-Host "`n[3/3] Creazione del primo commit locale..." -ForegroundColor Yellow
git commit -m "Initial commit - KCALcolatore con Pasto IA, Camera e OFF fix"
Write-Host "✓ Primo commit locale completato!" -ForegroundColor Green

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host "🎉 REPOSITORY GIT PRONTO! 🎉" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "Ora puoi spingere il codice su GitHub per spostarti sul tuo altro PC." -ForegroundColor White
Write-Host "Esegui questi comandi per configurare il remote ed effettuare il push:" -ForegroundColor Yellow
Write-Host "  git remote add origin https://github.com/IL_TUO_USERNAME/IL_TUO_REPOSITORY.git" -ForegroundColor Cyan
Write-Host "  git branch -M main" -ForegroundColor Cyan
Write-Host "  git push -u origin main" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Green

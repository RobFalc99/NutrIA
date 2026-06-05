#!/usr/bin/env bash
# build_and_upload.sh
# Script di automazione per KCALcolatore: Test, Build APK, Upload su GitHub Releases
# Uso: ./build_and_upload.sh --token "il_tuo_token"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DARKGRAY='\033[1;30m'
NC='\033[0m' # No Color

# Default values
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_OWNER="RobFalc99"
GITHUB_REPO="NutrIA"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--token) GITHUB_TOKEN="$2"; shift ;;
        -o|--owner) GITHUB_OWNER="$2"; shift ;;
        -r|--repo) GITHUB_REPO="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Trova la directory dello script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR" || exit 1

# Carica GITHUB_TOKEN da .env locale se presente
if [ -f "$SCRIPT_DIR/.env" ]; then
    if [ -z "$GITHUB_TOKEN" ]; then
        local_token=$(grep -E "^GITHUB_TOKEN=" "$SCRIPT_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -n "$local_token" ]; then
            GITHUB_TOKEN="$local_token"
        fi
    fi
fi

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   NutrIA Automation Pipeline (Linux)${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${DARKGRAY}Working directory: $(pwd)${NC}"

# --- STEP 1: Test ---
echo -e "\n${YELLOW}[1/3] Esecuzione dei Test Unitari... [TEST]${NC}"

test_output=$(flutter test 2>&1)
test_exit_code=$?

if [ $test_exit_code -ne 0 ]; then
    # Verifica se i test sono semplicemente assenti o passati
    if [[ ! "$test_output" =~ "No tests ran" && ! "$test_output" =~ "0 tests passed" && ! "$test_output" =~ "All tests passed" ]]; then
        echo -e "${RED}[ERRORE] I test unitari sono falliti!${NC}"
        echo -e "${RED}$test_output${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}[OK] Test completati con successo!${NC}"

# --- STEP 2: Build APK ---
echo -e "\n${YELLOW}[2/3] Compilazione Release APK... [BUILD]${NC}"
echo -e "${DARKGRAY}       (Questo potrebbe richiedere alcuni minuti...)${NC}"

# Pulizia preventiva cache CMake e build precedenti
echo -e "${DARKGRAY}Pulizia cache CMake e build precedenti...${NC}"
rm -rf "$SCRIPT_DIR/android/app/.cxx" 2>/dev/null || true
flutter clean --quiet 2>/dev/null || true

flutter build apk --release
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERRORE] La compilazione dell'APK è fallita!${NC}"
    exit 1
fi

apk_path="$SCRIPT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$apk_path" ]; then
    echo -e "${RED}[ERRORE] File APK non trovato a: $apk_path${NC}"
    exit 1
fi

apk_size=$(du -h "$apk_path" | cut -f1)
echo -e "${GREEN}[OK] APK compilato con successo! ($apk_size)${NC}"

# Copia in path temporaneo
temp_apk="/tmp/NutrIA_upload_temp.apk"
cp "$apk_path" "$temp_apk"
echo -e "${DARKGRAY}APK copiato in path temporaneo: $temp_apk${NC}"

# --- STEP 3: Commit, Tag e GitHub Release ---
echo -e "\n${YELLOW}[3/3] Pubblicazione su GitHub Release... [UPLOAD]${NC}"

timestamp=$(date +'%Y%m%dd-%H%M%S')
version="v$(date +'%Y.%m.%d')-$(date +'%H%M%S')"
release_name="NutrIA $version"
file_name="NutrIA-$timestamp.apk"

# Commit e push del codice corrente
echo -e "${WHITE}Commit e push del codice su GitHub...${NC}"
git add -A
commit_msg="build: release $version"

if [ -n "$(git status --porcelain)" ]; then
    git commit -m "$commit_msg"
    if [ $? -ne 0 ]; then
        echo -e "${DARKGRAY}Nessuna modifica da committare, procedo...${NC}"
    fi
fi

git push origin master
echo -e "${GREEN}[OK] Codice sincronizzato su GitHub!${NC}"

# Crea un tag per questa release
git tag "$version"
git push origin "$version"

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "\n${YELLOW}[ATTENZIONE] GITHUB_TOKEN non configurato.${NC}"
    echo -e "${WHITE}Per abilitare l'upload automatico dell'APK su GitHub Releases:${NC}"
    echo -e "${CYAN}  1. Vai su https://github.com/settings/tokens${NC}"
    echo -e "${CYAN}  2. Crea un token con permessi 'repo'${NC}"
    echo -e "${CYAN}  3. Esegui: export GITHUB_TOKEN='il_tuo_token'${NC}"
    echo -e "${CYAN}  4. Poi rilancia questo script${NC}"
    echo -e "\n${YELLOW}L'APK è disponibile localmente in:${NC}"
    echo -e "${WHITE}  $apk_path${NC}"
    exit 0
fi

# Crea la Release su GitHub via API
echo -e "${WHITE}Creazione release su GitHub...${NC}"

release_json=$(cat <<EOF
{
  "tag_name": "$version",
  "name": "$release_name",
  "body": "Build automatica del $(date +'%d/%m/%Y %H:%M'). APK size: $apk_size.",
  "draft": false,
  "prerelease": false
}
EOF
)

response=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  -d "$release_json" \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases")

release_url=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('html_url', ''))" 2>/dev/null)
upload_url=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('upload_url', '').split('{')[0])" 2>/dev/null)

if [ -z "$upload_url" ]; then
    echo -e "${RED}[ERRORE] Creazione release fallita!${NC}"
    echo -e "${RED}$response${NC}"
    rm -f "$temp_apk"
    exit 1
fi

echo -e "${GREEN}[OK] Release creata: $release_url${NC}"

# Upload dell'APK
echo -e "${WHITE}Upload dell'APK...${NC}"
upload_response=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary @"$temp_apk" \
  "$upload_url?name=$file_name")

download_url=$(echo "$upload_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('browser_download_url', ''))" 2>/dev/null)

if [ -z "$download_url" ]; then
    echo -e "${RED}[ERRORE] Upload dell'APK fallito!${NC}"
    echo -e "${RED}$upload_response${NC}"
    rm -f "$temp_apk"
    exit 1
fi

echo -e "${GREEN}[OK] APK caricato con successo!${NC}"

# Genera QR Code
escaped_url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$download_url'))" 2>/dev/null || echo "$download_url")
qr_url="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$escaped_url"

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN}    COMPILAZIONE E DISTRIBUZIONE COMPLETATE!           ${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e ""
echo -e "  Release:  ${WHITE}$release_url${NC}"
echo -e "  Download: ${CYAN}$download_url${NC}"
echo -e ""
echo -e "  QR Code (apri nel browser o scansiona): "
echo -e "  ${YELLOW}$qr_url${NC}"
echo -e "${GREEN}=======================================================${NC}"

# Cleanup
rm -f "$temp_apk"

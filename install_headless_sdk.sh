#!/usr/bin/env bash
# install_headless_sdk.sh
# Script per installare l'Android SDK in modalità Headless (senza GUI) e rimuovere Android Studio su Ubuntu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}      Setup Android SDK Headless (KCALcolatore)        ${NC}"
echo -e "${CYAN}=======================================================${NC}"

# 1. Rimuove Android Studio via Snap se presente
if snap list | grep -q android-studio; then
    echo -e "\n${YELLOW}[1/6] Rimozione di Android Studio (Snap)...${NC}"
    sudo snap remove android-studio
    echo -e "${GREEN}[OK] Android Studio rimosso con successo!${NC}"
else
    echo -e "\n${DARKGRAY}[1/6] Android Studio via Snap non installato, salto questo passaggio.${NC}"
fi

# 2. Verifica/Installa Java OpenJDK 17
echo -e "\n${YELLOW}[2/6] Verifica dell'installazione di Java (OpenJDK 17)...${NC}"
if ! java -version &>/dev/null; then
    echo -e "${YELLOW}Java non trovato. Installazione in corso...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y openjdk-17-jdk unzip wget
else
    echo -e "${GREEN}[OK] Java è già installato!${NC}"
    java -version
fi

# 3. Setup Cartelle e Download Command Line Tools di Android
echo -e "\n${YELLOW}[3/6] Download e configurazione dei Command Line Tools di Android...${NC}"
SDK_DIR="$HOME/Android/Sdk"
mkdir -p "$SDK_DIR/cmdline-tools"

# Scarica l'ultima versione dei tools stabili per Linux
TOOLS_ZIP="/tmp/cmdline-tools.zip"
URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

echo -e "Scaricamento in corso da Google..."
wget -q --show-progress -O "$TOOLS_ZIP" "$URL"

echo -e "Estrazione dell'archivio..."
# Rimuove versioni precedenti di 'latest' se esistono per evitare sovrapposizioni sporche
rm -rf "$SDK_DIR/cmdline-tools/latest"
mkdir -p /tmp/android-sdk-extracted

unzip -q "$TOOLS_ZIP" -d /tmp/android-sdk-extracted
mv /tmp/android-sdk-extracted/cmdline-tools "$SDK_DIR/cmdline-tools/latest"

# Cleanup file temporanei
rm -rf /tmp/android-sdk-extracted
rm -f "$TOOLS_ZIP"

echo -e "${GREEN}[OK] Command Line Tools configurati correttamente!${NC}"

# 4. Configurazione Variabili d'Ambiente in ~/.bashrc
echo -e "\n${YELLOW}[4/6] Configurazione delle variabili d'ambiente in ~/.bashrc...${NC}"
BASHRC="$HOME/.bashrc"

if ! grep -q "ANDROID_HOME" "$BASHRC"; then
    echo -e "Aggiunta delle configurazioni a $BASHRC..."
    echo -e "\n# Android SDK Configuration" >> "$BASHRC"
    echo -e "export ANDROID_HOME=\$HOME/Android/Sdk" >> "$BASHRC"
    echo -e "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools" >> "$BASHRC"
    echo -e "${GREEN}[OK] Variabili aggiunte a ~/.bashrc!${NC}"
else
    echo -e "${GREEN}[OK] Le variabili d'ambiente sono già presenti in ~/.bashrc!${NC}"
fi

# Applica le variabili alla sessione dello script corrente
export ANDROID_HOME="$SDK_DIR"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

# 5. Installazione SDK Components (Platforms, Build Tools, Platform Tools)
echo -e "\n${YELLOW}[5/6] Installazione di platform-tools, platforms;android-34 e build-tools...${NC}"
# Accetta licenze in modo automatico per l'installazione iniziale dei pacchetti
yes | "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null
"$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK] Componenti SDK installati con successo!${NC}"
else
    echo -e "${RED}[ERRORE] Installazione SDK fallita.${NC}"
    exit 1
fi

# 6. Configurazione Flutter e Accettazione Licenze
echo -e "\n${YELLOW}[6/6] Collegamento dell'SDK a Flutter e firma licenze...${NC}"
flutter config --android-sdk "$SDK_DIR"

echo -e "Avvio dell'accettazione delle licenze di Flutter (premi 'y' e Invio per ciascuna licenza)..."
flutter doctor --android-licenses

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN}      CONFIGURAZIONE HEADLESS COMPLETATA CON SUCCESSO! ${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\nPer completare l'applicazione delle variabili nella tua sessione corrente, esegui:"
echo -e "     ${CYAN}source ~/.bashrc${NC}"
echo -e "\nSuccessivamente, potrai avviare tranquillamente la pipeline di build:"
echo -e "     ${GREEN}./build_and_upload.sh --token \"IL_TUO_TOKEN\"${NC}"
echo -e "${GREEN}=======================================================${NC}"

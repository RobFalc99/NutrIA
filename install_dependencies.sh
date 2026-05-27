#!/usr/bin/env bash
# install_dependencies.sh
# Script di installazione automatizzata di Flutter, Java e Android SDK per Ubuntu 24.04

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}   Installazione Dipendenze di Sviluppo KCALcolatore   ${NC}"
echo -e "${CYAN}=======================================================${NC}"
echo -e "Questo script installerà Java JDK, Flutter e Android Studio su Ubuntu."
echo -e "Richiede l'utilizzo dei privilegi di amministratore (sudo).\n"

# 1. Aggiorna i pacchetti apt
echo -e "${YELLOW}[1/4] Aggiornamento dei repository di sistema...${NC}"
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa pkg-config clang cmake ninja-build libgtk-3-dev liblzma-dev

# 2. Installa Java JDK 17 (necessario per Android / Gradle)
echo -e "\n${YELLOW}[2/4] Installazione di OpenJDK 17...${NC}"
sudo apt-get install -y openjdk-17-jdk
if java -version &>/dev/null; then
    echo -e "${GREEN}[OK] Java installato correttamente!${NC}"
    java -version
else
    echo -e "${RED}[ERRORE] Impossibile installare Java.${NC}"
fi

# 3. Installa Flutter via Snap
echo -e "\n${YELLOW}[3/4] Installazione di Flutter tramite Snap...${NC}"
sudo snap install flutter --classic
if which flutter &>/dev/null; then
    echo -e "${GREEN}[OK] Flutter installato con successo!${NC}"
    flutter --version
else
    # Se snap non ha aggiornato subito il path per la sessione corrente, aggiungiamo il path di fallback
    export PATH="$PATH:/snap/bin"
    if /snap/bin/flutter --version &>/dev/null; then
        echo -e "${GREEN}[OK] Flutter installato in /snap/bin!${NC}"
    else
        echo -e "${RED}[ERRORE] Installazione di Flutter fallita.${NC}"
    fi
fi

# 4. Installa Android Studio via Snap (Metodo consigliato e più robusto per SDK e Licenze)
echo -e "\n${YELLOW}[4/4] Installazione di Android Studio tramite Snap...${NC}"
echo -e "Android Studio installerà automaticamente l'SDK Android e configurerà i driver necessari."
sudo snap install android-studio --classic

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN}          INSTALLAZIONE COMPLETATA CON SUCCESSO!       ${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\nPer completare la configurazione dell'ambiente, segui questi ultimi passi manuali:"
echo -e "${WHITE}1. Avvia Android Studio dal tuo menu delle applicazioni.${NC}"
echo -e "   - Completa la procedura guidata iniziale (Setup Wizard) che scaricherà l'SDK Android automaticamente."
echo -e "${WHITE}2. Configura il percorso dell'SDK in Flutter:${NC}"
echo -e "   - Esegui nel terminale:"
echo -e "     ${CYAN}flutter config --android-sdk ~/Android/Sdk${NC}"
echo -e "${WHITE}3. Accetta le licenze Android (fondamentale per compilare gli APK):${NC}"
echo -e "   - Esegui nel terminale:"
echo -e "     ${CYAN}flutter doctor --android-licenses${NC}"
echo -e "${WHITE}4. Riavvia il terminale o esegui:${NC}"
echo -e "     ${CYAN}source ~/.bashrc${NC}"
echo -e "\nDopo questi passaggi potrai lanciare il tuo deploy Linux con successo:"
echo -e "   ${GREEN}./build_and_upload.sh --token \"IL_TUO_TOKEN\"${NC}"
echo -e "${GREEN}=======================================================${NC}"

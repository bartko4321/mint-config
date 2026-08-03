#!/bin/bash

# Kolory
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================
# WYKRYWANIE JĘZYKA / LANGUAGE DETECTION
# ============================================================
detect_lang() {
    local l="${LANG:-}${LANGUAGE:-}${LC_ALL:-}"
    case "$l" in
        pl_PL*|*pl_PL*|pl*) echo "pl" ;;
        *) echo "en" ;;
    esac
}
LANGCODE=$(detect_lang)

# t <key> -> zwraca przetłumaczony komunikat (bez kolorów)
t() {
    local key="$1"
    if [ "$LANGCODE" = "pl" ]; then
        case "$key" in
            title1) echo "=====================================================" ;;
            title2) echo "  KOMPLEKSOWY SKRYPT AKTUALIZACJI I CZYSZCZENIA       " ;;
            title3) echo "          LINUX MINT (CINNAMON)                      " ;;
            ask_password) echo "Proszę podać hasło administratora (sudo):" ;;
            apt_update) echo "==> Pełna aktualizacja systemu (APT)..." ;;
            mintupdate) echo "==> Sprawdzanie aktualizacji przez mintupdate-cli..." ;;
            flatpak_update) echo "==> Pełna aktualizacja aplikacji Flatpak..." ;;
            firmware_section) echo "==> Aktualizacja firmware (fwupd)..." ;;
            firmware_refresh) echo "==> Odświeżanie bazy metadanych firmware..." ;;
            firmware_check) echo "==> Sprawdzanie dostępnych aktualizacji firmware..." ;;
            firmware_apply) echo "==> Instalowanie dostępnych aktualizacji firmware..." ;;
            firmware_reboot) echo "UWAGA: Niektóre aktualizacje firmware wymagają ponownego uruchomienia komputera!" ;;
            firmware_absent) echo "==> fwupd nieobecny - pomijam aktualizację firmware." ;;
            phase1) echo "--- FAZA 1: SYSTEM (SUDO) ---" ;;
            autoremove) echo "==> Usuwanie osieroconych pakietów i zbędnych zależności..." ;;
            deborphan) echo "==> Usuwanie osieroconych bibliotek (deborphan)..." ;;
            apt_keys) echo "==> Aktualizacja bazy kluczy zaufanych..." ;;
            apt_clean) echo "==> Czyszczenie cache pobierania APT (stare pakiety)..." ;;
            ppa_clean) echo "==> Usuwanie nieużywanych repozytoriów (PPA/listy)..." ;;
            flatpak_clean_system) echo "==> Kompleksowe czyszczenie Flatpak (System)..." ;;
            flatpak_remote_removed) echo "Usuwanie nieużywanego źródła Flatpak:" ;;
            flatpak_orphan_system) echo "==> Czyszczenie osieroconych danych po usuniętych aplikacjach w /var/app..." ;;
            flatpak_orphan_removed_system) echo "Usuwanie osieroconych danych systemowych w /var/app:" ;;
            flatpak_absent) echo "==> Flatpak nieobecny - pomijam czyszczenie systemowe." ;;
            journal_clean) echo "==> Czyszczenie logów (Journalctl + /var/log)..." ;;
            tmp_clean) echo "==> Czyszczenie starego /tmp i /var/tmp (starsze niż 3 dni)..." ;;
            kernel_clean) echo "==> Usuwanie starych kerneli (mintsystem / dpkg)..." ;;
            kernel_removing) echo "Usuwanie:" ;;
            kernel_current_only) echo "Tylko aktualny kernel w systemie." ;;
            grub_update) echo "==> Aktualizacja GRUB po zmianach kerneli..." ;;
            phase2) echo "--- FAZA 2: UŻYTKOWNIK (REAL USER) ---" ;;
            cache_clean) echo "==> Czyszczenie starego cache (omijanie przeglądarek)..." ;;
            thumbnails_clean) echo "==> Czyszczenie starych miniatur (Nemo)..." ;;
            cinnamon_nemo_clean) echo "==> Czyszczenie cache Cinnamon i Nemo..." ;;
            flatpak_user_clean) echo "==> Czyszczenie Flatpak (Użytkownik)..." ;;
            flatpak_orphan_user) echo "==> Czyszczenie osieroconych danych po usuniętych aplikacjach w ~/.var/app..." ;;
            flatpak_orphan_removed_user) echo "Usuwanie osieroconych danych użytkownika w ~/.var/app:" ;;
            fontcache) echo "==> Odświeżanie cache czcionek..." ;;
            virtmanager_clean) echo "==> Czyszczenie virt-manager i reset dconf..." ;;
            dconf_done) echo "==> dconf reset wykonany." ;;
            nemo_restart) echo "==> Restart Nemo (zastosowanie czyszczenia cache)..." ;;
            done_title) echo "     AKTUALIZACJA I CZYSZCZENIE ZAKOŃCZONE!          " ;;
            checking_state) echo "==> Sprawdzanie stanu systemu..." ;;
            reboot_warn) echo " UWAGA: Zainstalowano nowy kernel lub ważne pakiety!  " ;;
            reboot_recommend) echo " ZALECANY JEST RESTART KOMPUTERA!                     " ;;
            reboot_not_required) echo "==> Restart systemu nie jest aktualnie wymagany." ;;
            press_enter) echo "Naciśnij [ENTER], aby zakończyć..." ;;
        esac
    else
        case "$key" in
            title1) echo "=====================================================" ;;
            title2) echo "  COMPREHENSIVE UPDATE AND CLEANUP SCRIPT             " ;;
            title3) echo "          LINUX MINT (CINNAMON)                      " ;;
            ask_password) echo "Please enter your administrator (sudo) password:" ;;
            apt_update) echo "==> Full system update (APT)..." ;;
            mintupdate) echo "==> Checking for updates via mintupdate-cli..." ;;
            flatpak_update) echo "==> Full Flatpak application update..." ;;
            firmware_section) echo "==> Firmware update (fwupd)..." ;;
            firmware_refresh) echo "==> Refreshing firmware metadata..." ;;
            firmware_check) echo "==> Checking for available firmware updates..." ;;
            firmware_apply) echo "==> Installing available firmware updates..." ;;
            firmware_reboot) echo "NOTE: Some firmware updates require a system reboot!" ;;
            firmware_absent) echo "==> fwupd not found - skipping firmware update." ;;
            phase1) echo "--- PHASE 1: SYSTEM (SUDO) ---" ;;
            autoremove) echo "==> Removing orphaned packages and unnecessary dependencies..." ;;
            deborphan) echo "==> Removing orphaned libraries (deborphan)..." ;;
            apt_keys) echo "==> Updating trusted keys database..." ;;
            apt_clean) echo "==> Cleaning APT download cache (old packages)..." ;;
            ppa_clean) echo "==> Removing unused repositories (PPA/lists)..." ;;
            flatpak_clean_system) echo "==> Comprehensive Flatpak cleanup (System)..." ;;
            flatpak_remote_removed) echo "Removing unused Flatpak remote:" ;;
            flatpak_orphan_system) echo "==> Cleaning orphaned data from removed apps in /var/app..." ;;
            flatpak_orphan_removed_system) echo "Removing orphaned system data in /var/app:" ;;
            flatpak_absent) echo "==> Flatpak not found - skipping system cleanup." ;;
            journal_clean) echo "==> Cleaning logs (Journalctl + /var/log)..." ;;
            tmp_clean) echo "==> Cleaning old /tmp and /var/tmp (older than 3 days)..." ;;
            kernel_clean) echo "==> Removing old kernels (mintsystem / dpkg)..." ;;
            kernel_removing) echo "Removing:" ;;
            kernel_current_only) echo "Only the current kernel is installed." ;;
            grub_update) echo "==> Updating GRUB after kernel changes..." ;;
            phase2) echo "--- PHASE 2: USER (REAL USER) ---" ;;
            cache_clean) echo "==> Cleaning old cache (excluding browsers)..." ;;
            thumbnails_clean) echo "==> Cleaning old thumbnails (Nemo)..." ;;
            cinnamon_nemo_clean) echo "==> Cleaning Cinnamon and Nemo cache..." ;;
            flatpak_user_clean) echo "==> Cleaning Flatpak (User)..." ;;
            flatpak_orphan_user) echo "==> Cleaning orphaned data from removed apps in ~/.var/app..." ;;
            flatpak_orphan_removed_user) echo "Removing orphaned user data in ~/.var/app:" ;;
            fontcache) echo "==> Refreshing font cache..." ;;
            virtmanager_clean) echo "==> Cleaning virt-manager and resetting dconf..." ;;
            dconf_done) echo "==> dconf reset completed." ;;
            nemo_restart) echo "==> Restarting Nemo (applying cache cleanup)..." ;;
            done_title) echo "     UPDATE AND CLEANUP COMPLETE!                    " ;;
            checking_state) echo "==> Checking system state..." ;;
            reboot_warn) echo " WARNING: A new kernel or important packages were installed! " ;;
            reboot_recommend) echo " A SYSTEM REBOOT IS RECOMMENDED!                      " ;;
            reboot_not_required) echo "==> A system reboot is not currently required." ;;
            press_enter) echo "Press [ENTER] to finish..." ;;
        esac
    fi
}

echo -e "${BLUE}$(t title1)${NC}"
echo -e "${BLUE}$(t title2)${NC}"
echo -e "${BLUE}$(t title3)${NC}"
echo -e "${BLUE}$(t title1)${NC}"

# 1. ZAPYTANIE O HASŁO TYLKO RAZ
echo -e "${YELLOW}$(t ask_password)${NC}"
sudo -v

# Podtrzymanie sudo
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEP_ALIVE_PID=$!

echo -e "\n${GREEN}$(t apt_update)${NC}"

# Używamy apt-get (stabilne dla skryptów) + ukrywamy irytujące komunikaty o i386
sudo apt-get update 2>&1 | grep -v "nie obsługuje architektury\|Pomijanie pozyskania skonfigurowanego pliku"

# Kontynuacja pełnej aktualizacji (dist-upgrade to odpowiednik full-upgrade w apt-get)
sudo apt-get dist-upgrade -y

# Aktualizacja przez narzędzie Mintupdate (jeśli dostępne w wersji CLI)
if command -v mintupdate-cli &> /dev/null; then
    echo -e "\n${GREEN}$(t mintupdate)${NC}"
    sudo mintupdate-cli upgrade -y 2>/dev/null
fi

# Aktualizacja Flatpak (w Mint dostępny domyślnie z Mintinstall)
if command -v flatpak &> /dev/null; then
    echo -e "\n${GREEN}$(t flatpak_update)${NC}"
    flatpak update -y
fi

# Aktualizacja firmware (fwupd)
if command -v fwupdmgr &> /dev/null; then
    echo -e "\n${GREEN}$(t firmware_section)${NC}"
    echo -e "${GREEN}$(t firmware_refresh)${NC}"
    sudo fwupdmgr refresh --force 2>/dev/null
    echo -e "${GREEN}$(t firmware_check)${NC}"
    sudo fwupdmgr get-updates 2>/dev/null
    echo -e "${GREEN}$(t firmware_apply)${NC}"
    sudo fwupdmgr update -y 2>/dev/null
    echo -e "${YELLOW}$(t firmware_reboot)${NC}"
else
    echo -e "\n${YELLOW}$(t firmware_absent)${NC}"
fi

echo -e "\n${BLUE}$(t phase1)${NC}"

echo -e "${GREEN}$(t autoremove)${NC}"
sudo apt-get autoremove --purge -y

# Deborphan
if command -v deborphan &> /dev/null; then
    echo -e "${GREEN}$(t deborphan)${NC}"
    sudo apt-get purge $(deborphan) -y 2>/dev/null
fi

# Aktualizacja kluczy APT
echo -e "${GREEN}$(t apt_keys)${NC}"
sudo apt-key net-update 2>/dev/null

echo -e "${GREEN}$(t apt_clean)${NC}"
sudo apt-get autoclean

echo -e "${GREEN}$(t ppa_clean)${NC}"
sudo find /etc/apt/sources.list.d/ -type f -name "*.save" -delete

# Kompleksowe czyszczenie Flatpak (System)
if command -v flatpak &> /dev/null; then
    echo -e "${GREEN}$(t flatpak_clean_system)${NC}"
    sudo flatpak uninstall --unused --system -y
    sudo flatpak uninstall --unused --delete-data -y 2>/dev/null
    sudo flatpak repair --system

    # Usuwanie nieużywanych repozytoriów (remotes)
    USED_REMOTES=$(flatpak list --columns=origin 2>/dev/null | sort -u)
    ALL_REMOTES=$(flatpak remotes --columns=name 2>/dev/null)

    while IFS= read -r remote; do
        if [ -n "$remote" ] && ! echo "$USED_REMOTES" | grep -qx "$remote"; then
            echo -e "${YELLOW}$(t flatpak_remote_removed) $remote${NC}"
            sudo flatpak remote-delete --force "$remote" 2>/dev/null
        fi
    done <<< "$ALL_REMOTES"

    # Czyszczenie plików tymczasowych i historii Flatpak
    sudo rm -rf /var/tmp/flatpak-cache-* 2>/dev/null
    sudo find /var/lib/flatpak -name "*.tmp" -delete 2>/dev/null
    sudo rm -f /var/lib/flatpak/history 2>/dev/null

    # INTELIGENTNE CZYSZCZENIE /var/app (tylko osierocone dane)
    echo -e "${GREEN}$(t flatpak_orphan_system)${NC}"
    INSTALLED_FLATPAKS=$(flatpak list --app --columns=application 2>/dev/null)
    if [ -d "/var/app" ]; then
        for app_dir in /var/app/*; do
            if [ -d "$app_dir" ]; then
                app_id=$(basename "$app_dir")
                if ! echo "$INSTALLED_FLATPAKS" | grep -qx "$app_id"; then
                    echo -e "${YELLOW}$(t flatpak_orphan_removed_system) $app_id${NC}"
                    sudo rm -rf "$app_dir"
                fi
            fi
        done
    fi
else
    echo -e "${YELLOW}$(t flatpak_absent)${NC}"
fi

echo -e "${GREEN}$(t journal_clean)${NC}"
sudo journalctl --vacuum-time=7d
sudo find /var/log -type f -name "*.gz" -mtime +7 -delete
sudo find /var/log -type f -name "*.1" -delete

echo -e "${GREEN}$(t tmp_clean)${NC}"
sudo find /tmp -type f -atime +3 -delete 2>/dev/null
sudo find /var/tmp -type f -atime +3 -delete 2>/dev/null

echo -e "${GREEN}$(t kernel_clean)${NC}"
if command -v mintsystem &> /dev/null; then
    # Wbudowane, bezpieczne narzędzie Mint do usuwania starych kerneli
    sudo mintsystem removekernels 2>/dev/null
else
    CURRENT_KERNEL=$(uname -r)
    KERNEL_PACKAGES=$(dpkg -l | grep -E 'linux-image-[0-9]' | awk '{print $2}' | grep -v "$CURRENT_KERNEL")
    if [ -n "$KERNEL_PACKAGES" ]; then
        echo "$(t kernel_removing) $KERNEL_PACKAGES"
        sudo apt-get purge $KERNEL_PACKAGES -y
    else
        echo "$(t kernel_current_only)"
    fi
fi

echo -e "${GREEN}$(t grub_update)${NC}"
sudo update-grub 2>/dev/null

echo -e "\n${BLUE}$(t phase2)${NC}"

echo -e "${GREEN}$(t cache_clean)${NC}"
find ~/.cache -type f -atime +14 \
    ! -path "*/mozilla/*" \
    ! -path "*/google-chrome/*" \
    ! -path "*/chromium/*" \
    ! -path "*/BraveSoftware/*" \
    ! -path "*/opera/*" \
    -delete 2>/dev/null

echo -e "${GREEN}$(t thumbnails_clean)${NC}"
find ~/.cache/thumbnails -type f -atime +7 -delete 2>/dev/null

echo -e "${GREEN}$(t cinnamon_nemo_clean)${NC}"
rm -rf ~/.cache/cinnamon/* 2>/dev/null
rm -rf ~/.cache/nemo/* 2>/dev/null
rm -rf ~/.local/share/cinnamon/spices-cache/* 2>/dev/null

if command -v flatpak &> /dev/null; then
    echo -e "${GREEN}$(t flatpak_user_clean)${NC}"
    flatpak uninstall --unused --user -y
    flatpak uninstall --unused --delete-data -y 2>/dev/null || flatpak uninstall --delete-data -y 2>/dev/null
    rm -rf ~/.local/share/flatpak/repo/tmp/* 2>/dev/null
    rm -f ~/.local/share/flatpak/history 2>/dev/null

    # INTELIGENTNE CZYSZCZENIE ~/.var/app (tylko osierocone dane)
    echo -e "${GREEN}$(t flatpak_orphan_user)${NC}"
    INSTALLED_FLATPAKS=$(flatpak list --app --columns=application 2>/dev/null)
    if [ -d "$HOME/.var/app" ]; then
        for app_dir in "$HOME/.var/app"/*; do
            if [ -d "$app_dir" ]; then
                app_id=$(basename "$app_dir")
                if ! echo "$INSTALLED_FLATPAKS" | grep -qx "$app_id"; then
                    echo -e "${YELLOW}$(t flatpak_orphan_removed_user) $app_id${NC}"
                    rm -rf "$app_dir"
                fi
            fi
        done
    fi
fi

echo -e "${GREEN}$(t fontcache)${NC}"
fc-cache -fv

echo -e "${GREEN}$(t virtmanager_clean)${NC}"
USER_ID=$(id -u)
if [ -S "/run/user/$USER_ID/bus" ]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" dconf reset /org/virt-manager/virt-manager/urls/isos 2>/dev/null
    echo -e "${GREEN}$(t dconf_done)${NC}"
fi
rm -rf "$HOME/.cache/virt-manager" 2>/dev/null

echo -e "${GREEN}$(t nemo_restart)${NC}"
nemo -q 2>/dev/null

# Zakończenie
kill $SUDO_KEEP_ALIVE_PID 2>/dev/null
echo -e "\n${BLUE}$(t title1)${NC}"
echo -e "${GREEN}$(t done_title)${NC}"
echo -e "${BLUE}$(t title1)${NC}"

# Sprawdzanie konieczności restartu (np. po aktualizacji kernela)
echo -e "\n${GREEN}$(t checking_state)${NC}"
if [ -f /var/run/reboot-required ]; then
    echo -e "\n${RED}******************************************************${NC}"
    echo -e "${RED}$(t reboot_warn)${NC}"
    echo -e "${YELLOW}$(t reboot_recommend)${NC}"
    echo -e "${RED}******************************************************${NC}\n"
else
    echo -e "${GREEN}$(t reboot_not_required)${NC}"
fi

echo -e "$(t press_enter)"
read -r

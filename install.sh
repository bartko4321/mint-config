#!/bin/bash
# ==========================================================
# KOMPLEKSOWY SKRYPT KONFIGURACYJNY SYSTEMU (CINNAMON + LINUX MINT)
# ==========================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Kolory i logowanie ---
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${INFO}==> $*${NC}"; }
log_ok()   { echo -e "${SUCCESS}✔ $*${NC}"; }
log_err()  { echo -e "${ERROR}✖ BŁĄD: $*${NC}" >&2; }
log_warn() { echo -e "${WARN}⚠ UWAGA: $*${NC}"; }

trap 'log_err "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND"' ERR

# --- Zmienna lokalizująca folder ze skryptem (niezależnie skąd jest uruchamiany) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# --- Odporne "apt-get update" ---
# Jeśli w /etc/apt/sources.list.d/ zostały martwe wpisy PPA (np. po
# przerwanym wcześniejszym uruchomieniu tego skryptu, albo PPA które nie ma
# jeszcze wydania dla bieżącego OS_CODENAME), zwykłe "apt-get update"
# zwraca błąd i - przez set -e/trap - ubija cały skrypt, mimo że reszta
# repozytoriów (główne Mint/Ubuntu itd.) zaktualizowała się poprawnie.
# Ta funkcja: próbuje update, a jeśli się nie powiedzie - wyłuskuje z komunikatów
# błędów adresy zepsutych repozytoriów, usuwa odpowiadające im pliki .list/.sources
# i ponawia update.
safe_apt_update() {
    local out rc
    set +e
    out=$(sudo apt-get update -yq 2>&1)
    rc=$?
    set -e
    echo "$out"
    [[ $rc -eq 0 ]] && return 0

    log_warn "apt-get update napotkało błędy — próbuję zidentyfikować i usunąć zepsute repozytoria..."
    local broken_urls
    broken_urls=$(echo "$out" | grep -oP '(?:Błąd|Err):[0-9]+ \Khttps?://\S+' | sort -u)
    local removed=0
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        local host_path="${url#http://}"
        host_path="${host_path#https://}"
        for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
            [[ -f "$f" ]] || continue
            if grep -qF "$host_path" "$f" 2>/dev/null; then
                log_warn "Usuwam zepsute repozytorium: $f ($url)"
                sudo rm -f "$f"
                removed=1
            fi
        done
    done <<< "$broken_urls"

    if [[ $removed -eq 1 ]]; then
        wait_for_apt
        if sudo apt-get update -yq; then
            return 0
        else
            log_warn "apt-get update nadal zwraca błędy po usunięciu zepsutych repozytoriów — kontynuuję mimo to"
            return 0
        fi
    else
        log_warn "Nie udało się automatycznie zidentyfikować zepsutych repozytoriów — kontynuuję mimo błędów update"
        return 0
    fi
}

# --- Funkcja zapobiegająca blokadom APT ---
wait_for_apt() {
    log_info "Zatrzymywanie PackageKit i oczekiwanie na zwolnienie blokad APT..."
    sudo systemctl stop packagekit 2>/dev/null || true

    while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          sudo killall -0 apt apt-get dpkg 2>/dev/null; do
        sleep 3
    done
}

# --- Bezpieczne dodawanie PPA + instalacja pakietów ---
# Jeśli dane PPA nie ma jeszcze wydania dla bieżącego OS_CODENAME (np. bardzo
# świeży release bazowego Ubuntu), "apt-get update" zwróci 404. add-apt-repository samo
# w sobie kończy się sukcesem (tylko dodaje wpis), więc błąd wychodzi dopiero
# przy update — dlatego łapiemy go tutaj, usuwamy PPA i jedziemy dalej,
# zamiast pozwolić, by set -e/trap ubiło cały skrypt.
add_ppa_and_install() {
    local ppa="$1"; shift
    local packages=("$@")

    if ! command -v add-apt-repository &>/dev/null; then
        log_warn "add-apt-repository niedostępne — pomijam PPA $ppa"
        return 1
    fi

    if ! sudo add-apt-repository -y "ppa:$ppa" 2>/dev/null; then
        log_warn "Nie udało się dodać PPA $ppa — pomijam"
        return 1
    fi

    wait_for_apt
    if sudo apt-get update -yq; then
        if sudo apt-get install -yq "${packages[@]}"; then
            log_ok "Zainstalowano ${packages[*]} (PPA $ppa)"
            return 0
        else
            log_warn "Instalacja ${packages[*]} z PPA $ppa nie powiodła się"
            return 1
        fi
    else
        log_warn "PPA $ppa nie ma jeszcze wydania dla '$OS_CODENAME' (404) — usuwam PPA i pomijam"
        sudo add-apt-repository --remove -y "ppa:$ppa" 2>/dev/null || true
        wait_for_apt
        sudo apt-get update -yq || true
        return 1
    fi
}

# --- Zmienne globalne ---
CURRENT_USER=$(whoami)
OLD_USER_PLACEHOLDER="bartek"
DEB_DIR="/tmp/debs_$$"

# Mint ma własny VERSION_CODENAME (np. "wilma"), ale repozytoria (backporty itp.)
# trzeba dopasowywać do bazowego Ubuntu, dlatego korzystamy z UBUNTU_CODENAME.
# shellcheck disable=SC1091
source /etc/os-release
OS_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

# --- Sprawdzenie uprawnień ---
if [[ "$EUID" -eq 0 ]]; then
    log_err "Nie uruchamiaj skryptu jako root. Użyj zwykłego użytkownika z dostępem do sudo."
    exit 1
fi

# ── Tymczasowy wyjątek sudo dla apt-get ───────────────────────
sudo -v
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-temp-installer > /dev/null

# ==========================================================
# 1. PRZYGOTOWANIE
# ==========================================================
log_info "Przygotowanie konfiguracji użytkownika..."

# Kopiowanie skryptu aktualizacji (jeśli istnieje)
if [[ -f "$SCRIPT_DIR/.update.sh" ]]; then
    cp -af "$SCRIPT_DIR/.update.sh" ~/.update.sh
    chmod +x ~/.update.sh
fi

# ==========================================================
# 2. REPOZYTORIA I AKTUALIZACJA SYSTEMU
# ==========================================================
log_info "Konfiguracja repozytoriów APT..."

wait_for_apt

# Wykomentuj wpisy cdrom (jeśli istnieją)
sudo sed -i '/cdrom/s/^/#/' /etc/apt/sources.list 2>/dev/null || true

# Dodaj architektury (potrzebne np. dla Wine / 32-bit)
sudo dpkg --add-architecture i386

# Mint domyślnie już ma włączone universe/multiverse w swoich repo,
# ale dla pewności (np. na "czystszych" instalacjach) upewniamy się:
if command -v add-apt-repository &>/dev/null; then
    sudo add-apt-repository -y universe  2>/dev/null || true
    sudo add-apt-repository -y multiverse 2>/dev/null || true
fi

# Narzędzia potrzebne do konfiguracji kluczy GPG i wykrywania GPU
wait_for_apt
safe_apt_update
sudo apt-get install -yq curl wget gnupg pciutils

# Utworzenie zalecanego katalogu na klucze i wymuszenie dostępu (755)
sudo mkdir -p /etc/apt/keyrings
sudo chmod 755 /etc/apt/keyrings

# Repozytorium Google Chrome
if [ ! -f /etc/apt/keyrings/google-chrome.gpg ]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
    sudo chmod 644 /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
http://dl.google.com/linux/chrome/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
fi

# Repozytorium Brave (Origin) - wg https://brave.com/origin/linux/
# UWAGA: pliki brave-browser-archive-keyring.gpg oraz brave-core.asc hostowane
# przez Brave na S3 bywają nieaktualne względem klucza, którym faktycznie
# podpisują InRelease (znany, powtarzający się problem, np.
# https://github.com/brave/brave-browser/issues/42949 i #52253), co objawia
# się błędem "NO_PUBKEY". Dlatego pobieramy klucz bezpośrednio po jego ID
# z serwera kluczy zamiast z plików hostowanych przez Brave.
# WAŻNE: nowoczesny gpg domyślnie zapisuje nowo tworzony keyring w formacie
# "keybox" (.kbx), którego apt NIE obsługuje ("unsupported filetype") —
# dlatego importujemy do tymczasowego GNUPGHOME i EKSPORTUJEMY klucz do
# klasycznego formatu binarnego OpenPGP, jakiego wymaga apt. Zapisujemy też
# klucz pod /usr/share/keyrings, bo tę ścieżkę ma na sztywno wpisaną
# (Signed-By) plik .sources pobierany bezpośrednio z serwera Brave.
sudo mkdir -p /usr/share/keyrings
sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
BRAVE_KEY_ID="0686B78420038257"
BRAVE_GNUPGHOME="$(mktemp -d)"
if ! gpg --homedir "$BRAVE_GNUPGHOME" --keyserver hkps://keyserver.ubuntu.com --recv-keys "$BRAVE_KEY_ID"; then
    log_warn "keyserver.ubuntu.com nie odpowiedział, próbuję keys.openpgp.org..."
    gpg --homedir "$BRAVE_GNUPGHOME" --keyserver hkps://keys.openpgp.org --recv-keys "$BRAVE_KEY_ID"
fi
gpg --homedir "$BRAVE_GNUPGHOME" --export "$BRAVE_KEY_ID" \
    | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
rm -rf "$BRAVE_GNUPGHOME"
sudo chmod 644 /usr/share/keyrings/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

wait_for_apt
safe_apt_update
sudo apt-get upgrade -yq

# ==========================================================
# 3. INSTALACJA PAKIETÓW
# ==========================================================
log_info "Instalacja podstawowych narzędzi i firmware..."

wait_for_apt
# Linux-firmware.
sudo apt-get install -yq linux-firmware

# --- Usuwanie zbędnych pakietów ---
log_info "Usuwanie zbędnych pakietów..."
PACKAGES_REMOVE=(
    # nano
    # imagemagick
)
if [[ ${#PACKAGES_REMOVE[@]} -gt 0 ]]; then
    for pkg in "${PACKAGES_REMOVE[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            sudo apt-get purge -yq "$pkg" || true
        fi
    done
fi
sudo apt-get autoremove -yq

# --- Główna instalacja ---
log_info "Instalacja pakietów głównych..."
wait_for_apt
PACKAGES_INSTALL=(
    # Przeglądarki komunikatory
    google-chrome-stable brave-origin
    # Multimedia
    gmic mixxx kdenlive gimp soundconverter
    # Narzędzia systemowe
    vim dconf-editor dconf-cli hunspell-pl bleachbit profile-sync-daemon git build-essential
    unrar-free mc btrfs-progs exfatprogs ntfs-3g os-prober
    adb fastboot fsarchiver inxi pv rsync
    p7zip-full makeself zenity innoextract needrestart flatpak timeshift
    # Python
    python3-defusedxml python3-packaging python3-pip python3-tqdm
    # Gaming / GPU
    libayatana-appindicator3-1 gamemode vulkan-tools mangohud
    vkd3d-compiler goverlay winetricks
    # Kompilacja
    gcc make cmake meson ninja-build
    # GStreamer
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
    # Inne
    zsh zsh-syntax-highlighting zsh-autosuggestions
)

sudo apt-get install -yq "${PACKAGES_INSTALL[@]}"

# --- Pakiety niedostępne (lub niepewne) w standardowym apt ---
log_info "Instalacja pakietów spoza głównych repo (apt-cache / Flatpak / GitHub)..."

# Upewnij się, że Flathub jest już dostępny (flatpak jest instalowany wyżej)
if command -v flatpak &>/dev/null; then
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
fi

# Telegram Desktop — z PPA atareao
log_info "Dodawanie PPA atareao/telegram..."
add_ppa_and_install "atareao/telegram" telegram || true

# Fastfetch — z PPA zhangsongcui3371/fastfetch
log_info "Dodawanie PPA zhangsongcui3371/fastfetch..."
add_ppa_and_install "zhangsongcui3371/fastfetch" fastfetch || true

# HandBrake — z PPA stebbins/handbrake-releases (najnowsza wersja);
# w razie niepowodzenia instalujemy wersję z domyślnych repo (universe)
log_info "Dodawanie PPA stebbins/handbrake-releases..."
if ! add_ppa_and_install "stebbins/handbrake-releases" handbrake handbrake-cli; then
    log_warn "PPA stebbins/handbrake-releases niedostępne — próbuję wersję z universe"
    wait_for_apt
    sudo apt-get install -yq handbrake handbrake-cli \
        || log_warn "Instalacja HandBrake nie powiodła się"
fi

# CDEmu (cdemu-daemon, cdemu-client) — niedostępne w domyślnych repo,
# wymaga PPA cdemu/ppa
log_info "Dodawanie PPA cdemu/ppa..."
add_ppa_and_install "cdemu/ppa" cdemu-daemon cdemu-client || true

# Flatseal — dostępny wyłącznie jako Flatpak
if command -v flatpak &>/dev/null; then
    sudo flatpak install -y flathub com.github.tchx84.Flatseal \
        && log_ok "Zainstalowano Flatseal (Flatpak)" \
        || log_warn "Nie udało się zainstalować Flatseal"
else
    log_warn "flatpak nieobecny — nie można zainstalować Flatseal"
fi

# --- WINE ORAZ 32-BITOWE BIBLIOTEKI DO GIER ---
log_info "Instalacja Wine "
wait_for_apt
sudo apt-get install -yq wine wine64 

# ==========================================================
# WYKRYWANIE GPU: 32-BITOWE BIBLIOTEKI I MODUŁY INITRAMFS
# ==========================================================
log_info "Wykrywanie układu graficznego (biblioteki 32-bit oraz moduły jądra)..."
VGA_INFO=$(lspci -nn | grep -iE "VGA|3D|Display" || true)
MODULES_FILE="/etc/initramfs-tools/modules"

add_module() {
    grep -q "^$1" "$MODULES_FILE" || echo "$1" | sudo tee -a "$MODULES_FILE" > /dev/null
}

wait_for_apt
if echo "$VGA_INFO" | grep -iq "NVIDIA"; then
    log_ok "Wykryto układ NVIDIA. Instaluję biblioteki i dodaję moduł..."
    sudo apt-get install -yq libnvidia-gl-nvidia-current:i386 2>/dev/null \
        || sudo apt-get install -yq libgl1-nvidia-glvnd-glx:i386 2>/dev/null \
        || log_warn "Nie znaleziono pakietu 32-bit dla NVIDIA — sprawdź nazwę sterownika ręcznie"
    add_module "nvidia"
    add_module "nvidia_modeset"
    add_module "nvidia_uvm"
    add_module "nvidia_drm"
elif echo "$VGA_INFO" | grep -iq "AMD"; then
    log_ok "Wykryto układ AMD. Instaluję biblioteki Mesa i dodaję moduł amdgpu..."
    sudo apt-get install -yq libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
    add_module "amdgpu"
elif echo "$VGA_INFO" | grep -iq "Intel"; then
    log_ok "Wykryto układ Intel. Instaluję biblioteki Mesa i dodaję moduł i915..."
    sudo apt-get install -yq libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
    add_module "i915"
else
    log_warn "Nie rozpoznano jednoznacznie układu (NVIDIA/AMD/Intel). Instaluję domyślne pakiety Mesa."
    sudo apt-get install -yq libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
fi

log_info "Przebudowa obrazu initramfs..."
sudo update-initramfs -u

# --- Gear Lever (Flathub) ---
log_info "Instalacja Gear Lever z Flathub..."
sudo flatpak install -y flathub it.mijorus.gearlever || log_warn "Błąd instalacji Gear Lever"

wait_for_apt
sudo apt-get install -yq "linux-headers-$(uname -r)" \
    || log_warn "Nie udało się zainstalować nagłówków kernela (ignoruję)"

# --- Paczki .deb z internetu ---
log_info "Pobieranie i instalacja paczek .deb..."
mkdir -p "$DEB_DIR"

download_deb() {
    local name="$1" url="$2" dest="$3"
    if wget -q --timeout=30 -O "$dest" "$url"; then
        log_ok "Pobrano: $name"
    else
        log_warn "Nie udało się pobrać: $name ($url) — pomijam"
        rm -f "$dest"
    fi
}

get_github_deb_url() {
    local repo="$1" pattern="$2"
    curl -sf "https://api.github.com/repos/${repo}/releases/latest" \
        | grep "browser_download_url.*${pattern}" \
        | cut -d '"' -f 4 \
        || true
}

download_deb "Discord" \
    "https://discord.com/api/download?platform=linux&format=deb" \
    "$DEB_DIR/discord.deb"

LSFG_URL=$(get_github_deb_url "YuriSizov/ls-fg"    "ls-fg_.*deb")
LSFG_VK_URL=$(get_github_deb_url "YuriSizov/ls-fg-vk" "deb")

if [[ -n "$LSFG_URL" ]]; then download_deb "ls-fg" "$LSFG_URL" "$DEB_DIR/lsfg.deb"; fi
if [[ -n "$LSFG_VK_URL" ]]; then download_deb "ls-fg-vk" "$LSFG_VK_URL" "$DEB_DIR/lsfg-vk.deb"; fi

# Faugus Launcher — z PPA faugus/faugus-launcher
log_info "Dodawanie PPA faugus/faugus-launcher..."
if ! add_ppa_and_install "faugus/faugus-launcher" faugus-launcher; then
    log_warn "Nie udało się zainstalować Faugus Launcher z PPA — pomijam"
fi

shopt -s nullglob
DEB_FILES=("$DEB_DIR"/*.deb)
if [[ ${#DEB_FILES[@]} -gt 0 ]]; then
    wait_for_apt
    sudo apt-get install -yq "${DEB_FILES[@]}"
else
    log_warn "Brak plików .deb do zainstalowania"
fi
shopt -u nullglob
rm -rf "$DEB_DIR"

# ==========================================================
# 4. WIRTUALIZACJA I FIREWALL
# ==========================================================
log_info "Konfiguracja wirtualizacji i UFW..."

wait_for_apt
sudo apt-get install -yq \
    virt-manager qemu-system qemu-utils \
    libvirt-daemon-system libvirt-clients \
    ovmf dnsmasq \
    bluetooth bluez bluez-firmware bluez-tools ufw

# Serwis libvirt (uruchamiamy PRZED konfiguracją UFW, żeby virbr0 już istniał)
for svc in libvirtd virtqemud; do
    if systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "$svc"; then
        sudo systemctl enable --now "${svc}.service"
        log_ok "Uruchomiono serwis: $svc"
        break
    fi
done

# Upewnij się, że sieć "default" (NAT dla maszyn wirtualnych) istnieje i wystartuje przy boocie
if ! sudo virsh net-info default &>/dev/null; then
    log_warn "Sieć 'default' nie jest zdefiniowana - definiuję z domyślnego XML..."
    sudo virsh net-define /usr/share/libvirt/networks/default.xml || true
fi
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default || log_warn "Nie udało się ustawić autostartu sieci 'default' - sprawdź 'virsh net-list --all'."

# UFW
if command -v ufw &>/dev/null || [[ -x /usr/sbin/ufw ]]; then
    if [[ -f /etc/default/ufw ]]; then
        sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' \
            /etc/default/ufw || true
    fi

    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow in  on virbr0
    sudo ufw allow out on virbr0
    sudo ufw allow from 192.168.122.0/24
    sudo ufw --force enable
else
    log_warn "ufw niedostępny — pomijam konfigurację firewalla"
fi

# Grupy libvirt
for grp in libvirt libvirt-qemu kvm; do
    if getent group "$grp" &>/dev/null; then
        sudo usermod -aG "$grp" "$CURRENT_USER" \
            && log_ok "Dodano $CURRENT_USER do grupy $grp"
    else
        log_warn "Grupa $grp nie istnieje — pomijam"
    fi
done

# ==========================================================
# 6. FINALIZACJA I OPTYMALIZACJA
# ==========================================================
log_info "Finalizacja i optymalizacja..."

sudo systemctl enable fstrim.timer || true
sudo journalctl --vacuum-time=2d || true

# GRUB timeout
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub || true
sudo update-grub

# Awatar użytkownika
if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    log_info "Konfiguracja awatara użytkownika..."

    # Kopiowanie ikony do systemowego katalogu AccountsService
    sudo mkdir -p /var/lib/AccountsService/icons/
    sudo cp -af "$SCRIPT_DIR/piwo.png" "/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo chmod 644 "/var/lib/AccountsService/icons/$CURRENT_USER"

    # Tworzenie lub inteligentna edycja pliku konfiguracyjnego AccountsService
    ACCOUNTS_USER_FILE="/var/lib/AccountsService/users/$CURRENT_USER"

    if [[ ! -f "$ACCOUNTS_USER_FILE" ]]; then
        # Jeśli plik nie istnieje (świeży system), tworzymy go od zera z poprawną strukturą
        echo -e "[User]\nIcon=/var/lib/AccountsService/icons/$CURRENT_USER" | sudo tee "$ACCOUNTS_USER_FILE" > /dev/null
    else
        # Jeśli istnieje, upewniamy się, że ma nagłówek [User]
        if ! grep -q "^\[User\]" "$ACCOUNTS_USER_FILE" 2>/dev/null; then
            echo -e "[User]" | sudo tee -a "$ACCOUNTS_USER_FILE" > /dev/null
        fi

        # Aktualizujemy ścieżkę lub dopisujemy ją tuż pod nagłówkiem [User]
        if grep -q "^Icon=" "$ACCOUNTS_USER_FILE" 2>/dev/null; then
            sudo sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/$CURRENT_USER|" "$ACCOUNTS_USER_FILE"
        else
            sudo sed -i "/^\[User\]/a Icon=/var/lib/AccountsService/icons/$CURRENT_USER" "$ACCOUNTS_USER_FILE"
        fi
    fi
    sudo chmod 644 "$ACCOUNTS_USER_FILE"

    # Dodanie tradycyjnego fallbacku (~/.face) dla Slick-Greeter i Cinnamon
    cp -af "$SCRIPT_DIR/piwo.png" "$HOME/.face"
    cp -af "$SCRIPT_DIR/piwo.png" "$HOME/.face.icon"
    chmod 644 "$HOME/.face" "$HOME/.face.icon"

    # Wymuszenie przeładowania demona AccountsService
    sudo systemctl restart accounts-daemon || true

    log_ok "Ustawiono awatar użytkownika (AccountsService + fallback .face)"
fi

# Kopiowanie pliku tapety
log_info "Kopiowanie tapety pulpitu Cinnamon..."
WALLPAPER_DIR="/usr/share/backgrounds/custom"
sudo mkdir -p "$WALLPAPER_DIR"

SOURCE_WALLPAPER="$SCRIPT_DIR/wallpaper.jpg"
DEST_WALLPAPER="$WALLPAPER_DIR/wallpaper.jpg"
CHOSEN_WALLPAPER=""

if [[ -f "$SOURCE_WALLPAPER" ]]; then
    sudo cp "$SOURCE_WALLPAPER" "$DEST_WALLPAPER"
    sudo chmod 644 "$DEST_WALLPAPER" # Nadanie uprawnień do odczytu dla wszystkich użytkowników
    CHOSEN_WALLPAPER="$DEST_WALLPAPER"
    log_info "Tapeta skopiowana do $DEST_WALLPAPER"
else
    log_warn "Nie znaleziono pliku $SOURCE_WALLPAPER obok skryptu!"
fi

# Zmiana tła ekranu logowania (LightDM / Slick-Greeter)
log_info "Konfiguracja tła ekranu logowania..."
if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    LOGIN_WALLPAPER_DIR="/usr/share/backgrounds/custom"
    sudo mkdir -p "$LOGIN_WALLPAPER_DIR"
    sudo cp -af "$SCRIPT_DIR/login-wallpaper.png" "$LOGIN_WALLPAPER_DIR/login-wallpaper.png"
    sudo chmod 644 "$LOGIN_WALLPAPER_DIR/login-wallpaper.png"

    SLICK_GREETER_CONF="/etc/lightdm/slick-greeter.conf"

    # Lepszy warunek: sprawdzamy, czy plik istnieje LUB czy system jest skonfigurowany pod slick-greeter
    if [[ -f "$SLICK_GREETER_CONF" ]] || grep -qr "slick-greeter" /usr/share/lightdm/ 2>/dev/null || command -v slick-greeter >/dev/null 2>&1; then

        # Tworzymy katalog i plik konfiguracyjny, jeśli nie istnieją
        sudo mkdir -p "$(dirname "$SLICK_GREETER_CONF")"
        sudo touch "$SLICK_GREETER_CONF"

        if grep -q "^background=" "$SLICK_GREETER_CONF" 2>/dev/null; then
            sudo sed -i "s|^background=.*|background=$LOGIN_WALLPAPER_DIR/login-wallpaper.png|" \
                "$SLICK_GREETER_CONF"
        elif grep -q "^\[Greeter\]" "$SLICK_GREETER_CONF" 2>/dev/null; then
            sudo sed -i "/^\[Greeter\]/a background=$LOGIN_WALLPAPER_DIR/login-wallpaper.png" \
                "$SLICK_GREETER_CONF"
        else
            printf '[Greeter]\nbackground=%s\n' "$LOGIN_WALLPAPER_DIR/login-wallpaper.png" \
                | sudo tee -a "$SLICK_GREETER_CONF" > /dev/null
        fi

        # Wyłączenie losowych/rozmytych teł użytkownika, żeby nasze tło było widoczne
        if grep -q "^draw-user-backgrounds=" "$SLICK_GREETER_CONF" 2>/dev/null; then
            sudo sed -i "s|^draw-user-backgrounds=.*|draw-user-backgrounds=false|" "$SLICK_GREETER_CONF"
        else
            sudo sed -i "/^\[Greeter\]/a draw-user-backgrounds=false" "$SLICK_GREETER_CONF"
        fi

        log_ok "Ustawiono tło ekranu logowania (Slick-Greeter): $LOGIN_WALLPAPER_DIR/login-wallpaper.png"
    else
        log_warn "Slick-Greeter nie wykryty w systemie — plik skopiowany, ale nie skonfigurowano automatycznie."
    fi
else
    log_warn "Brak pliku login-wallpaper.png w katalogu ze skryptem - pomijam."
fi

# Konfiguracja BleachBit (root)
if [[ -d "$SCRIPT_DIR/bleachbit" ]]; then
    sudo mkdir -p /root/.config/bleachbit
    sudo cp -af "$SCRIPT_DIR/bleachbit/." /root/.config/bleachbit/
    log_ok "Skopiowano konfigurację BleachBit"
else
    log_warn "Folder bleachbit nie istnieje — pomijam"
fi

# DNS przez NetworkManager
ACTIVE_CONN=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
    | grep -v "^lo" | head -n 1 | cut -d: -f1 || true)
if [[ -n "$ACTIVE_CONN" ]]; then
    sudo nmcli connection modify "$ACTIVE_CONN" \
        ipv4.dns "1.1.1.1,1.0.0.1" \
        ipv6.dns "2606:4700:4700::1112,2606:4700:4700::1002"
    sudo nmcli connection up "$ACTIVE_CONN" || true
else
    log_warn "Brak aktywnego połączenia NetworkManager — pominięto konfigurację DNS"
fi

# ==========================================================
# 7. ZSH + OH MY ZSH + POWERLEVEL10K
# ==========================================================
log_info "Konfiguracja ZSH..."

if command -v zsh &>/dev/null; then
    sudo chsh -s /usr/bin/zsh "$CURRENT_USER"

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended || true
    fi

    P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [[ ! -d "$P10K_DIR" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" || true
    fi

    ZSHRC="$HOME/.zshrc"
    if [[ -f "$ZSHRC" ]]; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC" || true
        sed -i 's/^plugins=(.*/plugins=(git sudo systemd debian)/' "$ZSHRC" || true
        grep -q "LC_ALL=pl_PL.UTF-8" "$ZSHRC" || echo "export LC_ALL=pl_PL.UTF-8" >> "$ZSHRC"
        grep -q "^fastfetch"         "$ZSHRC" || echo "fastfetch"                  >> "$ZSHRC"
        grep -q "zsh-syntax-highlighting.zsh" "$ZSHRC" || echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> "$ZSHRC"
        grep -q "zsh-autosuggestions.zsh"     "$ZSHRC" || echo "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"         >> "$ZSHRC"
    fi
fi

# ==========================================================
# 8. KOPIOWANIE KONFIGURACJI ORAZ DCONF
# ==========================================================
log_info "Kopiowanie plików konfiguracyjnych..."
if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/; fi
if [[ -d "$SCRIPT_DIR/.icons" ]]; then cp -af "$SCRIPT_DIR/.icons/." ~/.icons/; fi
if [[ -d "$SCRIPT_DIR/.themes" ]]; then cp -af "$SCRIPT_DIR/.themes/." ~/.themes/; fi

# Podmiana ścieżki użytkownika w plikach konfiguracyjnych
if [[ "$OLD_USER_PLACEHOLDER" != "$CURRENT_USER" ]]; then
    find ~/.config -type f -exec sed -i "s|/home/$OLD_USER_PLACEHOLDER|/home/$CURRENT_USER|g" {} + 2>/dev/null || true
fi

# Ustawianie tapety pulpitu w środowisku graficznym (musi być PO dconf load,
# inaczej `dconf load /` powyżej nadpisuje z powrotem stary picture-uri)
if [[ -n "$CHOSEN_WALLPAPER" ]]; then
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        log_info "Ustawianie tapety pulpitu..."
        # Cinnamon/GSettings nie zawsze wykrywa zmianę, jeśli nowy URI jest
        # identyczny z poprzednim (np. przy ponownym uruchomieniu skryptu
        # z tym samym plikiem wallpaper.jpg) - dlatego najpierw czyścimy klucz.
        gsettings set org.cinnamon.desktop.background picture-uri "''" 2>/dev/null || true
        gsettings set org.cinnamon.desktop.background picture-uri "file://$CHOSEN_WALLPAPER" || \
            log_warn "Nie udało się ustawić tapety przez gsettings (brak sesji graficznej?)"
        gsettings set org.cinnamon.desktop.background picture-uri-dark "file://$CHOSEN_WALLPAPER" 2>/dev/null || true
    else
        log_warn "Brak aktywnej sesji graficznej — tapeta skopiowana, ale nie ustawiona automatycznie. Ustaw ją ręcznie po zalogowaniu."
    fi
fi

# Wczytanie ustawień dconf
if [[ -f "$SCRIPT_DIR/dconf-settings.ini" ]]; then
    if command -v dconf &>/dev/null; then
        log_info "Czyszczenie pliku INI i naprawa uprawnień struktury .config..."

        # 1. Usuwamy znaki powrotu karetki (CRLF -> LF) przy użyciu sed (nie wymaga dos2unix)
        sed -i 's/\r$//' "$SCRIPT_DIR/dconf-settings.ini"

        # 2. Upewniamy się, że katalogi konfiguracyjne należą do zalogowanego użytkownika, a nie roota
        mkdir -p "$HOME/.config/dconf"
        sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$HOME/.config"

        log_info "Inicjalizacja bezpiecznej sesji dconf..."

        # Tworzymy tymczasowy plik na ewentualny komunikat o błędzie ze strony dconf
        DCONF_ERR_LOG="/tmp/dconf_err_$$"

        # 3. Wykonanie ładowania w czystej sesji z przechwytywaniem strumienia błędów (2>)
        if dbus-run-session dconf load / < "$SCRIPT_DIR/dconf-settings.ini" 2>"$DCONF_ERR_LOG"; then
            log_ok "Wczytano ustawienia dconf pomyślnie!"
            rm -f "$DCONF_ERR_LOG"
        else
            log_err "Narzędzie dconf zgłosiło błąd wewnętrzny."
            echo -e "${WARN}Szczegóły błędu zwrócone przez dconf:${NC}"
            cat "$DCONF_ERR_LOG"
            rm -f "$DCONF_ERR_LOG"
        fi
    fi
fi

log_info "Zatrzymywanie sesji Cinnamon w celu przeładowania konfiguracji..."
killall cinnamon 2>/dev/null || true
sleep 3

log_info "Czyszczenie pamięci podręcznej (Cache)..."
rm -rf ~/.cache/icon-cache.kcache ~/.cache/cinnamon* ~/.cache/ico*

# Odbudowa baz danych aplikacji/ikon (odpowiednik kbuildsycoca dla Cinnamon)
update-desktop-database ~/.local/share/applications 2>/dev/null || true
gtk-update-icon-cache -f ~/.icons/* 2>/dev/null || true

# Ponowne uruchomienie Cinnamon w tle, żeby zapisał wczytaną konfigurację
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    (cinnamon --replace &>/dev/null &)
    sleep 5
    killall cinnamon 2>/dev/null || true
    sleep 2
else
    log_warn "Brak aktywnej sesji graficznej — Cinnamon zostanie uruchomiony normalnie po restarcie."
fi

# ==========================================================
log_info "Sprzątanie po instalacji..."
sudo rm -f /etc/sudoers.d/99-temp-installer

log_ok "KONFIGURACJA ZAKOŃCZONA SUKCESEM!"
sleep 3
systemctl reboot

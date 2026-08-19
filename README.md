# 🚀 Linux Mint + Cinnamon: Comprehensive Configuration Script

An automated, powerful Bash script designed to transform a clean **Linux Mint** installation with the **Cinnamon** desktop into a complete, optimized workstation ready for both work and entertainment.


---

## ✨ Main Features

The script performs a full system deployment divided into several logical stages:

### ⚙️ 1. Repositories & Updates
* Enables the `i386` architecture (required for games and Wine).
* Extends repositories with `contrib` and `non-free` components on the underlying Ubuntu/Debian base (using the standard `sources.list` format; Mint's own repositories are left untouched).
* Adds official repositories for external applications: **Google Chrome** and **Brave Browser**.
* Activates the **Flathub** repository (Flatpak) — useful since Mint ships with the Software Manager but not Flathub enabled by default.
* Safely waits for APT locks held by other system processes (including the Mint Update Manager / `mintupdate`) to be released.

### 🎮 2. Gaming, Drivers & Wine
* **Smart GPU Detection:** Automatically identifies your graphics card (NVIDIA / AMD / Intel) and installs dedicated 32-bit libraries, adding the appropriate modules to `initramfs` (forcing early KMS loading for smooth booting).
* For NVIDIA cards, offers to use Mint's built-in `driver-manager` / `mintdrivers` in addition to manual driver installation.
* Installs the latest stable version of **Wine** along with 32-bit audio libraries (PulseAudio, OpenAL).
* Automatically downloads and configures the latest version of **Winetricks**.
* Installs useful gaming tools: `gamemode`, `mangohud`, `vulkan-tools`, `vkd3d-compiler`, `goverlay`.

### 📦 3. Package Management
* **Debloat:** Removes unnecessary or rarely used pre-installed Mint applications (e.g. Hypnotix, Drawing, Celluloid, Pix, Mint Welcome Screen — kept optional/skippable per app).
* **Everyday tools installation:** Over 40 hand-picked packages (including VLC/GStreamer, Telegram, QBitTorrent, Kdenlive, Audacity, Krita, Vim, Fastfetch, BleachBit, rsync, 7zip, and many more).
* **Hardware detection:** Automatically installs missing firmware using `isenkram`.
* Automatically downloads the latest `.deb` packages from designated GitHub releases (e.g. Discord, faugus-launcher, ls-fg).

### 🔒 4. Virtualization & Firewall
* Installs and configures the **QEMU/KVM** virtualization environment and **Virt-Manager**.
* Automatically adds the current user to the `libvirt`, `libvirt-qemu`, and `kvm` groups.
* Configures and enables **UFW** (via Mint's `gufw` front-end where available) — blocks incoming traffic by default, allows outgoing, and opens the necessary ports for the virtualization network bridge (`virbr0`).

### 🎨 5. Cinnamon Desktop Personalization
* **Safe sync:** Copies your pre-made configuration files (`.config`, `.local`, `.icons`) after safely restarting the `cinnamon` process — preventing Cinnamon from overwriting your settings with defaults during shutdown.
* **User migration:** Automatically scans config files and replaces the old user placeholder (`bartek`) with your current account name.
* Applies custom **Cinnamon themes, applets, and desklets** (if provided) via `dconf`/`gsettings`, instead of KDE's `kwriteconfig`/`plasma-apply-*` tools.
* Configures the **Plymouth** boot splash (using the `bgrt` theme) and hides unnecessary GRUB messages (`quiet splash`).
* Automatically sets the user avatar (via `AccountsService`/`lightdm`), custom Cinnamon splash screen, and wallpapers in multiple resolutions for the *Next*-style theme.

### 🐚 6. Modern Shell (ZSH)
* Sets **ZSH** as the default user shell.
* Installs the **Oh My ZSH** framework in unattended mode.
* Downloads and activates the powerful **Powerlevel10k** theme.
* Adds automatic `fastfetch` invocation on terminal startup and enforces correct UTF-8 encoding.

### ⚡ 7. System Optimizations
* Enables regular SSD trimming via `fstrim.timer`.
* Clears old systemd system logs (`journalctl --vacuum-time=2d`).
* Sets the GRUB menu timeout to `0` seconds (instant boot).
* Configures fast and secure DNS servers (Cloudflare `1.1.1.1`) directly in the active **NetworkManager** configuration (same networking stack as on KDE — Mint uses `nm-applet`/`cinnamon-settings` on top of it).

---

## 🚀 How to Run

The script **cannot** be run directly from the `root` account (via `su` or `sudo ./install.sh`). Run it as a regular user with `sudo` privileges. The script will ask for your password once, then temporarily remove the password requirement for installation processes to run uninterrupted.

### Step 1: Clone the repository or download the files
```bash
git clone https://github.com/syscore88/mint-config.git
```

### Step 2: Enter the downloaded folder
```bash
cd mint-config
```

### Step 3: Make the script executable
```bash
chmod +x install.sh
```

### Step 4: Run the script
```bash
./install.sh
```

Once the process is complete, the computer will restart automatically. After logging in, you'll be greeted by a fully configured ZSH environment and a customized Cinnamon desktop!

### ☕ Support the Project

If you find this tool helpful and it saved you some time, consider buying me a coffee to support further development! 

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/bartekszczecinski)

<img width="1280" height="800" alt="Screenshot_ubuntu25 10_2026-07-20_18:52:25" src="https://github.com/user-attachments/assets/a46bc512-b785-4917-927d-43d62822830c" />

---

If you find this project useful, leave a star! ⭐

---
_This script was created to minimize system setup time after a clean installation. Use at your own risk!_

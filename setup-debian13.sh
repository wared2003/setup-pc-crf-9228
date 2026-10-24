#!/usr/bin/env bash
#
# Setup script for Debian 13 (Trixie) - Croix-Rouge Workstations
#

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

BENEVOLE_USER="benevole"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_SRC="${SCRIPT_DIR}/wallpaper.jpg"
AVATAR_SRC="${SCRIPT_DIR}/avatar.png"
WALLPAPER_DEST="/usr/share/backgrounds/croix-rouge-wallpaper.jpg"
AVATAR_DEST="/var/lib/AccountsService/icons/${BENEVOLE_USER}"

echo "==> 1. User check and creation..."
if ! id "${BENEVOLE_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${BENEVOLE_USER}"
    passwd -d "${BENEVOLE_USER}"
fi

echo "==> 2. System update..."
apt-get update -y
apt-get dist-upgrade -y

echo "==> 3. Installing dependencies & media codecs..."
apt-get install -y \
    curl \
    wget \
    git \
    dconf-cli \
    gnome-shell-extension-dash-to-dock \
    unattended-upgrades \
    apt-listchanges \
    flatpak \
    gnome-software-plugin-flatpak \
    accountsservice \
    cups \
    simple-scan \
    ffmpeg

echo "==> 4. Configuring automatic updates..."
cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

systemctl enable --now unattended-upgrades

echo "==> 5. Enabling GNOME automatic login (GDM3)..."
mkdir -p /etc/gdm3
if [[ -f /etc/gdm3/daemon.conf ]]; then
    sed -i '/^AutomaticLoginEnable=/d' /etc/gdm3/daemon.conf
    sed -i '/^AutomaticLogin=/d' /etc/gdm3/daemon.conf
fi

cat <<EOF >> /etc/gdm3/daemon.conf

[daemon]
AutomaticLoginEnable=True
AutomaticLogin=${BENEVOLE_USER}
EOF

echo "==> 6. Setting default wallpaper and profile picture..."
if [[ -f "${WALLPAPER_SRC}" ]]; then
    cp "${WALLPAPER_SRC}" "${WALLPAPER_DEST}"
    chmod 644 "${WALLPAPER_DEST}"
fi

if [[ -f "${AVATAR_SRC}" ]]; then
    mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users
    cp "${AVATAR_SRC}" "${AVATAR_DEST}"
    chmod 644 "${AVATAR_DEST}"

    cat <<EOF > "/var/lib/AccountsService/users/${BENEVOLE_USER}"
[User]
Icon=${AVATAR_DEST}
SystemAccount=false
EOF
fi

echo "==> 7. Configuring GNOME dconf defaults..."
mkdir -p /etc/dconf/profile
cat <<'EOF' > /etc/dconf/profile/user
user-db:user
system-db:local
EOF

mkdir -p /etc/dconf/db/local.d/
cat <<EOF > /etc/dconf/db/local.d/00-croix-rouge
[org/gnome/desktop/background]
picture-uri='file://${WALLPAPER_DEST}'
picture-uri-dark='file://${WALLPAPER_DEST}'
picture-options='zoom'

[org/gnome/shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com']
favorite-apps=['firefox-esr.desktop', 'org.onlyoffice.desktop-editors.desktop', 'org.gnome.Nautilus.desktop']

[org/gnome/shell/extensions/dash-to-dock]
dock-fixed=false
autohide=true
intellihide=true
dock-position='BOTTOM'
EOF

dconf update

echo "==> 8. Setting up Firefox policy and autostart..."
mkdir -p /etc/firefox-esr/policies
cat <<'EOF' > /etc/firefox-esr/policies/policies.json
{
  "policies": {
    "Homepage": {
      "URL": "https://connect.croix-rouge.fr",
      "Locked": false,
      "StartPage": "homepage"
    }
  }
}
EOF

BENEVOLE_HOME=$(eval echo "~${BENEVOLE_USER}")
AUTOSTART_DIR="${BENEVOLE_HOME}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"

cat <<'EOF' > "${AUTOSTART_DIR}/firefox.desktop"
[Desktop Entry]
Type=Application
Name=Firefox
Exec=firefox-esr %u
X-GNOME-Autostart-enabled=true
EOF

chown -R "${BENEVOLE_USER}:${BENEVOLE_USER}" "${BENEVOLE_HOME}/.config"

echo "==> 9. Setting up Flathub & ONLYOffice..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.onlyoffice.desktop-editors

echo "==> Setup completed successfully!"
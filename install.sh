#!/bin/bash
# Installs (or updates) the KWin script and enables it.
set -e
cd "$(dirname "$0")"

ID=animatedborders

if kpackagetool6 --type=KWin/Script --show "$ID" >/dev/null 2>&1; then
    kpackagetool6 --type=KWin/Script --upgrade package
else
    kpackagetool6 --type=KWin/Script --install package
fi

# Translations of the settings dialog, one catalog per po/<lang>.po.
for po in po/*.po; do
    lang=$(basename "$po" .po)
    dir=~/.local/share/locale/$lang/LC_MESSAGES
    mkdir -p "$dir"
    python3 po/compile_mo.py "$po" "$dir/kwin_script_animatedborders.mo"
done

# Applies changed settings right away instead of after the next login.
install -Dm755 apply-config.sh ~/.local/share/animatedborders/apply-config.sh
install -Dm644 -t ~/.config/systemd/user systemd/animatedborders-config.path systemd/animatedborders-config.service
systemctl --user daemon-reload
systemctl --user enable --now animatedborders-config.path

kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" true
qdbus6 org.kde.KWin /KWin reconfigure

echo "Installed and enabled. After an update, log out and back in:"
echo "KWin keeps the old QML code cached until it restarts."

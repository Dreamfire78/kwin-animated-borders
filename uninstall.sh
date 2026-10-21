#!/bin/bash
# Disables and removes the KWin script.
ID=animatedborders

kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" false
qdbus6 org.kde.KWin /KWin reconfigure
kpackagetool6 --type=KWin/Script --remove "$ID"

systemctl --user disable --now animatedborders-config.path
rm -f ~/.config/systemd/user/animatedborders-config.{path,service}
systemctl --user daemon-reload
rm -rf ~/.local/share/animatedborders ~/.cache/animatedborders-config
rm -f ~/.local/share/locale/*/LC_MESSAGES/kwin_script_animatedborders.mo

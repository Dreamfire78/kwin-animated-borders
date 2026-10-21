#!/bin/bash
# Run by animatedborders-config.path whenever kwinrc changes. KWin only rereads
# kwinrc on "reconfigure", which the settings dialog of KWin scripts never
# triggers, so do it here, but only when this script's own section changed.
config="${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc"
state="${XDG_CACHE_HOME:-$HOME/.cache}/animatedborders-config"

current=$(awk '/^\[/ { inside = ($0 == "[Script-animatedborders]") } inside' "$config" | sha1sum)
[ "$current" = "$(cat "$state" 2>/dev/null)" ] && exit 0

echo "$current" > "$state"
qdbus6 org.kde.KWin /KWin reconfigure

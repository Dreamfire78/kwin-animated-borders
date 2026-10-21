# Animated Borders – tacky-borders for KDE Plasma

A KWin script (QML) for Plasma 6 that draws an animated gradient border around the active window,
inspired by [tacky-borders](https://github.com/lukeyou05/tacky-borders) on Windows.
Nothing to compile, and it survives Plasma updates.

## Install / update

```bash
git clone https://github.com/dreamfire78/kwin-animated-borders.git
cd kwin-animated-borders
./install.sh
```

After an **update**, log out and back in once: KWin keeps the old QML code in memory until it restarts.

## Settings

System Settings → Window Management → KWin Scripts → "Animated Borders" → gear icon.
The settings dialog is currently in German.

| Setting (label) | Meaning |
|---|---|
| Border width (Randstärke) | Thickness of the border in pixels |
| Gap (Abstand zum Fenster) | Space between window and border |
| Corner radius (Eckenradius) | Radius of the window corners (0 = square) |
| Animation | Rotate, rotate reverse, pulse, static |
| Duration (Dauer pro Umlauf) | Speed in milliseconds per cycle |
| Colors 1–4 (Farbe 1–4) | Gradient colors as `#RRGGBB` or `#AARRGGBB` |
| Hide on maximized windows | Hides the border while the active window is maximized |

Saved settings take effect after about a second. The settings page for KWin scripts does not tell KWin that
`kwinrc` changed, so `install.sh` sets up a systemd path unit (`animatedborders-config.path`): whenever the
`[Script-animatedborders]` section changes, it runs `qdbus6 org.kde.KWin /KWin reconfigure`.
The script rereads its settings every second.

## Uninstall

```bash
./uninstall.sh
```

## How it works

- Four thin, click-through overlay windows (top, bottom, left, right) follow the geometry of the active window.
- Each window draws the whole ring as a `Shape` with a `ConicalGradient`, but only its own part is visible.
  That way the compositor only repaints the edges, not the whole area of the window.
- The border is hidden for fullscreen and minimized windows, panels and the desktop.
- The border windows are marked to skip Overview, the task switcher and the taskbar.

Quirks of KWin scripts:

- `visible` has no effect on windows declared in a script. Only `show()`/`hide()` work, and only after the script has finished loading.
- No QML bindings to KWin's window objects. On shutdown, KWin destroys windows and synchronously activates the next one,
  while its renderer is already gone. Touching windows or resizing the border windows at that point crashes KWin.
  Signals therefore only schedule `update()` via `Qt.callLater()`. During shutdown the event loop no longer runs,
  so nothing happens.
- QML files are cached per path. For testing, load each version from a new path with
  `org.kde.kwin.Scripting.loadDeclarativeScript` and start it with `/Scripting/ScriptN run`.

## Limitations

- The border sits above all windows. A menu or popup that extends past the window edge can overlap it or be overlapped by it.
- The animation keeps the compositor repainting constantly. To save battery, choose "Statisch" (static).

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).

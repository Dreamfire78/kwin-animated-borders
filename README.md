# Animated Borders – tacky-borders für KDE Plasma

KWin-Script (QML) für Plasma 6. Es zeichnet einen animierten Farbverlauf-Rand um das aktive Fenster.
Man muss nichts kompilieren, und das Script übersteht Plasma-Updates.

## Installieren / Aktualisieren

```bash
./install.sh
```

Nach einem **Update** einmal ab- und wieder anmelden. KWin hält den alten QML-Code bis zum Neustart im Speicher.

## Einstellungen

Systemeinstellungen → Fensterverwaltung → KWin-Scripte → „Animierte Fensterränder“ → Zahnrad.

| Einstellung | Bedeutung |
|---|---|
| Randstärke | Dicke des Rands in Pixeln |
| Abstand zum Fenster | Lücke zwischen Fenster und Rand |
| Eckenradius | Radius der Fensterecken (0 = eckig) |
| Animation | Rotieren, Rotieren rückwärts, Pulsieren, Statisch |
| Dauer pro Umlauf | Geschwindigkeit in Millisekunden |
| Farbe 1–4 | Verlaufsfarben als `#RRGGBB` oder `#AARRGGBB` |

Gespeicherte Einstellungen wirken nach etwa einer Sekunde. Die Einstellungsseite für KWin-Scripte sagt KWin nicht Bescheid,
dass sich `kwinrc` geändert hat. Deshalb richtet `install.sh` eine systemd-Path-Unit (`animatedborders-config.path`) ein:
Sobald sich der Abschnitt `[Script-animatedborders]` ändert, ruft sie `qdbus6 org.kde.KWin /KWin reconfigure` auf.
Das Script liest seine Einstellungen jede Sekunde neu ein.

## Entfernen

```bash
./uninstall.sh
```

## Funktionsweise

- Vier dünne, für Klicks durchlässige Overlay-Fenster (oben, unten, links, rechts) folgen der Geometrie von `Workspace.activeWindow`.
- Jedes Fenster zeichnet den ganzen Ring als `Shape` mit `ConicalGradient`, sichtbar ist aber nur sein eigener Ausschnitt.
  Dadurch muss der Compositor nur die Ränder neu zeichnen, nicht die ganze Fensterfläche.
- Bei Vollbild, minimierten Fenstern, Panels und dem Desktop wird der Rand ausgeblendet.

Eigenheiten von KWin-Scripts:

- `visible` wirkt bei Fenstern in einem Script nicht. Nur `show()`/`hide()` funktionieren, und das erst, nachdem das Script geladen ist.
- Keine QML-Bindings an KWins Fensterobjekte. Beim Beenden baut KWin die Fenster ab und aktiviert dabei synchron das nächste,
  obwohl das Rendering schon weg ist. Jeder Zugriff oder Größenwechsel der Randfenster in diesem Moment lässt KWin abstürzen.
  Signale planen deshalb nur `update()` per `Qt.callLater()` ein. Während des Beendens läuft die Ereignisschleife nicht mehr,
  also passiert dann nichts.
- QML-Dateien werden pro Pfad zwischengespeichert. Zum Testen deshalb jede Version unter einem neuen Pfad mit
  `org.kde.kwin.Scripting.loadDeclarativeScript` laden und mit `/Scripting/ScriptN run` starten.

## Grenzen

- Der Rand liegt über allen Fenstern. Ein Menü oder Popup, das über die Fensterkante hinausragt, kann ihn überdecken bzw. von ihm überdeckt werden.
- Die Animation sorgt dafür, dass der Compositor dauerhaft neu zeichnet. Wer Akku sparen will, wählt „Statisch“.

# Burgwacht

Ein Burgenbau-Spiel im Stil von Stronghold: Rohstoffe sammeln, eine Burg aufbauen und Angriffswellen abwehren.

## Starten

Voraussetzung: Godot 4.7 (`brew install --cask godot`).

```sh
tools/run.sh
```

Oder Godot öffnen, das Projekt importieren und auf ▶ klicken.

## Steuerung

| Aktion | Tasten |
|---|---|
| Burg gründen (zu Beginn) | Linksklick |
| Kamera bewegen | WASD / Pfeiltasten, zwei Finger auf dem Trackpad, rechte Maustaste ziehen |
| Zoomen | Pinch auf dem Trackpad, Mausrad |
| Pause / weiter | Leertaste |
| Geschwindigkeit 1× / 2× / 4× | 1 / 2 / 3 |
| Neue Karte | N |
| Schnell speichern / laden | F5 / F9 |
| Vollbild | F (im Vollbild auch Scrollen am Bildschirmrand) |

## Entwicklung

Tests: `tools/test.sh` · Aufbau: `docs/architecture.md` · Fahrplan: `docs/roadmap.md`.

## Lizenz

MIT, siehe [LICENSE](LICENSE).

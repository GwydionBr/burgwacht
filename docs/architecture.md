# Architektur

Godot 4.7, GDScript, isometrische 2D-Ansicht. Editor: `godot --path . -e`.

## Ordner

- `src/core/` – Spiellogik und Zustand, **ohne Darstellung**. Darf keine Nodes aus `view/` oder `ui/` kennen.
  - `iso.gd` – Umrechnung Kachel ↔ Weltkoordinaten (Kachel 64×32, Kachel (0,0) mittig bei (0,0))
  - `game_defs.gd` – lädt die Inhalte aus `data/*.json` (Singleton über `GameDefs.get_instance()`)
  - `map_data.gd` – Karte: Gelände pro Kachel, Rohstoffvorkommen; meldet Änderungen per Signal
  - `map_generator.gd` – erzeugt Karten deterministisch aus einem Seed
- `src/view/` – zeichnet den Zustand (alles prozedural mit `_draw`, noch keine Bilddateien). Objekte liegen im y-sortierten `Objects`-Node.
- `src/ui/` – Oberfläche (HUD), im Code aufgebaut.
- `src/main.gd` – verbindet Logik und Darstellung, Startparameter.
- `data/` – Spielinhalte als JSON.
- `tests/` – eigener kleiner Testrunner; jede `test_*.gd` erweitert `TestCase`, Methoden mit `test_`-Präfix laufen automatisch.

## Spielmodus

Freies Spiel mit Angriffswellen, mittlere Wirtschaft (Holz, Stein, Eisen, Nahrung, Gold, einige Produktionsketten).

## Export (später)

`*.json` muss im Export-Filter für Nicht-Ressourcen stehen.

# Burgwacht

Burgenbau-Strategiespiel im Stil von Stronghold für macOS. Godot 4.7, GDScript, isometrische 2D-Ansicht.
Spielmodus: freies Spiel mit Angriffswellen, mittlere Wirtschaft (Holz, Stein, Eisen, Nahrung, Gold, einige Produktionsketten).

## Befehle

- `tools/run.sh` – Spiel starten (`tools/run.sh -- --seed=42` für eine feste Karte)
- `tools/test.sh` – alle Tests headless ausführen (muss vor jedem Commit grün sein)
- `tools/screenshot.sh /tmp/bild.png [seed]` – Screenshot erzeugen, um Grafikänderungen zu prüfen
- Editor: `godot --path . -e`

## Architektur

- `src/core/` – Spiellogik und Zustand, **ohne Darstellung**. Darf keine Nodes aus `view/` oder `ui/` kennen.
  - `iso.gd` – Umrechnung Kachel ↔ Weltkoordinaten (Kachel 64×32, Kachel (0,0) mittig bei (0,0))
  - `game_defs.gd` – lädt die Inhalte aus `data/*.json` (Singleton über `GameDefs.get_instance()`)
  - `map_data.gd` – Karte: Gelände pro Kachel, Rohstoffvorkommen; meldet Änderungen per Signal
  - `map_generator.gd` – erzeugt Karten deterministisch aus einem Seed
- `src/view/` – zeichnet den Zustand (alles prozedural mit `_draw`, noch keine Bilddateien). Objekte liegen im y-sortierten `Objects`-Node.
- `src/ui/` – Oberfläche (HUD), im Code aufgebaut.
- `src/main.gd` – verbindet Logik und Darstellung, Startparameter.
- `data/` – Spielinhalte als JSON. Neue Gelände-, Rohstoff- oder Warentypen kommen hierher, nicht in den Code.
- `tests/` – eigener kleiner Testrunner; jede `test_*.gd` erweitert `TestCase`, Methoden mit `test_`-Präfix laufen automatisch.

## Konventionen

- Bezeichner auf Englisch, Kommentare und Spieltexte auf Deutsch.
- Statische Typisierung überall (`var x: int`, `:=`), keine Variant-Inferenz.
- Logik in `core/` testen; für Grafik einen Screenshot anschauen.
- Kleine Commits pro Feature.
- Beim Export (später): `*.json` muss im Export-Filter für Nicht-Ressourcen stehen.

## Fahrplan

1. ✅ Isometrische Karte, Kamera (Tastatur, Trackpad, Maus), Bäume/Felsen/Eisen, Kachel-Info
2. Bauen: Gebäude platzieren (Bergfried, Lager, Holzfäller, Steinbruch), Kosten, Bauvorschau
3. Bewohner: Wegfindung (AStarGrid2D), Arbeiter holen Rohstoffe und bringen sie ins Lager
4. Nahrung & Bevölkerung: Bauernhof, Kornspeicher, Wohnhäuser, Beliebtheit, Steuern
5. Produktionsketten: Weizen → Mühle → Bäcker, Eisen → Schmied → Waffen
6. Verteidigung: Mauern, Türme, Tore, Kaserne, Bogenschützen, Soldaten
7. Angriffswellen: Feinde laufen zur Burg, greifen Mauern an, werden stärker
8. Feinschliff: Speichern/Laden, Menüs, Sound, bessere Grafik, macOS-Export (.app)

## Agent skills

### Issue tracker

Issues liegen in GitHub Issues (`GwydionBr/burgwacht`), Zugriff über die `gh`-CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Standard-Labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: ein `CONTEXT.md` und `docs/adr/` im Repo-Root. See `docs/agents/domain.md`.

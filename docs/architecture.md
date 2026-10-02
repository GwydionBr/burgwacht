# Architektur

Godot 4.7, GDScript, isometrische 2D-Ansicht. Editor: `godot --path . -e`.

## Ordner

- `src/core/` – Spiellogik und Zustand, **ohne Darstellung**. Darf keine Nodes aus `view/` oder `ui/` kennen.
  - `iso.gd` – Umrechnung Kachel ↔ Weltkoordinaten (Kachel 64×32, Kachel (0,0) mittig bei (0,0))
  - `game_defs.gd` – lädt die Inhalte aus `data/*.json` (Singleton über `GameDefs.get_instance()`)
  - `map_data.gd` – Karte: Gelände pro Kachel, Vorkommen; meldet Änderungen per Signal
  - `map_generator.gd` – erzeugt Karten deterministisch aus einem Seed
  - `scenario.gd` – lädt und prüft ein Szenario aus `data/scenarios/<id>.json` (Fehler als deutscher Text in `error`)
  - `game_world.gd` – die Spielwelt: Wurzel des Zustands, Takt und Tag, einziger Zufallsgenerator; entsteht nur aus einem Szenario. Regeln: Vorkommen mit `spread` in `deposits.json` (Bäume) breiten sich auf freie, bebaubare Nachbarkacheln aus
- `src/view/` – zeichnet den Zustand (alles prozedural mit `_draw`, noch keine Bilddateien). Objekte liegen im y-sortierten `Objects`-Node.
- `src/ui/` – Oberfläche (HUD), im Code aufgebaut.
- `src/game_clock.gd` – treibt die Spielwelt an (Pause, 1×/2×/4×, begrenzte Takte pro Frame).
- `src/main.gd` – erzeugt die Spielwelt und verbindet sie mit Darstellung und Eingabe, Startparameter (`--scenario=`, `--seed=`, `--days=`). Keine Spiellogik.
- `data/` – Spielinhalte als JSON; `data/scenarios/` die Szenarien (Standard: `free_play`).
- `tests/` – eigener kleiner Testrunner; jede `test_*.gd` erweitert `TestCase`, Methoden mit `test_`-Präfix laufen automatisch.

## Spielwelt und Takt (ab Meilenstein 2)

Siehe `docs/adr/0001` bis `0004`. Kurz:

- Die **Spielwelt** ist die Wurzel des gesamten Spielzustands (Karte, Gebäude, Bewohner, Lager, Zeit, Zufallsgenerator). Sie entsteht aus einem **Szenario** (`data/scenarios/*.json`).
- Sie schreitet nur über `step()` um einen **Takt** voran (10 Takte = 1 Sekunde bei 1×). Ein Node außerhalb von `core/` ruft `step()` passend zur Spielgeschwindigkeit auf; die Darstellung interpoliert.
- Deterministisch: gleiches Szenario + gleiche Befehle = gleicher Verlauf. Zufall nur über den Generator der Spielwelt.
- Spielereingaben gehen als **Befehle** hinein, Änderungen als Signale hinaus. `view/` und `ui/` ändern den Zustand nie direkt.
- Der Zustand ist serialisierbar (Verweise über IDs). Jedes neue Zustandsstück bekommt einen Test „speichern → laden → gleicher Verlauf“.
- Gebäude: Werte in `data/buildings.json`, Ablauf über ein Verhalten aus einer festen Menge im Code.

## Tests

- Einzeltests für reine Logik (z. B. `Iso`, Kartengenerator).
- **Simulationstests** über die Spielwelt: Mini-Szenario laden, Befehle geben, N Takte laufen lassen, Ergebnis prüfen. Das ist die bevorzugte Teststelle. Die Mini-Szenarien liegen in `tests/scenarios/` (z. B. `tiny`: 20×16, Seed 7); `run_scenario("tiny", ticks)` bzw. `run_scenario_with_seed("tiny", ticks, seed)` aus `TestCase` laden eins, erzeugen die Spielwelt und lassen sie N Takte laufen.
- Grafik per Screenshot (`tools/screenshot.sh [bild] [seed] [szenario] [tage]`; mit Tagen läuft die Spielwelt vorher so lange).

## Spielmodus

Freies Spiel (Szenario ohne Ziel) mit endlosen Angriffswellen, mittlere Wirtschaft (Holz, Stein, Eisen, Nahrung, Gold, einige Produktionsketten). Szenarien mit Zielen und Aufträgen sind später möglich.

## Export (später)

`*.json` muss im Export-Filter für Nicht-Ressourcen stehen.

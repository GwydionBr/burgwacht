# Architektur

Godot 4.7, GDScript, isometrische 2D-Ansicht. Editor: `godot --path . -e`.

## Ordner

- `src/core/` – Spiellogik und Zustand, **ohne Darstellung**. Darf keine Nodes aus `view/` oder `ui/` kennen.
  - `iso.gd` – Umrechnung Kachel ↔ Weltkoordinaten (Kachel 64×32, Kachel (0,0) mittig bei (0,0))
  - `game_defs.gd` – lädt die Inhalte aus `data/*.json` (Singleton über `GameDefs.get_instance()`)
  - `map_data.gd` – Karte: Gelände pro Kachel, Vorkommen; meldet Änderungen per Signal
  - `map_generator.gd` – erzeugt Karten deterministisch aus einem Seed
  - `scenario.gd` – lädt und prüft ein Szenario aus `data/scenarios/<id>.json` (Fehler als deutscher Text in `error`)
  - `game_world.gd` – die Spielwelt: Wurzel des Zustands, Takt und Tag, einziger Zufallsgenerator, Gebäude, Lager und Bewohner; entsteht nur aus einem Szenario. Befehle über `execute()`, rein lesende Abfragen `placement_error()`/`founding_error()`/`build_error()`/`demolish_error()` (gemeinsam für Vorschau und Befehl), `founding_buildings()` für die Gründungsvorschau, `buildable_types()` für die Bauleiste, `is_walkable()` für Bewohner. Regeln: Vorkommen mit `spread` in `deposits.json` (Bäume) breiten sich auf freie, bebaubare Nachbarkacheln aus, nicht aber in Grundflächen und vor Eingänge. `to_data()`/`from_data()` für den Spielstand
  - `command.gd` – ein Befehl (Gründen, Bauen, Abreißen) für `GameWorld.execute()`
  - `building.gd` – ein Gebäude (ID, Typ, Ursprung, bei Lagern der Inhalt); Grundfläche, angrenzende Kacheln und Kachel vor dem Eingang aus `buildings.json` (Typen ohne `entrance` wie das Lagerfeuer haben keine)
  - `resident.gd` – ein Bewohner (ID, Position = Kachel + Ebene, zugeteilte Arbeitsstätte als ID; 0 = Untätiger)
- `src/view/` – zeichnet den Zustand (alles prozedural mit `_draw`, noch keine Bilddateien). Objekte (Vorkommen, Gebäudeblöcke, Lagerfeuer, Bewohnerfiguren) liegen im y-sortierten `Objects`-Node; `placement_preview.gd` zeigt die Bauvorschau und hebt beim Abriss das Gebäude unter der Maus hervor.
- `src/ui/` – Oberfläche (HUD mit Titelleiste samt „Bewohner N (Untätig M)“ und Bauleiste), im Code aufgebaut.
- `src/game_clock.gd` – treibt die Spielwelt an (Pause, 1×/2×/4×, begrenzte Takte pro Frame); steht während der Gründung.
- `src/main.gd` – erzeugt die Spielwelt und verbindet sie mit Darstellung und Eingabe, Startparameter (`--scenario=`, `--seed=`, `--found`, `--days=`), Gründung per Linksklick, Baumodus (Bauleiste oder L/H/B, Linksklick baut, Rechtsklick/Esc beendet), Abriss-Werkzeug (Bauleiste oder X, Linksklick reißt ohne Rückfrage ab), `--build=`/`--demolish`/`--hover=` für Screenshots, Schnellspeichern F5 / Laden F9 (`user://quicksave.sav`). Keine Spiellogik.
- `data/` – Spielinhalte als JSON (`terrain`, `deposits`, `goods`, `buildings`, `units`); `data/scenarios/` die Szenarien (Standard: `free_play`).
- `tests/` – eigener kleiner Testrunner; jede `test_*.gd` erweitert `TestCase`, Methoden mit `test_`-Präfix laufen automatisch.

## Spielwelt und Takt (ab Meilenstein 2)

Siehe `docs/adr/0001` bis `0004`. Kurz:

- Die **Spielwelt** ist die Wurzel des gesamten Spielzustands (Karte, Gebäude, Bewohner, Lager, Zeit, Zufallsgenerator). Sie entsteht aus einem **Szenario** (`data/scenarios/*.json`).
- Sie schreitet nur über `step()` um einen **Takt** voran (10 Takte = 1 Sekunde bei 1×). Ein Node außerhalb von `core/` ruft `step()` passend zur Spielgeschwindigkeit auf; die Darstellung interpoliert.
- Deterministisch: gleiches Szenario + gleiche Befehle = gleicher Verlauf. Zufall nur über den Generator der Spielwelt.
- Spielereingaben gehen als **Befehle** hinein, Änderungen als Signale hinaus. `view/` und `ui/` ändern den Zustand nie direkt.
- Der Zustand ist serialisierbar (Verweise über IDs). Jedes neue Zustandsstück bekommt einen Test „speichern → laden → gleicher Verlauf“.
- Gebäude: Werte in `data/buildings.json`, Ablauf über ein Verhalten aus einer festen Menge im Code. Jede Ware hat in `goods.json` ihre Lagerart (`storage`); Lager haben Lagerart und Fassungsvermögen.
- **Gründung**: Eine neue Spielwelt ist in Gründung – `step()` lässt keine Takte vergehen, nur der Gründungsbefehl ist erlaubt. Er setzt den Bergfried und seine Begleitgebäude (`companions` des Bergfrieds: Typ und Versatz – erstes Warenlager und Lagerfeuer), legt die Startwaren des Szenarios (`start_goods`) ins erste Lager (Überschuss verfällt) und stellt die Startbewohner (`start_residents`) als Untätige auf freie, begehbare Kacheln um das Lagerfeuer: nächste zuerst, bei gleichem Abstand im Uhrzeigersinn ab kleinerem y. Die Gründungsprüfung prüft alle Gebäude der Reihe nach; frühere Grundflächen und die Kacheln vor ihren Eingängen gelten für spätere als belegt.
- **Begehbarkeit** (`is_walkable()`): Gelände begehbar, kein Vorkommen mit `"walkable": false`, keine Grundfläche – außer Eingängen und Gebäuden mit `"walkable": true` (Lagerfeuer). Nur die Ebene Boden (ADR 0004).
- **Befehle** wirken sofort, auch ohne Takt; Ergebnis ist leer (Erfolg) oder ein deutscher Grund, ein abgelehnter Befehl ändert nichts. Prüfreihenfolge beim Platzieren: auf der Karte → Gelände bebaubar → keine Vorkommen → keine Gebäude → Kachel vor dem Eingang begehbar und frei; beim Bauen danach die Bauregeln des Typs und zuletzt genug Waren.
- **Bauen**: Baubar sind Typen mit `hotkey` in `buildings.json` (nicht der Bergfried). Kosten werden sofort aus den Lagern der passenden Lagerart entnommen, ältestes (kleinste ID) zuerst; der Bestand ist die Summe über alle Lager.
- **Bauregeln**: `rules` beim Gebäudetyp in `buildings.json`, je Regel `kind` und der deutsche Grund `reason`; gilt eine nicht, ist der Grund der ersten verletzten das Ergebnis. Arten: `next_to_same_storage` (grenzt an ein Lager derselben Lagerart – gibt es gerade keins, überall erlaubt) und `next_to_deposit` (grenzt an ein Vorkommen vom Typ `deposit`). „Grenzen“ heißt: Kachel direkt neben der Grundfläche mit gemeinsamer Kante, schräg zählt nicht (`Building.adjacent_tiles()`). Nur beim Bauen, nicht bei der Gründung.
- **Abriss**: Typen mit `demolish_forbidden` (Grund als Text; Bergfried, Lagerfeuer) nie, ein Lager nur leer. Die Hälfte der Baukosten je Ware (abgerundet) kommt in die Lager der passenden Lagerart, ältestes zuerst; was nicht passt, verfällt, der Abriss gelingt trotzdem. IDs werden nicht wiederverwendet.

## Spielstand

`GameWorld.to_data()` liefert den ganzen Zustand als reine Daten (Dictionaries, Arrays, Zahlen, Texte, Formatversion `SAVE_VERSION`), `GameWorld.from_data()` stellt daraus eine Spielwelt her; `GameWorld.data_error()` nennt auf Deutsch, warum Daten nicht passen (z. B. unbekannte Version). Jede Zustandsklasse hat ein eigenes `to_data()`/`from_data()` (`MapData`, `Deposit`, `Building`, `Resident`), die Spielwelt setzt sie zusammen. Gespeichert wird mit `FileAccess.store_var` (verlustfrei für 64-Bit-Zahlen wie den Zustand des Zufallsgenerators; JSON wäre es nicht).

Neues Zustandsstück:

1. Feld in `to_data()` und `from_data()` der zuständigen Klasse aufnehmen; Verweise als IDs, keine Darstellung.
2. Ist alter Spielstand damit nicht mehr ladbar, `SAVE_VERSION` erhöhen.
3. In `tests/test_save_load.gd` prüfen: speichern → laden → gleicher Zustand und nach N weiteren Takten derselbe Verlauf; dafür das Stück in `world_snapshot()` (`tests/test_case.gd`) aufnehmen.

## Tests

- Einzeltests für reine Logik (z. B. `Iso`, Kartengenerator).
- **Simulationstests** über die Spielwelt: Mini-Szenario laden, Befehle geben, N Takte laufen lassen, Ergebnis prüfen. Das ist die bevorzugte Teststelle. Die Mini-Szenarien liegen in `tests/scenarios/` (z. B. `tiny`: 20×16, Seed 7, 4 Startbewohner); `run_scenario("tiny", ticks)` bzw. `run_scenario_with_seed("tiny", ticks, seed)` aus `TestCase` laden eins, erzeugen die Spielwelt und lassen sie N Takte laufen.
- Neue Spielwelten aus `run_scenario…` sind schon gegründet (`found_castle()`: Stelle nächst der Kartenmitte); `new_world()` liefert eine in Gründung, `empty_world()` eine leergeräumte (nur Wiese) in Gründung; `founding_origin()` nennt den Ursprung eines Gebäudes der Gründung.
- Einzelne Testdateien: `tools/test.sh test_founding` (Teil des Dateinamens).
- Grafik per Screenshot (`tools/screenshot.sh [bild] [seed] [szenario] [tage] [--found]`; mit Tagen wird gegründet und die Spielwelt läuft vorher so lange, sonst zeigt das Bild die Gründungsvorschau über der Kartenmitte).

## Spielmodus

Freies Spiel (Szenario ohne Ziel) mit endlosen Angriffswellen, mittlere Wirtschaft (Holz, Stein, Eisen, Nahrung, Gold, einige Produktionsketten). Szenarien mit Zielen und Aufträgen sind später möglich.

## Export (später)

`*.json` muss im Export-Filter für Nicht-Ressourcen stehen.

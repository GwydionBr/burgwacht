# Coding Standards

Regeln für das Review eines Diffs. Was die Tests schon erzwingen (`core/` kennt nichts aus `view/`/`ui/`, jedes Skript lädt, Typangaben), steht hier nicht.

## Sprache

- Bezeichner (Klassen, Funktionen, Variablen, JSON-Schlüssel, IDs) auf Englisch.
- Kommentare, Doc-Kommentare, Spieltexte und Fehlermeldungen auf Deutsch, mit echten Umlauten und „deutschen Anführungszeichen“.
- Spieltexte und Kommentare verwenden die Begriffe aus `GLOSSARY.md`; ein Wort unter _Avoid_ ist ein Befund.

## Daten statt Code

- Neue Gelände-, Vorkommens-, Waren-, Gebäude- oder Einheitentypen und ihre Werte (Kosten, Größe, Farbe, Taste, Kategorie) stehen in `data/*.json`. Ein Spielwert als Literal in `src/` oder eine Fallunterscheidung nach Typ-ID, wo ein Datenfeld reichen würde, ist ein Befund; eine benannte Konstante für eine Sonderrolle (wie `GameWorld.FOUNDING_TYPE`) ist in Ordnung.
- Verhalten, das kein Datenwert ausdrücken kann, folgt `docs/adr/0003-gebaeude-daten-und-verhalten.md`.

## Logik und Darstellung

- Spielregeln stehen in `src/core/`; `view/` und `ui/` fragen sie ab, statt sie nachzubauen. Prüft die Oberfläche selbst, ob etwas erlaubt oder bezahlbar ist, ist das ein Befund.
- Ob ein Befehl gültig ist, entscheidet eine `*_error()`-Abfrage in `core/`, die Vorschau und Befehl gemeinsam nutzen; sie liefert einen leeren String oder den deutschen Grund.
- Zustandsänderungen laufen über `GameWorld.execute()` mit einem `Command` (deterministisch, siehe `docs/adr/0001-deterministische-taktsimulation.md`).

## Dokumentation im Code

- Jede Datei beginnt nach `class_name`/`extends` mit einem `##`-Doc-Kommentar, der sagt, wofür sie da ist. Ändert sich der Zweck, ändert sich der Kommentar mit.
- Öffentliche Funktionen und Konstanten haben einen `##`-Kommentar, wenn ihr Name nicht alles sagt.

## Tests und Prüfbarkeit

- Neue oder geänderte Logik in `core/` hat einen Test in `tests/`.
- Eine neue Ansicht oder ein neuer Startparameter hat ein Preset in `tools/presets.json`.

## Commits

- Ein Commit pro Feature; Daten, Logik und Oberfläche einer Änderung dürfen zusammen gehen, unabhängige Änderungen nicht.
- Commit-Betreff auf Deutsch, ohne Punkt am Ende.

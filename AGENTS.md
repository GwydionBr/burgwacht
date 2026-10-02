# Burgwacht

Burgenbau-Strategiespiel im Stil von Stronghold für macOS. Godot 4.7, GDScript, isometrische 2D-Ansicht.

## Befehle

- `tools/test.sh` – alle Tests headless (muss vor jedem Commit grün sein)
- `tools/run.sh` – Spiel starten (`tools/run.sh -- --seed=42` für feste Karte)
- `tools/screenshot.sh /tmp/bild.png [seed]` – Screenshot, um Grafikänderungen zu prüfen

## Regeln

- `src/core/` ist reine Logik und kennt nichts aus `view/` oder `ui/`.
- Neue Gelände-, Vorkommens-, Waren- oder Gebäudetypen gehören nach `data/*.json`, nicht in den Code.
- Bezeichner auf Englisch, Kommentare und Spieltexte auf Deutsch.
- Statische Typisierung überall, keine Variant-Inferenz.
- Logik in `core/` testen; Grafik per Screenshot prüfen. Kleine Commits pro Feature.

## Weiterlesen bei Bedarf

- `docs/architecture.md` – Aufbau, Dateien, Testrunner
- `docs/roadmap.md` – Meilensteine und aktueller Stand

## Agent skills

- Issue tracker: GitHub Issues über `gh`. See `docs/agents/issue-tracker.md`.
- Triage labels: Standard-Labels. See `docs/agents/triage-labels.md`.
- Domain docs: single-context. See `docs/agents/domain.md`.

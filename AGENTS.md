# Burgwacht

Burgenbau-Strategiespiel im Stil von Stronghold für macOS. Godot 4.7, GDScript, isometrische 2D-Ansicht.

## Befehle

- `tools/test.sh` – alle Tests headless, danach der Rauchtest (muss vor jedem Commit grün sein)
- `tools/run.sh` – Spiel starten (`tools/run.sh -- --seed=42` für feste Karte, `tools/run.sh barracks` für einen Testzustand)
- `tools/screenshot.sh /tmp/bild.png [seed|preset]` – Screenshot, um Grafikänderungen zu prüfen
- `tools/export.sh` – macOS-App nach `export/Burgwacht.app` exportieren und einmal headless starten (braucht die Export-Templates der installierten Godot-Version, nicht in der CI)
- Testzustände (Presets) stehen in `tools/presets.json`; neue Ansicht oder neuer Startparameter → dort ein Preset ergänzen (der Rauchtest prüft alle)

## Regeln

- `src/core/` ist reine Logik und kennt nichts aus `view/` oder `ui/`.
- Neue Gelände-, Vorkommens-, Waren- oder Gebäudetypen gehören nach `data/*.json`, nicht in den Code.
- Statische Typisierung überall, keine Variant-Inferenz (fehlende Typangabe ist ein Parse-Fehler).
- Logik in `core/` testen; Grafik per Screenshot prüfen.
- Vor dem PR `/code-review` seit `main` laufen lassen und die Befunde beheben; die Regeln dafür stehen in `CODING_STANDARDS.md`.

## Weiterlesen bei Bedarf

- `docs/architecture.md` – Aufbau, Dateien, Testrunner
- `docs/roadmap.md` – Meilensteine und aktueller Stand

## Agent skills

- Issue tracker: GitHub Issues über `gh`. See `docs/agents/issue-tracker.md`.
- Triage labels: Standard-Labels. See `docs/agents/triage-labels.md`.
- Domain docs: single-context. See `docs/agents/domain.md`.

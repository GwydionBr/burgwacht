# Sprites aus CC0-3D-Modellen, selbst gerendert

Die Grafik soll vollständig (Gelände, Vorkommen, alle Gebäude, Figuren mit Animationen in 8 Richtungen), in sich einheitlich und frei von Lizenzpflichten sein. Kein freier 2D-Satz leistet das. Deshalb rendern wir die Sprites selbst mit einem Blender-Skript und einer orthografischen Isokamera (genau 2:1) aus CC0-3D-Modellen (KayKit, Quaternius, Kenney). Fehlende Typen setzen wir aus deren Einzelteilen zusammen. Dafür nehmen wir einen stilisierten Low-Poly-Look in Kauf, statt realistisch auszusehen wie Stronghold. Jeder Typ ist als Textrezept beschrieben (JSON in `tools/render/recipes/`); eine `.blend`-Szene gibt es nur, wo echtes Modellieren nötig ist. Rezepte, Modelle, Szenen und die gerenderten PNGs liegen im Repo, und die Quellen stehen in `CREDITS.md`.

## Considered Options

- **Flare-Grafik (Clint Bellanger)**: realistisch vorgerendert und genau im 64×32-Raster, aber unter CC-BY-SA. Es fehlen Arbeiter, Soldaten, Betriebe und Tiere; ein zweiter Satz würde den Stil brechen.
- **Reiner's Tilesets**: inhaltlich fast vollständig und im Stil von Siedler und Stronghold, aber unter eigener Lizenz mit Namensnennung und Verbot der Weitergabe über Sammelseiten. Die Projektion ist 4:3 statt 2:1, die Bilder stammen von 2002–07.
- **KI-generierte Bilder**: Lizenzlage und Einheitlichkeit über alle Typen und Richtungen hinweg sind unsicher.
- **Rendern in Godot statt Blender**: Das bräuchte kein weiteres Werkzeug, aber Blender liefert bessere Beleuchtung und Schatten.

## Consequences

- Blender muss installiert sein, um Sprites neu zu rendern. Spiel, Tests und CI brauchen es nicht, weil die PNGs eingecheckt sind.
- Das Render-Skript verlangt genau Blender 5.2 LTS (Haupt- und Unterversion) und bricht sonst ab, damit die Bilder nicht von Version zu Version leicht abweichen.
- Typen ohne Sprite zeichnet die Ansicht weiter prozedural. Neue Typen bleiben damit allein über `data/*.json` möglich, auch bevor es ein Bild gibt.

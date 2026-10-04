# Fahrplan

Jeder Meilenstein ist eine spielbare Scheibe: Am Ende läuft das Spiel und zeigt das Neue. Begriffe wie in `GLOSSARY.md`, Grundsatzentscheidungen in `docs/adr/`. Pro Meilenstein gibt es ein GitHub-Issue; eine ausführliche Spezifikation und Teil-Issues entstehen erst kurz vor dem Start.

1. ✅ **Karte**: Isometrische Karte, Kamera (Tastatur, Trackpad, Maus), Bäume/Felsen/Eisen, Kachel-Info
2. ✅ **Fundament**: Spielwelt mit festem Takt (10/s), Pause und Zeitraffer, Tag als Zeiteinheit, Partie startet aus einem Szenario, Umbenennung Ressource → Vorkommen, Bäume wachsen nach, Spielwelt lässt sich (intern) speichern und laden
3. ✅ **Bauen**: Befehle; Gebäude aus `buildings.json` mit Verhalten; Bergfried, Lager, Holzfäller, Steinbruch platzieren; Kosten werden sofort abgezogen; Bauvorschau; Abriss (50 % zurück); Lager mit Lagerarten
4. **Bewohner**: Wegfindung mit Ebenen, Gebäude blockieren außer am Eingang; Lagerfeuer mit Untätigen; Arbeiter bauen Vorkommen ab und tragen Waren sichtbar ins Lager
5. **Nahrung & Bevölkerung**: Apfelplantage, Jäger, Kornspeicher, Wohnhäuser (Wohnraum); Nahrungsverbrauch pro Tag; Beliebtheit aus Faktoren (Nahrungsmenge, Vielfalt, Steuern); Bewohner kommen und gehen
6. **Produktionsketten & Markt**: Weizen → Mühle → Bäcker; Eisen → Schmied → Waffen; Waffenkammer; Markt mit festen Preisen
7. **Verteidigung**: Mauern, Türme und Tore (begehbar, Ebene); Kaserne wirbt Untätige mit Waffen zu Soldaten an; Soldaten auswählen, bewegen, angreifen
8. **Angriffswellen**: Feinde aus `units.json`; Wellenplan im Szenario mit Schonfrist und Steigerungsformel; Ankündigung mit Richtung und Countdown; Räuber (Nahkampf) und Wilderer (Fernkampf); Feinde laufen zum Bergfried und greifen Hindernisse an; Gebäude haben Lebenspunkte; Niederlage, wenn der Bergfried fällt
9. **Feinschliff**: Speichern/Laden im Menü, Hauptmenü und Szenarioauswahl, Sound, Sprites statt Platzhaltergrafik, macOS-Export (.app)

## Später denkbar

- Ziele und Aufträge in Szenarien (das Modell ist dafür vorbereitet)
- Förster, Reparatur von Gebäuden, Belagerungswaffen

## Bewusst nicht geplant (vorerst)

Kriegsnebel, Feuer und Krankheit, Jahreszeiten, Straßen, mehrere Spieler, KI-Burg als Gegner.

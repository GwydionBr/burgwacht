# Deterministische Taktsimulation mit Befehlen

Die Spielwelt in `src/core/` schreitet in festen Takten voran (nicht per `_process(delta)` in einzelnen Nodes) und ist aus Seed + Befehlsfolge exakt reproduzierbar: ein einziger Zufallsgenerator im Spielzustand, keine Abhängigkeit von Framerate, globalem `randi()` oder unsortierter Iterationsreihenfolge. Spielereingaben gelangen nur als Befehle hinein, Änderungen gehen als Signale hinaus; die Darstellung interpoliert zwischen Takten. So lassen sich Wirtschaft und Kampf über viele Takte headless testen, Pause/Zeitraffer sind trivial und Fehler sind per Seed nachstellbar.

## Consequences

- Kein Spielcode in `view/` darf Spielzustand verändern; er schickt Befehle.
- Wer in `core/` Zufall braucht, nimmt den Generator der Spielwelt.
- Über Dictionaries wird nur in definierter Reihenfolge iteriert, wenn das Ergebnis davon abhängt.

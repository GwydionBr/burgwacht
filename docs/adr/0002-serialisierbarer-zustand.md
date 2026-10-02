# Spielzustand von Anfang an serialisierbar

Obwohl Speichern/Laden erst im letzten Meilenstein als Funktion kommt, wird der Zustand der Spielwelt ab sofort als reine Daten gebaut: Objekte verweisen über IDs aufeinander statt über Objektreferenzen, Darstellungsdaten gehören nicht dazu. Ein Test „speichern → laden → gleicher Zustand (und gleicher weiterer Verlauf)“ begleitet jedes neue Zustandsstück. Nachrüsten wäre bei einem Aufbauspiel mit vielen verflochtenen Objekten sehr teuer.

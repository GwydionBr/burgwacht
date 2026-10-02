# Burgwacht

Burgenbau-Strategiespiel: Der Spieler baut auf einer zufällig erzeugten Karte eine Burg mit Wirtschaft auf und verteidigt sie gegen immer stärkere Angriffswellen.

## Sprache

### Partie

**Partie**:
Ein Spieldurchlauf auf einer Karte, vom Start bis zur Niederlage (oder bis ein Ziel erfüllt ist).
_Avoid_: Spiel, Runde, Level

**Spielwelt**:
Der gesamte Zustand einer Partie: Karte, alles darauf, Lager, Zeit und Zufall.
_Avoid_: Spielstand, State

**Takt**:
Der kleinste Zeitschritt der Spielwelt; alles Geschehen schreitet Takt für Takt voran.
_Avoid_: Frame, Tick (im Deutschen)

**Befehl**:
Eine Absicht des Spielers, die an die Spielwelt übergeben wird, z. B. „Gebäude bauen“.
_Avoid_: Aktion, Kommando

**Niederlage**:
Das Ende einer Partie, weil der Bergfried zerstört wurde.

**Ziel**:
Eine prüfbare Bedingung, deren Erfüllung eine Partie gewinnt. Im freien Spiel gibt es keines.
_Avoid_: Siegbedingung, Quest

**Auftrag**:
Eine optionale Aufgabe während einer Partie, deren Erfüllung eine Belohnung bringt, die Partie aber nicht beendet.
_Avoid_: Quest, Mission, Nebenziel

**Bedingung**:
Eine prüfbare Aussage über die Spielwelt (z. B. „50 Brot im Kornspeicher“), auf der Ziele und Aufträge aufbauen.

**Szenario**:
Die Datenbeschreibung, aus der eine Partie startet: Karte, Startwaren, Startbewohner, Wellenplan, Ziele und Aufträge. Das freie Spiel ist ein Szenario ohne Ziel.
_Avoid_: Level, Mission, Karte

**Gründung**:
Der Beginn einer Partie: Die Zeit steht still, bis der Spieler den Bergfried gesetzt hat; mit ihm entstehen das erste Warenlager und der erste Kornspeicher mit den Startwaren sowie das Lagerfeuer, an dem die Startbewohner als Untätige stehen.
_Avoid_: Aufbauphase, Start

**Tag**:
Feste Anzahl Takte, im Rhythmus derer Steuern, Beliebtheit, Nahrungsverbrauch und Wellen abgerechnet werden.
_Avoid_: Runde, Zyklus

### Karte

**Karte**:
Das rechteckige Kachelraster einer Partie mit Gelände und Vorkommen.
_Avoid_: Map, Level

**Kachel**:
Ein Feld der Karte mit genau einem Gelände.
_Avoid_: Tile, Feld, Zelle

**Gelände**:
Die Bodenart einer Kachel; bestimmt, ob man darauf gehen und bauen kann.
_Avoid_: Terrain, Boden

**Ebene**:
Die Höhenstufe, auf der sich jemand auf einer Kachel befindet: Boden oder auf einer Mauer bzw. einem Turm.
_Avoid_: Höhe, Stockwerk, Layer

**Vorkommen**:
Ein abbaubares Objekt auf einer Kachel (Baum, Felsen, Eisenvorkommen, Wild), das eine begrenzte Menge eines Rohstoffs liefert.
_Avoid_: Ressource, Resource Node, Rohstoffquelle

### Wirtschaft

**Ware**:
Alles, was gelagert und transportiert werden kann, z. B. Holz, Mehl, Schwert.
_Avoid_: Gut, Item, Ressource

**Rohstoff**:
Eine Ware, die direkt aus einem Vorkommen gewonnen wird (Holz, Stein, Eisen). Eigenschaft einer Ware, kein eigener Typ.
_Avoid_: Ressource

**Lager**:
Oberbegriff für ein Gebäude, in dem Waren einer bestimmten Lagerart physisch liegen; ist es voll, kann dorthin nichts mehr geliefert werden.
_Avoid_: Speicher (allein), Inventar, Bestand

**Lagerart**:
Die Sorte Lager, in die eine Ware gehört (Warenlager, Kornspeicher, Waffenkammer); jede Ware hat genau eine.

**Warenlager**:
Das Lager für Rohstoffe und andere Waren, die weder Nahrung noch Waffen sind.
_Avoid_: Lager (für dieses konkrete Gebäude), Stockpile

**Schatz**:
Das Gold der Burg; liegt im Bergfried und ist keine Ware.
_Avoid_: Gold als Ware, Kasse

**Nahrung**:
Eine Ware, die Bewohner essen (Äpfel, Fleisch, später Brot); ihre Lagerart ist der Kornspeicher.
_Avoid_: Essen, Proviant, Lebensmittel

**Kornspeicher**:
Das Lager für Nahrung.
_Avoid_: Speisekammer, Vorratslager

**Wild**:
Ein Vorkommen aus Tieren, das Fleisch liefert und wie Bäume nachwächst; es bewegt sich nicht.
_Avoid_: Tiere, Hirsche, Beute

**Ration**:
Die vom Spieler eingestellte Stufe, wie viel Nahrung jeder Bewohner pro Tag isst (keine, halb, normal, extra, doppelt).
_Avoid_: Portion, Essensmenge

**Steuersatz**:
Die vom Spieler eingestellte Stufe, wie viel Gold jeder Bewohner pro Tag in den Schatz zahlt.
_Avoid_: Abgaben, Steuerstufe

### Gebäude und Bewohner

**Gebäude**:
Ein vom Spieler platziertes Bauwerk, das eine oder mehrere Kacheln belegt.
_Avoid_: Building, Haus (allgemein)

**Grundfläche**:
Das Rechteck aus Kacheln, das ein Gebäude belegt; Gebäude werden nicht gedreht.
_Avoid_: Footprint, Fläche

**Bauregel**:
Eine Bedingung aus den Daten eines Gebäudetyps, wo er stehen darf, z. B. „grenzt an Felsen“. **Grenzen** heißt: eine Kachel direkt neben der Grundfläche, mit gemeinsamer Kante; schräg zählt nicht.
_Avoid_: Bauvoraussetzung, Platzierungsregel

**Abriss**:
Das Entfernen eines Gebäudes durch den Spieler; die Hälfte der Baukosten kommt zurück.
_Avoid_: Abbau (das ist das Gewinnen von Rohstoffen), Löschen

**Bergfried**:
Das zentrale Gebäude der Burg; fällt es, ist die Partie verloren.
_Avoid_: Burg, Hauptgebäude, Keep

**Eingang**:
Die Kachel, über die ein Gebäude betreten und beliefert wird.
_Avoid_: Tür, Zugang

**Verhalten**:
Die Art, wie ein Gebäude arbeitet (abbauen, herstellen, anbauen, lagern, wohnen, verteidigen); aus einer kleinen festen Menge.
_Avoid_: Gebäudetyp, Kategorie

**Arbeitsstätte**:
Ein Gebäude, das Arbeiter beschäftigt.
_Avoid_: Betrieb, Werkstatt (allgemein)

**Bewohner**:
Jede Person, die zur Burg gehört.
_Avoid_: Siedler, Bauer, Peasant, Einwohner

**Arbeiter**:
Ein Bewohner, der einer Arbeitsstätte zugeteilt ist.
_Avoid_: Angestellter, Worker

**Untätiger**:
Ein Bewohner ohne Arbeitsstätte, der am Lagerfeuer auf Arbeit wartet; er wird automatisch einer freien Arbeitsstätte zugeteilt.
_Avoid_: Arbeitsloser, Faulenzer

**Lagerfeuer**:
Das Gebäude, das mit dem Bergfried bei der Gründung entsteht und an dem die Untätigen stehen; weder baubar noch abreißbar.
_Avoid_: Sammelpunkt, Feuerstelle

**Abbau**:
Das Gewinnen von Rohstoffen aus einem Vorkommen durch einen Arbeiter; ist ein Vorkommen erschöpft, verschwindet es.
_Avoid_: Ernte, Abriss (das ist das Entfernen eines Gebäudes)

**Traglast**:
Die Menge einer Ware, die ein Arbeiter auf einmal trägt.
_Avoid_: Ladung, Kapazität

**Beliebtheit**:
Wert von 0 bis 100, wie gern Bewohner in der Burg leben; bestimmt, ob Bewohner kommen oder gehen. Sie ändert sich jeden Tag um die Summe ihrer Faktoren.
_Avoid_: Zufriedenheit, Stimmung, Ansehen

**Faktor**:
Ein Beitrag zur täglichen Änderung der Beliebtheit, z. B. Ration, Vielfalt der Nahrung, Steuersatz.
_Avoid_: Modifikator, Einfluss

**Wohnhaus**:
Ein Gebäude, das den Wohnraum erhöht; Bewohner wohnen nicht sichtbar darin.
_Avoid_: Hütte, Haus

**Wohnraum**:
Die Zahl der Bewohner, die die Burg insgesamt beherbergen kann; der Bergfried stellt einen Grundwohnraum, jedes Wohnhaus mehr.
_Avoid_: Bevölkerungslimit, Kapazität

### Kampf

**Soldat**:
Ein Bewohner, der mit Waffen angeworben wurde und kämpft statt zu arbeiten.
_Avoid_: Einheit, Krieger, Truppe

**Feind**:
Ein angreifender Kämpfer, der nicht zur Burg gehört.
_Avoid_: Gegner, Angreifer, Mob

**Welle**:
Eine Gruppe von Feinden, die gemeinsam zu einem bestimmten Zeitpunkt am Kartenrand erscheint.
_Avoid_: Angriff, Invasion

**Wellenplan**:
Die Festlegung im Szenario, wann welche Wellen mit welchen Feinden von wo kommen.

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
Die Höhenstufe, auf der sich jemand auf einer Kachel befindet: Boden oder Wehrgang.
_Avoid_: Höhe, Stockwerk, Layer

**Wehrgang**:
Die erhöhte Ebene oben auf Mauern, Toren und Türmen; erreichbar über Treppen und Türme, betreten nur von Soldaten und Feinden. Mauer und Turm liegen gleich hoch, der Turm gibt nur mehr Reichweite.
_Avoid_: Mauerkrone, Zinnen

**Vorkommen**:
Ein abbaubares Objekt auf einer Kachel (Baum, Felsen, Eisenvorkommen, Wild), das eine begrenzte Menge eines Rohstoffs liefert.
_Avoid_: Ressource, Resource Node, Rohstoffquelle

### Wirtschaft

**Ware**:
Alles, was gelagert und transportiert werden kann, z. B. Holz, Mehl, Schwert.
_Avoid_: Gut, Item, Ressource

**Rohstoff**:
Eine Ware, die direkt aus einem Vorkommen gewonnen wird (Holz, Stein, Eisen, Fleisch). Eigenschaft einer Ware, kein eigener Typ; ein Rohstoff kann zugleich Nahrung sein.
_Avoid_: Ressource

**Lager**:
Oberbegriff für ein Gebäude, in dem Waren einer bestimmten Lagerart physisch liegen; ist es voll, kann dorthin nichts mehr geliefert werden.
_Avoid_: Speicher (allein), Inventar, Bestand

**Lagerart**:
Die Sorte Lager, in die eine Ware gehört (Warenlager, Kornspeicher, Waffenkammer); jede Ware hat genau eine.

**Warenlager**:
Das Lager für alle Waren, die weder Nahrung noch Waffen sind, also auch für die meisten Rohstoffe.
_Avoid_: Lager (für dieses konkrete Gebäude), Stockpile

**Schatz**:
Das Gold der Burg; liegt im Bergfried und ist keine Ware.
_Avoid_: Gold als Ware, Kasse

**Nahrung**:
Eine Ware, die Bewohner essen (Äpfel, Fleisch, Brot); ihre Lagerart ist der Kornspeicher.
_Avoid_: Essen, Proviant, Lebensmittel

**Kornspeicher**:
Das Lager für Nahrung.
_Avoid_: Speisekammer, Vorratslager

**Waffe**:
Eine Ware, mit der ein Untätiger zum Soldaten angeworben wird (Schwert, Bogen); ihre Lagerart ist die Waffenkammer.
_Avoid_: Ausrüstung, Bewaffnung

**Waffenkammer**:
Das Lager für Waffen.
_Avoid_: Arsenal, Rüstkammer

**Markt**:
Ein Gebäude ohne Arbeiter; steht mindestens eins, kann der Spieler Waren gegen Gold aus dem Schatz kaufen und verkaufen.
_Avoid_: Handelsposten, Händler

**Handel**:
Ein Kauf oder Verkauf einer festen Menge einer Ware am Markt zu den festen Preisen aus den Warendaten; er gelingt ganz oder gar nicht.
_Avoid_: Tausch, Transaktion

**Marktansicht**:
Die Übersicht (Taste M) mit Bestand, Kauf- und Verkaufspreis jeder Ware; zugleich die Bestandsübersicht, auch ohne Markt (dann ohne Handel).
_Avoid_: Inventar, Handelsfenster

**Wild**:
Ein Vorkommen aus Tieren, das Fleisch liefert und wie Bäume nachwächst; es bewegt sich nicht.
_Avoid_: Tiere, Hirsche, Beute

**Rudel**:
Eine zusammenhängende Gruppe von Wild-Kacheln (3–6), wie sie die Kartenerzeugung setzt; Rudel berühren einander nicht, auch nicht schräg.
_Avoid_: Herde, Gruppe

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
Eine Bedingung aus den Daten eines Gebäudetyps, wo er stehen darf, z. B. „grenzt an Felsen“ oder „nur auf Wiese“. **Grenzen** heißt: eine Kachel direkt neben der Grundfläche, mit gemeinsamer Kante; schräg zählt nicht.
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
Ein Bewohner ohne Arbeitsstätte, der am Lagerfeuer auf Arbeit wartet; er wird automatisch einer freien Arbeitsstätte zugeteilt. Ankommende und Gehende sind keine Untätigen.
_Avoid_: Arbeitsloser, Faulenzer

**Ankommender**:
Ein neuer Bewohner, der bei hoher Beliebtheit am Kartenrand erscheint und zum Lagerfeuer geht, wo er Untätiger wird; er zählt ab seinem Erscheinen als Bewohner.
_Avoid_: Ankömmling, Neuling, Zuwanderer

**Gehender**:
Ein Bewohner, der bei niedriger Beliebtheit oder zu wenig Wohnraum die Burg verlässt und zum Kartenrand geht, wo er verschwindet; er zählt schon ab dem Aufbruch nicht mehr als Bewohner. Soldaten werden nie zu Gehenden.
_Avoid_: Auswanderer, Flüchtling

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

**Vielfalt**:
Ein Faktor: wie viele Nahrungssorten die Bewohner an einem Tag gegessen haben; jede Sorte über die erste hinaus hebt die Beliebtheit.
_Avoid_: Abwechslung

**Verwaltung**:
Die Ansicht, in der der Spieler Ration und Steuersatz einstellt und die Faktoren der Beliebtheit aufgeschlüsselt sieht.
_Avoid_: Menü, Burgverwaltung

**Hof**:
Eine Arbeitsstätte, deren Arbeiter darin arbeitet und die Ware selbst erzeugt, ohne Vorkommen (Verhalten `farm`), z. B. die Apfelplantage.
_Avoid_: Farm, Bauernhof

**Herstellungsbetrieb**:
Eine Arbeitsstätte, deren Arbeiter eine Eingangsware aus einem Lager holt und daraus darin ein Erzeugnis herstellt (Verhalten `produce`), z. B. Mühle, Bäcker, Schmied.
_Avoid_: Werkstatt, Fabrik, Verarbeiter

**Eingangsware**:
Die Ware, die ein Herstellungsbetrieb verbraucht, z. B. Weizen bei der Mühle.
_Avoid_: Input, Rohware

**Erzeugnis**:
Die Ware, die eine Arbeitsstätte liefert; jeder Gebäudetyp hat genau eines.
_Avoid_: Produkt, Output

**Apfelplantage**:
Ein Hof auf Wiese, dessen Arbeiter darin Äpfel anbaut und sie zum nächsten Kornspeicher trägt; braucht kein Vorkommen.
_Avoid_: Obstgarten, Farm

**Wohnhaus**:
Ein Gebäude, das den Wohnraum erhöht; Bewohner wohnen nicht sichtbar darin.
_Avoid_: Hütte, Haus

**Wohnraum**:
Die Zahl der Bewohner, die die Burg insgesamt beherbergen kann; der Bergfried stellt einen Grundwohnraum, jedes Wohnhaus mehr.
_Avoid_: Bevölkerungslimit, Kapazität

### Kampf

**Soldat**:
Ein Bewohner, der mit Waffen angeworben wurde und kämpft statt zu arbeiten; er belegt Wohnraum, isst und zahlt Steuern wie jeder Bewohner.
_Avoid_: Einheit, Krieger, Truppe

**Soldatentyp**:
Die Art eines Soldaten mit eigenen Kampfwerten und eigenen Anwerbekosten; heute Schwertkämpfer (Nahkampf, Schwert) und Bogenschütze (Fernkampf, Bogen).
_Avoid_: Einheitentyp, Klasse

**Anwerben**:
Ein Befehl an einer Kaserne, der einen Untätigen gegen Waffen (und Gold) zum Soldaten macht; er gelingt ganz oder gar nicht. Der Untätige ist ab dem Befehl Soldat und läuft zur Kaserne.
_Avoid_: Rekrutieren, Ausbilden

**Kaserne**:
Ein Gebäude ohne Arbeiter, an dem Soldaten angeworben werden.
_Avoid_: Barracke, Trainingslager

**Mauer**:
Ein 1×1-Gebäude, das am Boden den Weg versperrt und oben Wehrgang trägt; wird als gerade Linie gezogen, jede Kachel ist ein eigenes Gebäude.
_Avoid_: Wall, Palisade

**Turm**:
Ein Gebäude, dessen ganze Grundfläche Wehrgang ist; sein Eingang am Boden führt hinauf, aber nur für eigene Leute. Gibt Soldaten darauf zusätzliche Reichweite; darf auch ohne Mauer stehen.
_Avoid_: Wachturm, Bastion

**Tor**:
Ein 1×1-Gebäude in einer Mauerlinie, durch das eigene Leute am Boden gehen, Feinde aber nicht; oben trägt es Wehrgang.
_Avoid_: Torhaus, Pforte

**Treppe**:
Ein billiges Gebäude neben Mauer, Tor oder Turm, das Boden und Wehrgang verbindet; auch Feinde können sie benutzen.
_Avoid_: Aufgang, Leiter

**Posten**:
Die Position, zu der ein Soldat zuletzt befohlen wurde (anfangs die Kaserne); dorthin kehrt er nach selbstständigem Kämpfen zurück. Nahkämpfer verfolgen Feinde nur bis zu einer festen Entfernung vom Posten.
_Avoid_: Stellung, Wachposten

**Leine**:
Wie weit ein Nahkämpfer einen Feind beim selbstständigen Verteidigen höchstens verfolgt, gemessen vom Posten; ein ausdrücklicher Angriff hat keine Leine.
_Avoid_: Verfolgungsradius, Reichweite

**Selbstständiges Verteidigen**:
Was ein Soldat ohne Befehl tut: Bogenschützen schießen vom Platz aus auf den nächsten Feind in Reichweite, Schwertkämpfer greifen den nächsten erreichbaren Feind in Sichtweite an (an der Leine) und kehren danach zum Posten zurück.
_Avoid_: Automatik, KI, Wachmodus

**Auswahl**:
Die Soldaten, die der Spieler gerade per Klick oder Rahmen gewählt hat und denen er Bewegen und Angreifen befiehlt.
_Avoid_: Selektion, Gruppe

**Figur**:
Jeder, der sich auf der Karte bewegt: Bewohner und Feinde.
_Avoid_: Einheit, Unit, Akteur

**Kämpfer**:
Eine Figur mit Lebenspunkten, die angreift und angegriffen wird: Soldaten und Feinde.
_Avoid_: Einheit, Krieger

**Feind**:
Ein angreifender Kämpfer, der nicht zur Burg gehört, z. B. der Räuber (Nahkampf).
_Avoid_: Gegner, Angreifer, Mob

**Welle**:
Eine Gruppe von Feinden, die gemeinsam zu einem bestimmten Zeitpunkt am Kartenrand erscheint.
_Avoid_: Angriff, Invasion

**Wellenplan**:
Die Festlegung im Szenario, wann welche Wellen mit welchen Feinden von wo kommen.

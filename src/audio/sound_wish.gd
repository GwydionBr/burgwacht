class_name SoundWish
extends RefCounted
## Ein Abspielwunsch der Tonregie (SoundDirector) an die Tonausgabe: welches Geräusch in welcher
## Variante, wie laut, wo im Panorama und mit welcher Tonhöhe. Reine Daten.

## Der Geräuschanlass aus SoundData.OCCASIONS.
var occasion := ""
## Die Variante (Index in die Tondateien des Anlasses, 0 = erste).
var variant := 0
## Lautstärkefaktor (Grundlautstärke × Abschwächung durch die Entfernung); 1 = wie die Datei.
var volume := 1.0
## Panorama von -1 (ganz links) über 0 (Mitte) bis 1 (ganz rechts).
var pan := 0.0
## Tonhöhe als Faktor (1 = unverändert).
var pitch := 1.0

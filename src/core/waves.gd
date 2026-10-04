class_name Waves
extends RefCounted
## Angriffswellen der Spielwelt nach dem Wellenplan (WavePlan).
##
## Hält keinen eigenen Zustand: Plan, Nummer der nächsten Welle und abgewehrte Wellen hält die
## Spielwelt, die Welle eines Feinds der Feind selbst; die Spielwelt bleibt die einzige Wurzel des
## Zustands (ADR 0002). Wie Combat legt sie für jeden Aufruf ein Waves an (GameWorld._waves()).

## Die Seiten der Karte, in der Reihenfolge, in der der Zufall unter ihnen wählt.
const SIDES: Array[String] = ["north", "east", "south", "west"]

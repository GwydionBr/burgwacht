class_name Waves
extends RefCounted
## Angriffswellen der Spielwelt nach dem Wellenplan (WavePlan): Zu Beginn ihres Tages erscheint
## eine Welle gebündelt auf der Randkachel ihrer Seite, die dem Bergfried am nächsten liegt
## (Combat.spawn_tile()); ihre Feinde verteilen sich auf die freien Kacheln drumherum. Wellen
## kommen strikt nach Plan, auch wenn ältere noch leben.
##
## Hält keinen eigenen Zustand: Plan, Nummer der nächsten Welle und abgewehrte Wellen hält die
## Spielwelt, die Welle eines Feinds der Feind selbst; die Spielwelt bleibt die einzige Wurzel des
## Zustands (ADR 0002). Wie Combat legt sie für jeden Aufruf ein Waves an (GameWorld._waves()).

## Die Seiten der Karte, in der Reihenfolge, in der der Zufall unter ihnen wählt.
const SIDES: Array[String] = ["north", "east", "south", "west"]
## Seite → Name im Spieltext („Welle aus Norden!“).
const SIDE_NAMES: Dictionary[String, String] = {
	"north": "Norden", "east": "Osten", "south": "Süden", "west": "Westen",
}

var _world: GameWorld


func _init(world: GameWorld) -> void:
	_world = world


## Die Randkacheln einer Seite, zeilenweise: Norden y = 0, Osten x = Breite − 1, Süden
## y = Höhe − 1, Westen x = 0. Eine Ecke gehört zu beiden Seiten.
static func side_tiles(map: MapData, side: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var on_side := (side == "north" and y == 0) or (side == "east" and x == map.width - 1) \
					or (side == "south" and y == map.height - 1) or (side == "west" and x == 0)
			if on_side:
				result.append(Vector2i(x, y))
	return result


## Die Welle mit dieser Nummer (ab 1) laut Plan; null, wenn keine mehr kommt.
func planned_wave(number: int) -> PlannedWave:
	var plan := _world._wave_plan
	return plan.list[number - 1] if number <= plan.list.size() else null


## In jedem Takt (und bei der Gründung): Jede Welle, deren Tag begonnen hat, erscheint.
func update() -> void:
	var wave := planned_wave(_world._next_wave)
	while wave != null and wave.day <= _world.get_day():
		_spawn(wave)
		wave = planned_wave(_world._next_wave)


## Debug-Befehl: Die nächste Welle erscheint sofort, die danach kommen wie geplant.
func spawn_next() -> String:
	var reason := _world.spawn_wave_error()
	if reason != "":
		return reason
	_spawn(planned_wave(_world._next_wave))
	return ""


## Die nächste Welle erscheint jetzt; ihre Feinde kommen in der Reihenfolge des Plans auf die
## Randkachel ihrer Seite bzw. die nächsten freien drumherum.
func _spawn(wave: PlannedWave) -> void:
	var number := _world._next_wave
	_world._next_wave += 1
	var side := wave.side if wave.side != "" else _random_side()
	var combat := _world._combat()
	var spawn := combat.spawn_tile(side)
	_world.notice.emit("Welle aus %s!" % SIDE_NAMES[side])
	var spawned := 0
	for type_id: String in wave.enemies:
		for _i in wave.enemies[type_id]:
			var found: Array[Vector2i] = []
			if not spawn.is_empty() and _is_free(spawn[0]):
				found = spawn
			elif not spawn.is_empty():
				found = _world._search_outward(spawn[0], _is_free)
			if not found.is_empty():
				combat._add_enemy(type_id, found[0], number)
				spawned += 1
	# Ohne einen einzigen Feind (Anzahl 0 oder kein Platz) ist sie sofort abgewehrt.
	if spawned == 0:
		_repel()


## Eine Seite aus dem Zufall der Spielwelt (ADR 0001): nur unter denen, von denen aus das
## Gelände den Bergfried erreicht (Gebäude außer Acht gelassen, Combat._reaches_keep()); gibt es
## keine, unter allen.
func _random_side() -> String:
	var reaching := _world._combat()._reaches_keep()
	var sides: Array[String] = []
	for side in SIDES:
		for tile in side_tiles(_world.map, side):
			if reaching.has(Figure.ground(tile)):
				sides.append(side)
				break
	if sides.is_empty():
		sides = SIDES.duplicate()
	return sides[_world._rng.randi_range(0, sides.size() - 1)]


## Kann hier ein Feind der Welle erscheinen? Frei für Feinde und ohne anderen Feind.
func _is_free(tile: Vector2i) -> bool:
	return _world._combat()._is_free_enemy_tile(tile) and _world.get_enemies_at(tile).is_empty()


## Ein Feind ist gestorben: War er der letzte seiner Welle, ist sie abgewehrt.
func enemy_removed(enemy: Enemy) -> void:
	if enemy.wave == 0:
		return
	for other in _world.get_enemies():
		if other.wave == enemy.wave:
			return
	_repel()


func _repel() -> void:
	_world._repelled_waves += 1
	_world.notice.emit("Welle abgewehrt")

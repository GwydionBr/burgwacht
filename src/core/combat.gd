class_name Combat
extends RefCounted
## Kampf und Feinde der Spielwelt: Feinde (z. B. Räuber) erscheinen am Kartenrand und laufen zum
## Bergfried; Soldaten in Sichtweite greifen sie an. Soldaten greifen Feinde auf Befehl an. Ein
## Angriff trifft sofort und ohne Zufall; wer keine Lebenspunkte mehr hat, stirbt.
##
## Hält keinen eigenen Zustand: Feinde und Bewohner gehören weiter der Spielwelt, sie bleibt die
## einzige Wurzel des Zustands (ADR 0002). Die Spielwelt legt für jeden Aufruf ein Combat an
## (GameWorld._combat()); als ihr Teil benutzt Combat ihre internen Hilfen (Wegfindung, Feinde
## hinzufügen und entfernen).

var _world: GameWorld


func _init(world: GameWorld) -> void:
	_world = world


## Was ein Kämpfer im Kampf gegen target tut, als Spieltext, z. B. „greift Räuber an“.
static func fight_text(figure: Figure, target: Figure) -> String:
	var verb := "verfolgt %s" if figure.is_moving() else "greift %s an"
	return verb % FighterType.name_of(target.fighter_type())


## Angreifen: Die Soldaten verfolgen den Feind ohne Leine, bis er tot ist (update_attacker()).
func attack(soldier_ids: Array[int], enemy_id: int) -> String:
	var reason := _world.attack_error(soldier_ids, enemy_id)
	if reason != "":
		return reason
	var ids := soldier_ids.duplicate()
	ids.sort()
	for id: int in ids:
		var soldier := _world.get_resident(id)
		if soldier.target_id == enemy_id:
			continue
		soldier.target_id = enemy_id
		soldier.task = Resident.Task.ON_DUTY
		# Wer gerade auf einen neuen Versuch wartet, legt gleich los.
		soldier.timer = 0
		_world.resident_changed.emit(soldier.id)
	return ""


## Ein Takt für einen Soldaten mit Angriffsbefehl: Er verfolgt den Feind und kämpft (_fight()).
## Erreicht er ihn nicht, bleibt er stehen und versucht es nach der Wartezeit erneut.
func update_attacker(soldier: Resident) -> void:
	var enemy := _world.get_enemy(soldier.target_id)
	if enemy == null:
		_end_attack(soldier)
		return
	if soldier.timer > 0:
		soldier.timer -= 1
		return
	if not _fight(soldier, enemy):
		soldier.timer = Resident.retry_ticks()


## Das Ziel eines Soldaten ist tot: Er bleibt stehen (mitten im Schritt geht er den noch zu
## Ende), und sein Posten wird seine Position.
func _end_attack(soldier: Resident) -> void:
	_world._report_change(soldier, func() -> void:
		soldier.target_id = 0
		soldier.timer = 0
		soldier.stop()
		soldier.post = soldier.plan_start())


## Ein Takt Kampf gegen target. Nur zwischen zwei Schritten wird entschieden: Ist das Ziel in
## Reichweite (Figure.in_reach()), bleibt er stehen und greift an, sobald die Angriffsdauer seit
## dem letzten Angriff um ist (_hit()); sonst läuft er zu dessen Kachel und plant neu, wenn das
## Ziel weitergezogen oder der Weg versperrt ist. false, wenn es keinen Weg zum Ziel gibt (er
## steht dann).
func _fight(figure: Figure, target: Figure) -> bool:
	if figure.step_progress == 0:
		if figure.in_reach(target):
			figure.path.clear()
			if figure.cooldown == 0:
				_hit(figure, target)
			return true
		if not figure.is_moving() or figure.path.back() != target.position() \
				or not _world._is_next_step_open(figure):
			if not _world._route_to(figure, target.position()):
				figure.path.clear()
				return false
	figure.advance()
	return true


## Ein Angriff trifft sofort und ohne Zufall: Schaden abziehen, Angriffsdauer beginnt von vorn.
## Fernkämpfer melden den Schuss für die Darstellung. Was aus dem Ziel wird, hängt von seiner Art
## ab (Figure.report_hit() → soldier_hit() bzw. enemy_hit()).
func _hit(figure: Figure, target: Figure) -> void:
	var type := figure.fighter_type()
	figure.cooldown = FighterType.attack_ticks(type)
	target.hp = maxi(target.hp - FighterType.damage_of(type), 0)
	if not FighterType.is_melee(type):
		_world.shot_fired.emit(figure.position(), target.position())
	target.report_hit(self)


## Ein Soldat wurde getroffen. Bei 0 Lebenspunkten fällt er: Er ist kein Bewohner mehr (seine
## Waffe ist verloren); Feinde, die ihn angegriffen haben, laufen weiter zum Bergfried.
func soldier_hit(soldier: Resident) -> void:
	if soldier.hp > 0:
		_world.resident_changed.emit(soldier.id)
		return
	_world._remove_resident(soldier)
	_world.notice.emit("Ein %s ist gefallen" % FighterType.name_of(soldier.soldier_type))
	for enemy in _world.get_enemies():
		if enemy.target_id == soldier.id:
			_drop_enemy_target(enemy)


## Ein Feind wurde getroffen. Bei 0 Lebenspunkten verschwindet er; Soldaten, die ihn angegriffen
## haben, bleiben stehen (_end_attack()).
func enemy_hit(enemy: Enemy) -> void:
	if enemy.hp > 0:
		_world.enemy_changed.emit(enemy.id)
		return
	_world._remove_enemy(enemy)
	for resident in _world.get_residents():
		if resident.target_id == enemy.id:
			_end_attack(resident)


## Feinde laufen in ID-Reihenfolge einen Takt weiter: Ein Feind ohne Ziel sucht zwischen zwei
## Schritten den nächsten Soldaten in Sichtweite, den er erreicht (_enemy_target()), und greift
## ihn an (_fight()); verliert er ihn aus der Sicht oder erreicht ihn nicht mehr, läuft er weiter
## zum Bergfried (_send_enemy_to_keep()).
func update_enemies() -> void:
	for enemy in _world.get_enemies():
		if _world.get_enemy(enemy.id) != null:
			_update_enemy(enemy)


func _update_enemy(enemy: Enemy) -> void:
	if enemy.cooldown > 0:
		enemy.cooldown -= 1
	var target := _world.get_resident(enemy.target_id)
	if enemy.step_progress == 0:
		if target != null and enemy.distance_to(target) > FighterType.sight_of(enemy.type) + Figure.DISTANCE_SLACK:
			_drop_enemy_target(enemy)
			target = null
		if target == null:
			target = _enemy_target(enemy)
			if target != null:
				enemy.target_id = target.id
				_world.enemy_changed.emit(enemy.id)
	if target != null:
		if not _fight(enemy, target):
			_drop_enemy_target(enemy)
		return
	if enemy.is_moving() and enemy.step_progress == 0 and not _world._is_next_step_open(enemy):
		_send_enemy_to_keep(enemy)
	enemy.advance()


## Der Soldat in Sichtweite, den der Feind angreift: der nächste (Abstand der Kachelmitten, bei
## Gleichstand kleinere ID), den er erreicht – mit einem Weg von höchstens doppelter Sichtweite,
## damit Soldaten hinter Hindernissen nicht jeden Takt die ganze Karte durchsuchen lassen. null,
## wenn es keinen gibt.
func _enemy_target(enemy: Enemy) -> Resident:
	var sight := FighterType.sight_of(enemy.type)
	var candidates: Array[Resident] = []
	for resident in _world.get_residents():
		if resident.is_soldier() and enemy.distance_to(resident) <= sight + Figure.DISTANCE_SLACK:
			candidates.append(resident)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Resident, b: Resident) -> bool:
		var da := enemy.distance_to(a)
		var db := enemy.distance_to(b)
		return da < db if absf(da - db) > Figure.DISTANCE_SLACK else a.id < b.id)
	var reachable := _world._distances(enemy.position(), GameWorld.Walker.GROUND_ONLY, 2.0 * sight)
	for candidate in candidates:
		if reachable.has(candidate.position()):
			return candidate
	return null


## Der Feind gibt sein Ziel auf und läuft weiter zum Bergfried.
func _drop_enemy_target(enemy: Enemy) -> void:
	enemy.target_id = 0
	_send_enemy_to_keep(enemy)
	_world.enemy_changed.emit(enemy.id)


## Schickt einen Feind zur erreichbaren Kachel, die dem Bergfried am nächsten liegt
## (_keep_goal()); steht er schon dort oder gibt es keine, bleibt er stehen und wartet.
func _send_enemy_to_keep(enemy: Enemy) -> void:
	if enemy.is_moving() and not _world._is_next_step_open(enemy):
		# Die Kachel, auf die er gerade tritt, ist versperrt: zurück auf seine.
		enemy.step_progress = 0
	var goal := _keep_goal(enemy.plan_start())
	if goal.is_empty() or not _world._route_to(enemy, goal[0]):
		enemy.stop()


## Die von start aus erreichbare Kachel außerhalb des Bergfrieds, die seiner Grundfläche am
## nächsten liegt (Abstand der Kachelmitten); bei Gleichstand die mit dem kürzeren Weg, dann die
## kleinere (zeilenweise). Ist der Weg frei, ist das eine Kachel direkt am Bergfried. Als
## [Position], leer, wenn es keine gibt.
func _keep_goal(start: Vector3i) -> Array[Vector3i]:
	var keep := _world._keep()
	var best: Array[Vector3i] = []
	var best_distance := INF
	var best_length := INF
	var distances := _world._distances(start, GameWorld.Walker.GROUND_ONLY)
	for position: Vector3i in distances:
		var tile := Vector2i(position.x, position.y)
		if _world.get_building_at(tile) == keep:
			continue
		var distance := _distance_to_building(tile, keep)
		var length := distances[position]
		var better := distance < best_distance - Figure.DISTANCE_SLACK
		if not better and absf(distance - best_distance) <= Figure.DISTANCE_SLACK:
			better = length < best_length and not Pathfinder.same_length(length, best_length)
			if not better and Pathfinder.same_length(length, best_length):
				better = GameWorld._row_order(tile, Vector2i(best[0].x, best[0].y))
		if better:
			best = [position]
			best_distance = distance
			best_length = length
	return best


## Abstand einer Kachel zur nächsten Kachel der Grundfläche eines Gebäudes (0 auf ihr).
static func _distance_to_building(tile: Vector2i, building: Building) -> float:
	var nearest := tile.clamp(building.origin, building.origin + Building.size_of(building.type) - Vector2i.ONE)
	return Vector2(tile - nearest).length()


## Debug-Befehl: Ein Feind erscheint am Kartenrand nächst dem Bergfried (spawn_tile()).
func spawn_enemy(type_id: String) -> String:
	var reason := _world.spawn_enemy_error(type_id)
	if reason != "":
		return reason
	_add_enemy(type_id, spawn_tile()[0])
	return ""


## Die Randkachel, auf der ein Feind erscheint: die freie, die der Grundfläche des Bergfrieds am
## nächsten liegt und nicht durch das Gelände von ihm abgeschnitten ist (_reaches_keep());
## bei Gleichstand die kleinere (zeilenweise). Gebäude zählen dabei nicht: Ist der Weg nur durch
## Gebäude versperrt, erscheint er trotzdem dort und wartet. Ist jeder Rand abgeschnitten, die
## nächste freie. Als [Kachel], leer, wenn es keine freie gibt.
func spawn_tile() -> Array[Vector2i]:
	var keep := _world._keep()
	var reaching := _reaches_keep()
	var best: Array[Vector2i] = []
	var best_distance := INF
	var best_reaches := false
	var map := _world.map
	for y in map.height:
		for x in map.width:
			var tile := Vector2i(x, y)
			if not map.is_edge(tile) or not _is_free_enemy_tile(tile):
				continue
			var reaches := reaching.has(Figure.ground(tile))
			var distance := _distance_to_building(tile, keep)
			if (reaches and not best_reaches) \
					or (reaches == best_reaches and distance < best_distance - Figure.DISTANCE_SLACK):
				best = [tile]
				best_distance = distance
				best_reaches = reaches
	return best


## Alle Positionen, von denen aus man eine Kachel direkt am Bergfried erreicht (gemeinsame Kante
## mit seiner Grundfläche), wenn man Gebäude außer Acht lässt (GameWorld._is_open_ground()). Je
## Zusammenhangsgebiet genügt eine Suche.
func _reaches_keep() -> Dictionary[Vector3i, float]:
	var keep := _world._keep()
	var result: Dictionary[Vector3i, float] = {}
	for tile in Building.adjacent_tiles(keep.type, keep.origin):
		var start := Figure.ground(tile)
		if _world._is_open_ground(start) and not result.has(start):
			result.merge(Pathfinder.distances(start, _world._is_open_ground))
	return result


## Kann hier ein Feind erscheinen? Begehbar und ohne Gebäude (also auch nicht auf Eingängen).
func _is_free_enemy_tile(tile: Vector2i) -> bool:
	return _world.is_walkable(tile, Figure.Level.GROUND) and _world.get_building_at(tile) == null


## Die Feinde des Szenarios bei der Gründung: auf ihrer Kachel oder, ist sie nicht frei, der
## nächsten freien (Reihenfolge wie bei den Startbewohnern); gibt es keine, entfällt er.
func add_start_enemies(start_enemies: Array[StartEnemy]) -> void:
	for entry in start_enemies:
		var found: Array[Vector2i] = [entry.tile]
		if not _is_free_enemy_tile(entry.tile):
			found = _world._search_outward(entry.tile, _is_free_enemy_tile)
		if not found.is_empty():
			_add_enemy(entry.type_id, found[0])


## Ein neuer Feind mit vollen Lebenspunkten; er läuft gleich zum Bergfried.
func _add_enemy(type_id: String, tile: Vector2i) -> void:
	_send_enemy_to_keep(_world._add_enemy(type_id, tile))


## Nach Bau oder Abriss: Wer auf einer neuen Grundfläche steht, weicht auf die nächste begehbare
## Kachel aus; wer kein Ziel hat, plant den Weg zum Bergfried neu.
func replan_enemies() -> void:
	for enemy in _world.get_enemies():
		if not _world._is_walkable_position(enemy.position()):
			var found := _world._search_outward(enemy.tile, func(tile: Vector2i) -> bool:
				return _world.is_walkable(tile, Figure.Level.GROUND))
			if not found.is_empty():
				enemy.place_at(Figure.ground(found[0]))
		if enemy.target_id == 0:
			_send_enemy_to_keep(enemy)

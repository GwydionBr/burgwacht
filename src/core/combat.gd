class_name Combat
extends RefCounted
## Kampf und Feinde der Spielwelt: Feinde (Räuber im Nahkampf, Wilderer im Fernkampf) erscheinen
## am Kartenrand, laufen zum Bergfried und greifen ihn an; Soldaten in Sichtweite bzw. Reichweite
## greifen sie an. Soldaten greifen Feinde auf Befehl an. Ein Angriff trifft sofort und ohne
## Zufall; wer keine Lebenspunkte mehr hat, stirbt. Fällt der Bergfried, ist die Partie verloren.
##
## Feinde planen ihren Weg mit Zerstörungskosten (ADR 0005): Gebäude, auf denen sie nicht stehen
## dürfen, gelten als begehbar, kosten aber so viel, wie es dauert, sie zu zerstören
## (_EnemyMap). Das erste Gebäude auf dem Weg ist das Hindernis; der Feind läuft heran und
## greift es an, ein Fernkämpfer schon aus der Entfernung. Ein zerstörtes Gebäude verschwindet
## (GameWorld._destroy()), dann planen alle neu.
##
## Hält keinen eigenen Zustand: Feinde und Bewohner gehören weiter der Spielwelt, sie bleibt die
## einzige Wurzel des Zustands (ADR 0002). Die Spielwelt legt für jeden Aufruf ein Combat an
## (GameWorld._combat()); als ihr Teil benutzt Combat ihre internen Hilfen (Wegfindung, Feinde
## hinzufügen und entfernen, Meldung am Bergfried, Niederlage), schreibt ihren Zustand aber nicht
## selbst.

## Meldung beim ersten Treffer eines Angriffs auf den Bergfried.
const KEEP_ATTACKED := "Der Bergfried wird angegriffen!"
## Nahkampf-Reichweite zu einem Gebäude: Abstand zur nächsten Kachel der Grundfläche unter diesem
## Wert, also auf einer Nachbarkachel, auch schräg (√2 < 1,5).
const MELEE_REACH := 1.5

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
		if soldier.target_id == enemy_id and not soldier.defending:
			continue
		soldier.target_id = enemy_id
		soldier.defending = false
		soldier.task = Resident.Task.ON_DUTY
		# Wer gerade auf einen neuen Versuch wartet, legt gleich los.
		soldier.timer = 0
		_world.resident_changed.emit(soldier.id)
	return ""


## Ein Takt für einen Soldaten mit Ziel: Mit Befehl verfolgt er den Feind ohne Leine; beim
## selbstständigen Verteidigen gelten Reichweite und Leine (_keep_defending()).
func update_attacker(soldier: Resident) -> void:
	var enemy := _world.get_enemy(soldier.target_id)
	if enemy == null:
		_stop_attack(soldier)
		return
	if soldier.defending:
		_keep_defending(soldier, enemy)
		return
	if soldier.timer > 0:
		soldier.timer -= 1
		return
	if not _fight(soldier, enemy):
		soldier.timer = Resident.retry_ticks()


## Beendet den Angriff und meldet die Änderung; beim Verteidigen geht er zurück zum Posten,
## nach einem Befehl bleibt er stehen (_stop_attack()).
func _end_attack(soldier: Resident) -> void:
	_world._report_change(soldier, _stop_attack.bind(soldier))


## Ein Takt Kampf gegen target. Nur zwischen zwei Schritten wird entschieden: Ist das Ziel in
## Reichweite (Figure.in_reach()), bleibt er stehen und greift an, sobald die Angriffsdauer seit
## dem letzten Angriff um ist (_hit()); sonst läuft er zu dessen Kachel und plant neu, wenn das
## Ziel weitergezogen oder der Weg versperrt ist. false, wenn es keinen Weg zum Ziel gibt oder
## may_enter (Position → bool) den nächsten Schritt verbietet (Leine beim Verteidigen).
func _fight(figure: Figure, target: Figure, may_enter := Callable()) -> bool:
	if figure.step_progress == 0:
		if figure.in_reach(target, _range_bonus(figure)):
			figure.path.clear()
			if figure.cooldown == 0:
				_hit(figure, target)
			return true
		if not figure.is_moving() or figure.path.back() != target.position() or not _world._can_step(figure):
			if not _world._route_to(figure, target.position()):
				figure.path.clear()
				return false
		if may_enter.is_valid() and not may_enter.call(figure.path[0]):
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


## Ein Feind wurde getroffen. Bei 0 Lebenspunkten verschwindet er; seine Angreifer beenden
## den Angriff, Verteidigende kehren zum Posten zurück (_end_attack()).
func enemy_hit(enemy: Enemy) -> void:
	if enemy.hp > 0:
		_world.enemy_changed.emit(enemy.id)
		return
	_world._remove_enemy(enemy)
	for resident in _world.get_residents():
		if resident.target_id == enemy.id:
			_end_attack(resident)


## Feinde laufen in ID-Reihenfolge einen Takt weiter: Ein Feind ohne Ziel sucht zwischen zwei
## Schritten den nächsten Soldaten, den er erreicht bzw. in Reichweite hat (_enemy_target()), und
## greift ihn an (_fight()); verliert er ihn (_enemy_keeps_target()) oder erreicht ihn nicht mehr,
## läuft er weiter zum Bergfried (_send_enemy_to_keep()).
func update_enemies() -> void:
	for enemy in _world.get_enemies():
		if _world.is_defeated():
			return
		if _world.get_enemy(enemy.id) != null:
			_update_enemy(enemy)
	if _world._is_keep_alarmed(0) and not _is_keep_attacked_without_wave():
		# Der Angriff der Feinde ohne Welle ist vorbei; der nächste wird wieder gemeldet.
		_world._end_keep_alarm(0)


## Greift gerade ein Feind ohne Welle (Startfeind, Debug-Feind) den Bergfried an?
func _is_keep_attacked_without_wave() -> bool:
	var keep := _world._keep()
	for enemy in _world.get_enemies():
		if enemy.wave == 0 and enemy.target_building_id == keep.id:
			return true
	return false


## Ein Takt eines Feinds. Zielvorrang: ein Soldat, den er erreicht bzw. in Reichweite hat
## (_enemy_target()), dann das Hindernis auf seinem Weg, dann der Bergfried (_attack_in_way());
## sonst geht er seinen Weg weiter.
func _update_enemy(enemy: Enemy) -> void:
	if enemy.cooldown > 0:
		enemy.cooldown -= 1
	var target := _world.get_resident(enemy.target_id)
	if enemy.step_progress == 0:
		if target != null and not _enemy_keeps_target(enemy, target):
			_drop_enemy_target(enemy)
			target = null
		if target == null:
			target = _enemy_target(enemy)
			if target != null:
				enemy.target_id = target.id
				enemy.target_building_id = 0
				_world.enemy_changed.emit(enemy.id)
	if target != null:
		if not _fight(enemy, target):
			_drop_enemy_target(enemy)
		return
	if enemy.step_progress == 0 and _attack_in_way(enemy):
		return
	if enemy.is_moving() and enemy.step_progress == 0 and not _world._can_step(enemy):
		_send_enemy_to_keep(enemy)
	enemy.advance()


## Ein Takt am Gebäude, das dem Feind im Weg steht: zuerst das Hindernis (_obstacle_in_reach()),
## sonst der Bergfried, wenn er ihn in Reichweite hat (_in_reach_of_building()). Er bleibt stehen
## und greift es an, sobald die Angriffsdauer seit dem letzten Angriff um ist; seinen Weg legt er
## dafür ab, das Ziel merkt er sich (target_building_id). false, wenn er keines in Reichweite hat.
func _attack_in_way(enemy: Enemy) -> bool:
	var building := _obstacle_in_reach(enemy)
	var keep := _world._keep()
	if building == null and _in_reach_of_building(enemy, keep):
		building = keep
	if building == null:
		if enemy.target_building_id != 0:
			enemy.target_building_id = 0
			_world.enemy_changed.emit(enemy.id)
		return false
	enemy.path.clear()
	if enemy.target_building_id != building.id:
		enemy.target_building_id = building.id
		_world.enemy_changed.emit(enemy.id)
	if enemy.cooldown == 0:
		_hit_building(enemy, building)
	return true


## Das Hindernis, das der Feind jetzt angreift: das erste Gebäude auf seinem Weg, auf dem er nicht
## stehen darf (_obstacle_at()), wenn er es in Reichweite hat. Ohne Weg (er greift schon an) das
## Hindernis, das er sich gemerkt hat, solange es steht und in Reichweite ist. Sonst null.
func _obstacle_in_reach(enemy: Enemy) -> Building:
	var obstacle: Building = null
	if enemy.is_moving():
		for position in enemy.path:
			obstacle = _obstacle_at(position)
			if obstacle != null:
				break
	else:
		obstacle = _world.get_building(enemy.target_building_id)
		if obstacle != null and obstacle == _world._keep():
			obstacle = null
	if obstacle != null and _in_reach_of_building(enemy, obstacle):
		return obstacle
	return null


## Hat der Kämpfer das Gebäude in Reichweite (_in_reach_at())?
func _in_reach_of_building(figure: Figure, building: Building) -> bool:
	return _in_reach_at(figure.fighter_type(), figure.position(), building)


## Hätte ein Kämpfer dieses Typs auf position das Gebäude in Reichweite? Nahkämpfer am Boden auf
## einer Nachbarkachel der Grundfläche (auch schräg), Fernkämpfer bis zu ihrer Reichweite zur
## nächsten Kachel der Grundfläche.
func _in_reach_at(type: String, position: Vector3i, building: Building) -> bool:
	var distance := _distance_to_building(Vector2i(position.x, position.y), building)
	if FighterType.is_melee(type):
		return position.z == Figure.Level.GROUND and distance > 0.0 and distance < MELEE_REACH
	return distance <= FighterType.range_of(type) + _range_bonus_at(type, position) + Figure.DISTANCE_SLACK


## Ein Angriff auf ein Gebäude trifft sofort und ohne Zufall, wie _hit(). Am Bergfried meldet
## der erste Treffer einer Welle diesen („Der Bergfried wird angegriffen!“; bei Feinden ohne
## Welle der erste Treffer eines Angriffs); fällt er auf 0, ist die Partie verloren. Jedes andere
## Gebäude ist bei 0 zerstört (GameWorld._destroy()).
func _hit_building(figure: Figure, building: Building) -> void:
	var type := figure.fighter_type()
	figure.cooldown = FighterType.attack_ticks(type)
	building.hp = maxi(building.hp - FighterType.damage_of(type), 0)
	if not FighterType.is_melee(type):
		var nearest := figure.tile.clamp(building.origin, building.origin + Building.size_of(building.type) - Vector2i.ONE)
		_world.shot_fired.emit(figure.position(), Figure.ground(nearest))
	_world.building_changed.emit(building.id)
	var wave := (figure as Enemy).wave if figure is Enemy else 0
	if building == _world._keep() and _world._alarm_keep(wave):
		_world.notice.emit(KEEP_ATTACKED)
	if building == _world._keep() and building.hp == 0:
		_world._lose()
	elif building.hp == 0:
		_world._destroy(building)


## Der Soldat, den der Feind angreift (unbewaffnete Bewohner sind nie Ziel): der nächste (Abstand
## der Kachelmitten, bei Gleichstand kleinere ID). Ein Nahkämpfer nimmt einen in Sichtweite, den er
## erreicht – mit einem Weg von höchstens doppelter Sichtweite, damit Soldaten hinter Hindernissen
## nicht jeden Takt die ganze Karte durchsuchen lassen. Ein Fernkämpfer (Wilderer) nimmt einen in
## Reichweite, auch auf einer anderen Ebene (Wehrgang), ohne Weg. null, wenn es keinen gibt.
func _enemy_target(enemy: Enemy) -> Resident:
	var sight := FighterType.sight_of(enemy.type)
	var melee := FighterType.is_melee(enemy.type)
	var candidates: Array[Figure] = []
	for resident: Resident in _world.get_residents():
		if not resident.is_soldier():
			continue
		if melee and enemy.distance_to(resident) <= sight + Figure.DISTANCE_SLACK:
			candidates.append(resident)
		elif not melee and enemy.in_reach(resident, _range_bonus(enemy)):
			candidates.append(resident)
	return _nearest_opponent(enemy, candidates, 2.0 * sight if melee else -1.0) as Resident


## Bleibt der Feind an seinem Soldaten dran? Ein Nahkämpfer, solange er ihn sieht; ein Fernkämpfer,
## solange er ihn in Reichweite hat, sonst geht er seinen Weg weiter, statt ihm nachzulaufen.
func _enemy_keeps_target(enemy: Enemy, target: Resident) -> bool:
	if FighterType.is_melee(enemy.type):
		return enemy.distance_to(target) <= FighterType.sight_of(enemy.type) + Figure.DISTANCE_SLACK
	return enemy.in_reach(target, _range_bonus(enemy))


## Der Feind gibt sein Ziel auf und läuft weiter zum Bergfried.
func _drop_enemy_target(enemy: Enemy) -> void:
	enemy.target_id = 0
	_send_enemy_to_keep(enemy)
	_world.enemy_changed.emit(enemy.id)


## Schickt einen Feind auf dem schnellsten Weg zum Bergfried (_keep_route()); steht er schon in
## Reichweite oder erreicht er ihn gar nicht (Gelände), bleibt er stehen und wartet.
func _send_enemy_to_keep(enemy: Enemy) -> void:
	if enemy.is_moving() and not _world._can_step(enemy):
		# Die Kachel, auf die er gerade tritt, ist versperrt: zurück auf seine.
		enemy.step_progress = 0
	if not _world._follow(enemy, _keep_route(enemy)):
		enemy.stop()


## Der schnellste Weg des Feinds ab plan_start() zu einer Position, von der aus er den Bergfried in
## Reichweite hat (_in_reach_at()), mit Zerstörungskosten für Hindernisse (_EnemyMap). Samt Start
## wie Pathfinder.find_path(); leer, wenn das Gelände keinen zulässt.
func _keep_route(enemy: Enemy) -> Array[Vector3i]:
	var keep := _world._keep()
	var type := enemy.type
	var is_goal := func(position: Vector3i) -> bool: return _in_reach_at(type, position, keep)
	# Nahkämpfer: Eine Kachel in Reichweite liegt weniger als MELEE_REACH von der Grundfläche
	# entfernt, also fehlen von position aus mindestens so viele Kacheln weniger MELEE_REACH.
	# Fernkämpfer suchen ohne Schätzung.
	var estimate := Callable()
	if FighterType.is_melee(type):
		estimate = func(position: Vector3i) -> float:
			return maxf(_distance_to_building(Vector2i(position.x, position.y), keep) - MELEE_REACH, 0.0)
	var map := _EnemyMap.new(self, type)
	return Pathfinder.find_path_to_any(enemy.plan_start(), is_goal, map.is_passable, map.ascents,
			map.is_steppable, map.extra_cost, estimate)


## Das Hindernis auf position: ein zerstörbares Gebäude außer dem Bergfried, das am Boden auf
## sonst begehbarem Gelände steht und auf dem Feinde nicht stehen dürfen (Mauer, Tor, Turm, alle
## Gebäude außer Treppe und Eingängen). null, wenn dort keines ist.
func _obstacle_at(position: Vector3i) -> Building:
	if position.z != Figure.Level.GROUND or not _world._is_open_ground(position) \
			or _world._can_stand(position, GameWorld.Walker.ENEMY):
		return null
	var building := _world.get_building_at(Vector2i(position.x, position.y))
	if building == null or not building.is_destructible() or building == _world._keep():
		return null
	return building


## Die Karte, wie ein Feind dieses Typs sie für seinen Weg sieht (ADR 0005): Wo er stehen darf,
## kostet nichts extra; ein Hindernis (_obstacle_at()) ist begehbar, kostet aber beim Hineingehen
## von außerhalb so viele Kacheln Weg, wie er in der Zeit zurücklegt, die er braucht, um es zu
## zerstören: (aktuelle Lebenspunkte / Schaden) × Angriffsdauer / Takte pro Kachel. Innerhalb
## desselben Gebäudes kostet ein Schritt nichts extra, denn eine Zerstörung genügt. Merkt sich die
## Kosten je Position, denn die Wegfindung fragt dieselbe Position oft.
class _EnemyMap:
	## Kein Hindernis, aber auch nicht begehbar.
	const BLOCKED := -1.0

	var _combat: Combat
	var _type: String
	var _costs: Dictionary[Vector3i, float] = {}
	## Position → das Hindernis dort (null: keines), wie _costs gemerkt.
	var _obstacles: Dictionary[Vector3i, Building] = {}

	func _init(combat: Combat, type: String) -> void:
		_combat = combat
		_type = type

	## Kosten auf position: 0, wo er stehen darf, Zerstörungskosten auf einem Hindernis, sonst
	## BLOCKED.
	func cost_at(position: Vector3i) -> float:
		if _costs.has(position):
			return _costs[position]
		var cost := BLOCKED
		var obstacle: Building = null
		if _combat._world._can_stand(position, GameWorld.Walker.ENEMY):
			cost = 0.0
		else:
			obstacle = _combat._obstacle_at(position)
			if obstacle != null:
				cost = float(obstacle.hp) / FighterType.damage_of(_type) * FighterType.attack_ticks(_type) \
						/ FighterType.ticks_per_tile(_type)
		_costs[position] = cost
		_obstacles[position] = obstacle
		return cost

	## Begehbar für die Wegplanung: wo er stehen darf oder ein Hindernis.
	func is_passable(position: Vector3i) -> bool:
		return cost_at(position) != BLOCKED

	## Zerstörungskosten für den Schritt von from auf to (Pathfinder, extra_cost): nur beim
	## Hineingehen in ein Hindernis von außerhalb, nicht von einer anderen Kachel desselben.
	func extra_cost(from: Vector3i, to: Vector3i) -> float:
		var cost := maxf(cost_at(to), 0.0)
		if cost > 0.0:
			cost_at(from)
			if _obstacles[from] == _obstacles[to]:
				return 0.0
		return cost

	## Ebenenwechsel wie GameWorld._ascents(), aber nicht von einem Hindernis aus: Durch einen Turm,
	## den er erst zerstört, kommt er nicht auf dessen Wehrgang.
	func ascents(position: Vector3i) -> Array[Vector3i]:
		if cost_at(position) > 0.0:
			var none: Array[Vector3i] = []
			return none
		return _combat._world._ascents(position)

	## Schritte wie GameWorld._is_steppable(); auf ein Hindernis und von ihm herunter immer (ein
	## zerstörtes Gebäude hat keinen Eingang mehr).
	func is_steppable(from: Vector3i, to: Vector3i) -> bool:
		return cost_at(from) > 0.0 or cost_at(to) > 0.0 or _combat._world._is_steppable(from, to)


## Abstand einer Kachel zur nächsten Kachel der Grundfläche eines Gebäudes (0 auf ihr).
static func _distance_to_building(tile: Vector2i, building: Building) -> float:
	var nearest := tile.clamp(building.origin, building.origin + Building.size_of(building.type) - Vector2i.ONE)
	return Vector2(tile - nearest).length()


## Debug-Befehl: Ein Feind erscheint am Kartenrand nächst dem Bergfried (spawn_tile()).
func spawn_enemy(type_id: String) -> String:
	var reason := _world.spawn_enemy_error(type_id)
	if reason != "":
		return reason
	add_enemy(type_id, spawn_tile()[0])
	return ""


## Die Randkachel, auf der ein Feind erscheint: die freie, die der Grundfläche des Bergfrieds am
## nächsten liegt und nicht durch das Gelände von ihm abgeschnitten ist (reaches_keep());
## bei Gleichstand die kleinere (zeilenweise). Gebäude zählen dabei nicht: Ist der Weg nur durch
## Gebäude versperrt, erscheint er trotzdem dort und wartet. Ist jeder Rand abgeschnitten, die
## nächste freie. Mit side (MapSide) nur Kacheln dieser Seite. Als [Kachel], leer, wenn es
## keine freie gibt.
func spawn_tile(side := "") -> Array[Vector2i]:
	var keep := _world._keep()
	var reaching := reaches_keep()
	var best: Array[Vector2i] = []
	var best_distance := INF
	var best_reaches := false
	for tile in _edge_tiles(side):
		if not is_free_enemy_tile(tile):
			continue
		var reaches := reaching.has(Figure.ground(tile))
		var distance := _distance_to_building(tile, keep)
		if (reaches and not best_reaches) \
				or (reaches == best_reaches and distance < best_distance - Figure.DISTANCE_SLACK):
			best = [tile]
			best_distance = distance
			best_reaches = reaches
	return best


## Die Randkacheln der Seite (leer: aller Seiten), zeilenweise.
func _edge_tiles(side: String) -> Array[Vector2i]:
	if side != "":
		return MapSide.tiles(_world.map, side)
	var result: Array[Vector2i] = []
	var map := _world.map
	for y in map.height:
		for x in map.width:
			if map.is_edge(Vector2i(x, y)):
				result.append(Vector2i(x, y))
	return result


## Alle Positionen, von denen aus man eine Kachel direkt am Bergfried erreicht (gemeinsame Kante
## mit seiner Grundfläche), wenn man Gebäude außer Acht lässt (GameWorld._is_open_ground()). Je
## Zusammenhangsgebiet genügt eine Suche.
func reaches_keep() -> Dictionary[Vector3i, float]:
	var keep := _world._keep()
	var result: Dictionary[Vector3i, float] = {}
	for tile in Building.adjacent_tiles(keep.type, keep.origin):
		var start := Figure.ground(tile)
		if _world._is_open_ground(start) and not result.has(start):
			result.merge(Pathfinder.distances(start, _world._is_open_ground))
	return result


## Kann hier ein Feind erscheinen? Begehbar und ohne Gebäude (also auch nicht auf Eingängen).
func is_free_enemy_tile(tile: Vector2i) -> bool:
	return _world.is_walkable(tile, Figure.Level.GROUND) and _world.get_building_at(tile) == null


## Die Feinde des Szenarios bei der Gründung: auf ihrer Kachel oder, ist sie nicht frei, der
## nächsten freien (Reihenfolge wie bei den Startbewohnern); gibt es keine, entfällt er.
func add_start_enemies(start_enemies: Array[StartEnemy]) -> void:
	for entry in start_enemies:
		var found: Array[Vector2i] = [entry.tile]
		if not is_free_enemy_tile(entry.tile):
			found = _world._search_outward(entry.tile, is_free_enemy_tile)
		if not found.is_empty():
			add_enemy(entry.type_id, found[0])


## Ein neuer Feind mit vollen Lebenspunkten (aus der Welle mit dieser Nummer, 0 = keiner); er
## läuft gleich zum Bergfried.
func add_enemy(type_id: String, tile: Vector2i, wave := 0) -> Enemy:
	var enemy := _world._add_enemy(type_id, tile, wave)
	_send_enemy_to_keep(enemy)
	return enemy


## Nach Bau oder Abriss: Wer nicht mehr auf einer für Feinde begehbaren Position steht, weicht
## auf den nächsten freien Boden aus; wer kein Ziel hat, plant den Weg zum Bergfried neu.
func replan_enemies() -> void:
	for enemy in _world.get_enemies():
		if not _world._can_stand(enemy.position(), GameWorld.Walker.ENEMY):
			var found := _world._search_outward(enemy.tile, func(tile: Vector2i) -> bool:
				return _world._can_stand(Figure.ground(tile), GameWorld.Walker.ENEMY))
			if not found.is_empty():
				enemy.place_at(Figure.ground(found[0]))
		if enemy.target_id == 0:
			_send_enemy_to_keep(enemy)


## Ein stehender Soldat ohne Befehl verteidigt sich: Fernkämpfer schießen auf den nächsten
## Feind in Reichweite; Nahkämpfer suchen in Sichtweite einen erreichbaren Feind innerhalb der
## Leine. false, wenn es keinen gibt.
func defend(soldier: Resident) -> bool:
	var type := soldier.soldier_type
	var melee := FighterType.is_melee(type)
	var sight := FighterType.sight_of(type)
	var candidates: Array[Figure] = []
	for enemy: Enemy in _world.get_enemies():
		if melee and soldier.distance_to(enemy) <= sight + Figure.DISTANCE_SLACK and _within_leash(enemy.position(), soldier):
			candidates.append(enemy)
		elif not melee and soldier.in_reach(enemy, _range_bonus(soldier)):
			candidates.append(enemy)
	var target := _nearest_opponent(soldier, candidates, 2.0 * sight if melee else -1.0)
	if target == null:
		return false
	soldier.target_id = target.id
	soldier.defending = true
	soldier.timer = 0
	_keep_defending(soldier, target as Enemy)
	return true


## Ein Takt Verteidigen: Fernkämpfer bleiben stehen, Nahkämpfer verfolgen nur in Sichtweite
## und innerhalb der Leine; wer aufgibt, kehrt zu seinem Posten zurück.
func _keep_defending(soldier: Resident, enemy: Enemy) -> void:
	var type := soldier.soldier_type
	if not FighterType.is_melee(type):
		if soldier.in_reach(enemy, _range_bonus(soldier)):
			_fight(soldier, enemy)
		else:
			_stop_attack(soldier)
		return
	if soldier.step_progress == 0 and soldier.distance_to(enemy) > FighterType.sight_of(type) + Figure.DISTANCE_SLACK:
		_stop_attack(soldier)
	elif not _fight(soldier, enemy, _within_leash.bind(soldier)):
		_stop_attack(soldier)


## Liegt die Position höchstens die Leine vom Posten entfernt (Abstand der Kachelmitten)?
func _within_leash(position: Vector3i, soldier: Resident) -> bool:
	var offset := Vector2i(position.x, position.y) - soldier.post_tile()
	return Vector2(offset).length() <= FighterType.leash_of(soldier.soldier_type) + Figure.DISTANCE_SLACK


## Beendet den Kampf. Verteidigende kehren zum alten Posten zurück; nach einem Befehl bleibt
## der Soldat stehen (mitten im Schritt geht er ihn zu Ende), und sein Posten wird seine Position.
func _stop_attack(soldier: Resident) -> void:
	soldier.target_id = 0
	soldier.timer = 0
	if soldier.defending:
		soldier.defending = false
		_world._send_to_post(soldier)
		return
	soldier.stop()
	soldier.post = soldier.plan_start()


## Zusätzliche Reichweite auf dem Wehrgang: Bonus des Kämpfertyps und des Gebäudes darunter (Turm).
## Nur für Soldaten; Feinde bekommen keinen (der Wilderer reicht überall 6).
func _range_bonus(figure: Figure) -> int:
	return _range_bonus_at(figure.fighter_type(), figure.position())


## Zusätzliche Reichweite eines Kämpfers dieses Typs auf position (_range_bonus()).
func _range_bonus_at(type: String, position: Vector3i) -> int:
	if FighterType.is_enemy_type(type):
		return 0
	var below := _world.get_building_at(Vector2i(position.x, position.y))
	if position.z == Figure.Level.WALL_WALK and below != null:
		return FighterType.wall_walk_range_bonus(type) + below.range_bonus()
	return 0


## Nächster Gegner (Abstand der Kachelmitten, bei Gleichstand kleinere ID); mit max_length
## nur einer, dessen Weg höchstens so lang ist. null, wenn es keinen gibt.
func _nearest_opponent(figure: Figure, candidates: Array[Figure], max_length := -1.0) -> Figure:
	candidates.sort_custom(func(a: Figure, b: Figure) -> bool:
		var da := figure.distance_to(a)
		var db := figure.distance_to(b)
		return da < db if absf(da - db) > Figure.DISTANCE_SLACK else a.id < b.id)
	if max_length < 0.0 or candidates.is_empty():
		return null if candidates.is_empty() else candidates[0]
	var reachable := _world._distances(figure.position(), _world._walker_of(figure), max_length)
	for candidate in candidates:
		if reachable.has(candidate.position()):
			return candidate
	return null

class_name Waves
extends RefCounted
## Die Wellen der Spielwelt nach dem Wellenplan (WavePlan): Zu Beginn ihres Tages erscheint
## eine Welle gebündelt auf der Randkachel ihrer Seite, die dem Bergfried am nächsten liegt
## (Combat.spawn_tile()); ihre Feinde verteilen sich auf die freien Kacheln drumherum. Wellen
## kommen strikt nach Plan, auch wenn ältere noch leben.
##
## Eine Vorwarnzeit (WavePlan.warning_days) vor ihrem Erscheinen wird die nächste Welle angekündigt;
## dabei wird ihre Seite festgelegt (ist keine geplant, aus dem Zufall der Spielwelt). Angekündigt
## wird immer nur die nächste; mit dem Erscheinen endet die Ankündigung. Höchstens eine Welle je
## Tag (WavePlan), so wird jede angekündigt.
##
## Hält keinen eigenen Zustand: Plan, Nummer der nächsten Welle, Seite der laufenden Ankündigung
## und abgewehrte Wellen hält die Spielwelt, die Welle eines Feinds der Feind selbst; die
## Spielwelt bleibt die einzige Wurzel des Zustands (ADR 0002) und ändert ihn selbst
## (_take_next_wave(), _start_announcement(), _end_announcement(), _repel_wave()). Wie Combat legt
## sie für jeden Aufruf ein Waves an (GameWorld._waves()).

## Grund, wenn der Debug-Befehl keine nächste Welle erscheinen lassen kann.
const NO_NEXT_WAVE := "Keine weitere Welle geplant"

var _world: GameWorld


func _init(world: GameWorld) -> void:
	_world = world


## Die Welle mit dieser Nummer (ab 1) laut Plan; null, wenn keine mehr kommt.
func planned_wave(number: int) -> PlannedWave:
	return _world._wave_plan.wave(number)


## Der Takt, mit dem die Welle erscheint: der Beginn ihres Tages.
func appearance_tick(wave: PlannedWave) -> int:
	return (wave.day - 1) * GameWorld.TICKS_PER_DAY


## In jedem Takt (und bei der Gründung): Jede Welle, deren Tag begonnen hat, erscheint; danach
## beginnt, wenn es Zeit ist, die Ankündigung der nächsten (bei der Gründung auch verspätet).
func update() -> void:
	var wave := planned_wave(_world.get_next_wave())
	while wave != null and wave.day <= _world.get_day():
		_spawn(wave)
		wave = planned_wave(_world.get_next_wave())
	var warning := _world._wave_plan.warning_days * GameWorld.TICKS_PER_DAY
	if wave != null and _world.get_announced_side() == "" and _world.get_tick() >= appearance_tick(wave) - warning:
		_announce(wave)


## Die Ankündigung der nächsten Welle beginnt: Ihre Seite steht ab jetzt fest.
func _announce(wave: PlannedWave) -> void:
	var side := wave.side if wave.side != "" else _random_side()
	var days := ceili(float(appearance_tick(wave) - _world.get_tick()) / GameWorld.TICKS_PER_DAY)
	_world.notice.emit("Welle aus %s in %d %s" % [MapSide.name_of(side), days, "Tag" if days == 1 else "Tagen"])
	_world._start_announcement(side)


## Darf der Debug-Befehl jetzt die nächste Welle erscheinen lassen? Leer oder der Grund.
func spawn_next_error() -> String:
	if _world.is_founding():
		return GameWorld.FOUNDING_FIRST
	if planned_wave(_world.get_next_wave()) == null:
		return NO_NEXT_WAVE
	return ""


## Debug-Befehl: Die nächste Welle erscheint sofort, die danach kommen wie geplant. Ist die
## übernächste schon in ihrer Vorwarnzeit, beginnt ihre Ankündigung gleich mit (update()).
func spawn_next() -> String:
	var reason := spawn_next_error()
	if reason != "":
		return reason
	_spawn(planned_wave(_world.get_next_wave()))
	update()
	return ""


## Die nächste Welle erscheint jetzt; ihre Feinde kommen in der Reihenfolge des Plans auf die
## Randkachel ihrer Seite bzw. die nächsten freien drumherum.
func _spawn(wave: PlannedWave) -> void:
	var number := _world._take_next_wave()
	# Die Seite der laufenden Ankündigung (sie gilt immer dieser, der nächsten Welle).
	var side := _world.get_announced_side()
	if side != "":
		_world._end_announcement()
	elif wave.side != "":
		side = wave.side
	else:
		side = _random_side()
	var combat := _world._combat()
	var spawn := combat.spawn_tile(side)
	_world.notice.emit("Welle aus %s!" % MapSide.name_of(side))
	var spawned := 0
	for type_id: String in wave.enemies:
		for _i in wave.enemies[type_id]:
			var found: Array[Vector2i] = []
			if not spawn.is_empty() and _is_free(spawn[0]):
				found = spawn
			elif not spawn.is_empty():
				found = _world._search_outward(spawn[0], _is_free)
			if not found.is_empty():
				combat.add_enemy(type_id, found[0], number)
				spawned += 1
	# Ohne einen einzigen Feind (Anzahl 0 oder kein Platz) ist sie sofort abgewehrt.
	if spawned == 0:
		_repel(number)


## Eine Seite aus dem Zufall der Spielwelt (ADR 0001): nur unter denen, von denen aus das
## Gelände den Bergfried erreicht (Gebäude außer Acht gelassen, Combat.reaches_keep()); gibt es
## keine, unter allen.
func _random_side() -> String:
	var reaching := _world._combat().reaches_keep()
	var sides: Array[String] = []
	for side in MapSide.all():
		for tile in MapSide.tiles(_world.map, side):
			if reaching.has(Figure.ground(tile)):
				sides.append(side)
				break
	if sides.is_empty():
		sides = MapSide.all()
	return sides[_world._rng.randi_range(0, sides.size() - 1)]


## Kann hier ein Feind der Welle erscheinen? Frei für Feinde und ohne anderen Feind.
func _is_free(tile: Vector2i) -> bool:
	return _world._combat().is_free_enemy_tile(tile) and _world.get_enemies_at(tile).is_empty()


## Ein Feind ist gestorben: War er der letzte seiner Welle, ist sie abgewehrt.
func enemy_removed(enemy: Enemy) -> void:
	if enemy.wave == 0:
		return
	for other in _world.get_enemies():
		if other.wave == enemy.wave:
			return
	_repel(enemy.wave)


## Die Welle mit dieser Nummer ist abgewehrt; ihr Merker „Bergfried angegriffen“ wird nicht mehr
## gebraucht.
func _repel(number: int) -> void:
	_world._repel_wave(number)
	_world.notice.emit("Welle abgewehrt")

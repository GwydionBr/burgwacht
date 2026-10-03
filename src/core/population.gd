class_name Population
extends RefCounted
## Regelwerte der Bevölkerung aus data/population.json: Rationsstufen (Verbrauch je Bewohner
## und Tag, Faktor), die Faktoren der Beliebtheit samt Namen, die Voreinstellungen und die
## Regel für Kommen und Gehen.


## Die Rationsstufen von der kleinsten zur größten (Reihenfolge der Daten).
static func ration_ids() -> Array[String]:
	var result: Array[String] = []
	for ration: Dictionary in _rations():
		result.append(str(ration["id"]))
	return result


static func has_ration(ration_id: String) -> bool:
	return ration_ids().has(ration_id)


## Spielname einer Rationsstufe, z. B. „halb“.
static func ration_name(ration_id: String) -> String:
	return str(_ration(ration_id)["name"])


## Nahrung je Bewohner und Tag.
static func consumption(ration_id: String) -> float:
	return float(_ration(ration_id)["consumption"])


## Faktor der Beliebtheit, wenn diese Ration gegessen wurde.
static func ration_factor(ration_id: String) -> int:
	return int(_ration(ration_id)["factor"])


static func default_ration() -> String:
	return str(GameDefs.get_instance().population["default_ration"])


## Bei dieser Beliebtheit kommt und geht niemand; darüber kommen Bewohner, darunter gehen sie.
static func balance_popularity() -> int:
	return int(_migration()["balance"])


## Abstand in Takten zwischen zwei Ankünften bzw. Abgängen bei dieser Beliebtheit:
## max(min_ticks, base_ticks − ticks_per_point · |B − balance|).
static func migration_ticks(popularity: int) -> int:
	var migration := _migration()
	var distance := absi(popularity - balance_popularity())
	return maxi(int(migration["min_ticks"]), int(migration["base_ticks"]) - int(migration["ticks_per_point"]) * distance)


## Faktor der Vielfalt: je gegessener Sorte über die erste hinaus "per_extra_kind",
## ohne gegessene Sorte 0.
static func variety_factor(kinds: int) -> int:
	return maxi(kinds - 1, 0) * int(_factor_def(Factor.VARIETY)["per_extra_kind"])


## Spielname eines Faktors, z. B. „Vielfalt“.
static func factor_name(factor_id: String) -> String:
	return str(_factor_def(factor_id)["name"])


static func _migration() -> Dictionary:
	return GameDefs.get_instance().population["migration"]


static func _rations() -> Array:
	return GameDefs.get_instance().population["rations"]


static func _ration(ration_id: String) -> Dictionary:
	for ration: Dictionary in _rations():
		if ration["id"] == ration_id:
			return ration
	assert(false, "Unbekannte Ration „%s“" % ration_id)
	return {}


static func _factor_def(factor_id: String) -> Dictionary:
	return GameDefs.get_instance().population["factors"][factor_id]

class_name Population
extends RefCounted
## Regelwerte der Bevölkerung aus data/population.json: Rationsstufen (Verbrauch je Bewohner
## und Tag, Faktor), Steuersätze (Gold je Bewohner und Tag, Faktor), die Faktoren der
## Beliebtheit samt Namen und die Voreinstellungen.


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


## Die Steuersätze vom kleinsten zum größten (Reihenfolge der Daten).
static func tax_rate_ids() -> Array[String]:
	var result: Array[String] = []
	for tax_rate: Dictionary in _tax_rates():
		result.append(str(tax_rate["id"]))
	return result


static func has_tax_rate(tax_rate_id: String) -> bool:
	return tax_rate_ids().has(tax_rate_id)


## Spielname eines Steuersatzes, z. B. „sehr hoch“.
static func tax_rate_name(tax_rate_id: String) -> String:
	return str(_tax_rate(tax_rate_id)["name"])


## Gold je Bewohner und Tag.
static func tax_gold(tax_rate_id: String) -> float:
	return float(_tax_rate(tax_rate_id)["gold"])


## Faktor der Beliebtheit bei diesem Steuersatz.
static func tax_factor(tax_rate_id: String) -> int:
	return int(_tax_rate(tax_rate_id)["factor"])


static func default_tax_rate() -> String:
	return str(GameDefs.get_instance().population["default_tax_rate"])


## Faktor der Vielfalt: je gegessener Sorte über die erste hinaus "per_extra_kind",
## ohne gegessene Sorte 0.
static func variety_factor(kinds: int) -> int:
	return maxi(kinds - 1, 0) * int(_factor_def(Factor.VARIETY)["per_extra_kind"])


## Spielname eines Faktors, z. B. „Vielfalt“.
static func factor_name(factor_id: String) -> String:
	return str(_factor_def(factor_id)["name"])


static func _rations() -> Array:
	return GameDefs.get_instance().population["rations"]


static func _ration(ration_id: String) -> Dictionary:
	for ration: Dictionary in _rations():
		if ration["id"] == ration_id:
			return ration
	assert(false, "Unbekannte Ration „%s“" % ration_id)
	return {}


static func _tax_rates() -> Array:
	return GameDefs.get_instance().population["tax_rates"]


static func _tax_rate(tax_rate_id: String) -> Dictionary:
	for tax_rate: Dictionary in _tax_rates():
		if tax_rate["id"] == tax_rate_id:
			return tax_rate
	assert(false, "Unbekannter Steuersatz „%s“" % tax_rate_id)
	return {}


static func _factor_def(factor_id: String) -> Dictionary:
	return GameDefs.get_instance().population["factors"][factor_id]

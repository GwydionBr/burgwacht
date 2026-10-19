extends RefCounted
## Eine gewonnene Partie für Screenshot und Rauchtest der Siegansicht.


static func create() -> GameWorld:
	var scenario := Scenario.from_dict("victory", {
		"name": "Ziel erfüllt", "map": {"width": 24, "height": 24}, "seed": 1,
		"start_residents": 8,
		"goals": [{"kind": "population", "amount": 8, "text": "Acht Bewohner aufnehmen"}]})
	var helper := TestCase.new()
	return helper.found_castle(helper.clear_map(GameWorld.create(scenario, 1)))

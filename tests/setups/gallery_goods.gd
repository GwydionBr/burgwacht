extends Node2D
## Jede tragbare Ware als Rückenbündel auf demselben Bewohner; auch Ware ohne Sprite bleibt sichtbar.


func setup(clock: GameClock) -> void:
	var index := 0
	for good_id: String in GameDefs.get_instance().goods:
		var resident := Resident.new()
		var column := index % 5
		var row := index / 5
		resident.tile = Vector2i(13 + column * 2 + row * 2, 17 - column * 2 + row * 2)
		resident.carried_good = good_id
		resident.carried_amount = 1
		var view := ResidentView.new()
		view.setup(resident, clock)
		view.facing = 3
		add_child(view)
		var label := Label.new()
		label.text = str(GameDefs.get_instance().goods[good_id]["name"])
		label.add_theme_font_size_override("font_size", 10)
		label.position = Iso.tile_to_world(resident.tile) + Vector2(-20, 8)
		add_child(label)
		index += 1

extends Node2D
## Jede tragbare Ware als Rückenbündel auf demselben Bewohner; auch Ware ohne Sprite bleibt sichtbar.


func setup(clock: GameClock) -> void:
	var index := 0
	for good_id: String in GameDefs.get_instance().goods:
		var resident := Resident.new()
		resident.tile = Vector2i.ZERO
		var point := Vector2(46 + (index % 5) * 110, 28 + (index / 5) * 61)
		resident.carried_good = good_id
		resident.carried_amount = 1
		var view := ResidentView.new()
		view.setup(resident, clock)
		view.facing = 3
		var holder := Node2D.new()
		holder.position = point
		add_child(holder)
		holder.add_child(view)
		var label := Label.new()
		label.text = str(GameDefs.get_instance().goods[good_id]["name"])
		label.add_theme_font_size_override("font_size", 12)
		label.position = point + Vector2(-25, 21)
		add_child(label)
		index += 1

extends SceneTree
## Gibt die IDs aller Presets aus tools/presets.json aus, eine je Zeile (für tools/smoke.sh).
## Aufruf: godot --headless --path . --script res://tests/preset_ids.gd


func _initialize() -> void:
	var error := Presets.error()
	if error != "":
		printerr(error)
		quit(1)
		return
	for id: String in Presets.load_all():
		print(id)
	quit()

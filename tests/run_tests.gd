extends SceneTree
## Führt alle tests/test_*.gd aus. Aufruf: tools/test.sh


func _initialize() -> void:
	var failed := 0
	var passed := 0
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: TestCase = script.new()
			test_case.call(method_name)
			if test_case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FEHLER  %s :: %s" % [file, method_name])
				for failure in test_case.failures:
					print("        ", failure)
	print("\n%d bestanden, %d fehlgeschlagen" % [passed, failed])
	quit(1 if failed > 0 else 0)

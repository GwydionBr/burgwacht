extends SceneTree
## Führt alle tests/test_*.gd aus. Aufruf: tools/test.sh
## Nur bestimmte Dateien: tools/test.sh test_founding (Teil des Dateinamens, mehrere möglich).
##
## Ein Test schlägt fehl, wenn eine Prüfung nicht stimmt, wenn er einen Fehler auslöst
## (Skriptfehler, fehlgeschlagenes assert(), push_error()) oder wenn er gar nichts prüft.


## Sammelt die Fehler, die Godot während eines Tests meldet. Ohne ihn bräche ein Skriptfehler
## nur die Testmethode ab, und der Test gälte als bestanden.
class ErrorCollector:
	extends Logger

	var errors: PackedStringArray = []

	func _log_error(
		function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		errors.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])


func _initialize() -> void:
	var failed := 0
	var passed := 0
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var filters := OS.get_cmdline_user_args()
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		if not filters.is_empty() and not Array(filters).any(func(f: String) -> bool: return file.contains(f)):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FEHLER  %s lässt sich nicht laden (Parse-Fehler?)" % file)
			collector.errors.clear()
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: TestCase = script.new()
			collector.errors.clear()
			test_case.call(method_name)
			var failures := test_case.failures.duplicate()
			for error in collector.errors:
				failures.append("Fehler: " + error)
			if failures.is_empty() and test_case.checks == 0:
				failures.append("Der Test prüft nichts (kein assert_true/assert_eq erreicht)")
			if failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FEHLER  %s :: %s" % [file, method_name])
				for failure in failures:
					print("        ", failure)
	OS.remove_logger(collector)
	print("\n%d bestanden, %d fehlgeschlagen" % [passed, failed])
	quit(1 if failed > 0 else 0)

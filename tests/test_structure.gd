extends TestCase
## Prüft die Regeln für den Aufbau des Projekts (AGENTS.md), nicht das Spiel selbst.

const SOURCE_DIR := "res://src"
const CORE_DIR := "res://src/core"
## Ordner, aus denen core/ nichts kennen darf.
const OUTER_DIRS: Array[String] = ["res://src/view", "res://src/ui"]


## Auch Skripte, die kein anderer Test berührt (main.gd, view/, ui/), müssen sich laden
## lassen – ein Parse-Fehler oder eine fehlende Typangabe fällt sonst erst beim Start auf.
func test_all_scripts_load() -> void:
	var paths := _scripts_in(SOURCE_DIR)
	assert_true(paths.size() > 0, "Keine Skripte unter %s gefunden" % SOURCE_DIR)
	for path in paths:
		var script: GDScript = load(path)
		assert_true(script != null and script.can_instantiate(), "%s lässt sich nicht laden" % path)


## core/ ist reine Logik: kein Verweis auf Klassen oder Dateien aus view/ und ui/.
func test_core_knows_nothing_of_view_and_ui() -> void:
	var outer_classes: Array[String] = []
	for dir in OUTER_DIRS:
		for path in _scripts_in(dir):
			var name_match := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)").search(_read(path))
			if name_match != null:
				outer_classes.append(name_match.get_string(1))
	assert_true(outer_classes.size() > 0, "Keine Klassen in view/ und ui/ gefunden")
	for path in _scripts_in(CORE_DIR):
		var source := _read(path)
		for dir in OUTER_DIRS:
			assert_true(not source.contains(dir), "%s verweist auf %s" % [path, dir])
		for outer_class in outer_classes:
			var usage := RegEx.create_from_string("\\b%s\\b" % outer_class).search(source)
			assert_true(usage == null, "%s kennt %s aus view/ oder ui/" % [path, outer_class])


## Alle *.gd in einem Ordner samt Unterordnern, sortiert.
func _scripts_in(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			paths.append(dir.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir):
		paths.append_array(_scripts_in(dir.path_join(sub_dir)))
	paths.sort()
	return paths


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

extends SceneTree
## Wirtschaftsrechner: gibt die Schätzungen von Economy als Tabellen aus (Arbeitsstätten,
## Nahrung, Ketten, Bevölkerung). Aufruf: tools/economy.sh [--storage=Kacheln] [--deposit=Kacheln]


func _initialize() -> void:
	var economy := Economy.new(_arg("storage", Economy.DEFAULT_STORAGE_DISTANCE),
			_arg("deposit", Economy.DEFAULT_DEPOSIT_DISTANCE))
	print("Wirtschaftsrechner – Weg zum Lager %s Kacheln, zum Vorkommen %s Kacheln, %d Takte je Tag"
			% [_number(economy.storage_distance), _number(economy.deposit_distance), GameWorld.TICKS_PER_DAY])
	_print_workplaces(economy)
	_print_food(economy)
	_print_chains(economy)
	_print_population()
	quit()


func _print_workplaces(economy: Economy) -> void:
	var rows: Array[PackedStringArray] = [PackedStringArray(["Arbeitsstätte", "Arbeit", "Weg", "Erzeugnis/Tag",
			"Eingang/Tag", "Kosten", "Wert/Tag", "Amortisation"])]
	for type_id in Economy.workplace_types():
		var rate := economy.rate(type_id)
		var input := "–" if rate.input == "" else "%s %s" % [_number(rate.input_per_day), _good(rate.input)]
		var payback := economy.payback_days(type_id)
		rows.append(PackedStringArray([_building(type_id), str(rate.work_ticks), _number(rate.walk_ticks),
				"%s %s" % [_number(rate.product_per_day), _good(rate.product)], input,
				"%d Gold" % Economy.cost_in_gold(type_id), _number(economy.value_per_day(type_id)),
				"nie" if is_inf(payback) else "%s Tage" % _number(payback)]))
	_print_table("Arbeitsstätten (Takte je Arbeitsgang; Kosten zum Kaufpreis, Wert zum Verkaufspreis)", rows)


func _print_food(economy: Economy) -> void:
	var header := PackedStringArray(["Nahrungsstätte"])
	for ration_id in Population.ration_ids():
		if Population.consumption(ration_id) > 0:
			header.append("Ration %s" % Population.ration_name(ration_id))
	var rows: Array[PackedStringArray] = [header]
	for type_id in Economy.workplace_types():
		if not Population.is_food(economy.rate(type_id).product):
			continue
		var row := PackedStringArray([_building(type_id)])
		for ration_id in Population.ration_ids():
			if Population.consumption(ration_id) > 0:
				row.append(_number(economy.fed_residents(type_id, ration_id)))
		rows.append(row)
	_print_table("Nahrung (satte Bewohner je Gebäude)", rows)


func _print_chains(economy: Economy) -> void:
	var rows: Array[PackedStringArray] = [PackedStringArray(["Kette", "Gebäude je Endglied"])]
	for type_id in Economy.workplace_types():
		if economy.rate(type_id).input == "":
			continue
		var parts := PackedStringArray()
		for link in economy.chain(type_id):
			parts.append("%s %s" % [_number(link.count), _building(link.type)])
		rows.append(PackedStringArray([_building(type_id), " ← ".join(parts)]))
	_print_table("Ketten (wie viele Zulieferer bis zum Rohstoff)", rows)


func _print_population() -> void:
	var rows: Array[PackedStringArray] = [PackedStringArray(["Wohnraum", "Bewohner"])]
	for type_id in Economy.housing_types():
		rows.append(PackedStringArray([_building(type_id), str(Building.create(0, type_id, Vector2i.ZERO).housing())]))
	_print_table("Bevölkerung", rows)
	rows = [PackedStringArray(["Steuersatz", "Gold/Bewohner/Tag", "Beliebtheit/Tag"])]
	for tax_rate_id in Population.tax_rate_ids():
		rows.append(PackedStringArray([Population.tax_rate_name(tax_rate_id),
				_number(Population.tax_gold(tax_rate_id)), "%+d" % Population.tax_factor(tax_rate_id)]))
	_print_table("", rows)


## Gibt eine Tabelle mit Überschrift aus; die erste Zeile ist der Kopf, Spalten linksbündig.
func _print_table(title: String, rows: Array[PackedStringArray]) -> void:
	var widths: Array[int] = []
	for row in rows:
		for i in row.size():
			if i >= widths.size():
				widths.append(0)
			widths[i] = maxi(widths[i], row[i].length())
	print("")
	if title != "":
		print(title)
	for r in rows.size():
		var cells := PackedStringArray()
		for i in rows[r].size():
			cells.append(rows[r][i].rpad(widths[i]))
		print("  " + "  ".join(cells).strip_edges(false, true))
		if r == 0:
			var rule := PackedStringArray()
			for width in widths:
				rule.append("-".repeat(width))
			print("  " + "  ".join(rule))


func _building(type_id: String) -> String:
	return str(GameDefs.get_instance().buildings[type_id]["name"])


func _good(good: String) -> String:
	return str(GameDefs.get_instance().goods[good]["name"])


## Eine Zahl mit höchstens einer Nachkommastelle, ohne „,0“.
func _number(value: float) -> String:
	var text := "%.1f" % value
	return text.trim_suffix(".0").replace(".", ",")


## Wert eines Startparameters --name=Zahl, sonst fallback.
func _arg(name: String, fallback: float) -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return float(arg.get_slice("=", 1))
	return fallback

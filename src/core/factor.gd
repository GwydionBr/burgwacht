class_name Factor
extends RefCounted
## Ein Faktor: ein Beitrag zur täglichen Änderung der Beliebtheit (z. B. Ration, Vielfalt).
## Ein weiterer Faktor (später Religion, Bier) braucht eine eigene ID hier, einen
## Eintrag unter "factors" in population.json und einen in GameWorld._factors_of().

const RATION := "ration"
const VARIETY := "variety"
const TAX_RATE := "tax_rate"

var id: String
var value: int


static func create(factor_id: String, factor_value: int) -> Factor:
	var factor := Factor.new()
	factor.id = factor_id
	factor.value = factor_value
	return factor


## Spielname aus den Daten, z. B. „Ration“.
func name() -> String:
	return Population.factor_name(id)


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {"id": id, "value": value}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Factor:
	return create(str(data["id"]), int(data["value"]))

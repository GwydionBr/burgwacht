class_name ResidentAnimation
extends RefCounted
## Wählt die Arbeitsanimation und Blickrichtung eines abbauenden Bewohners aus den Vorkommensdaten.


static func work_animation(resident: Resident, world: GameWorld) -> String:
	if resident.task != Resident.Task.MINING or resident.is_moving():
		return ""
	var deposit := world.map.get_deposit(resident.deposit_tile)
	if deposit == null:
		return ""
	return str(GameDefs.get_instance().deposits[deposit.type].get("work_animation", ""))


static func work_direction(resident: Resident, previous: int) -> int:
	if resident.task != Resident.Task.MINING or resident.is_moving():
		return previous
	return FigureAnimation.direction(resident.deposit_tile - resident.tile, previous)

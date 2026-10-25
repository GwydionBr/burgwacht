class_name ScreenFit
extends RefCounted
## Passt Fenster und Oberfläche einmal beim Start an den Bildschirm an. Der Stretch-Modus aus
## project.godot (`canvas_items`, `expand`) skaliert die 1600×900 große Oberfläche mit dem Fenster.
## Auf HiDPI-Bildschirmen (Retina) ist das Fenster in Bildpunkten nur halb so groß wie gedacht
## und die Oberfläche wäre im Vollbild fast doppelt so groß; dort wächst darum das Fenster um den
## Bildschirmfaktor (höchstens auf MAX_SCREEN_SHARE der nutzbaren Fläche), und die Oberfläche
## schrumpft um HIDPI_UI_SCALE, sodass mehr Karte zu sehen ist.

## So viel der nutzbaren Bildschirmfläche darf das Fenster beim Start höchstens einnehmen.
const MAX_SCREEN_SHARE := 0.9
## Faktor auf die Oberfläche auf HiDPI-Bildschirmen: im Vollbild auf einem MacBook (3024×1898)
## etwa 1,35-fach statt 1,89-fach.
const HIDPI_UI_SCALE := 0.714


static func apply(window: Window) -> void:
	var screen := window.current_screen
	var factor := DisplayServer.screen_get_scale(screen)
	if factor <= 1.0:
		return
	window.content_scale_factor = HIDPI_UI_SCALE
	var usable := Vector2(DisplayServer.screen_get_usable_rect(screen).size) * MAX_SCREEN_SHARE
	var wanted := Vector2(window.size) * factor
	var size := Vector2i(wanted * minf(1.0, minf(usable.x / wanted.x, usable.y / wanted.y)))
	if size.x > window.size.x:
		window.size = size
		window.move_to_center()

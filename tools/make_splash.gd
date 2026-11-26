extends Node
## Renders the boot splash (res://assets/splash.png) from the title card's final frame.
## Runs inside the game (autoloads available); needs a real renderer:
##   godot --path . --resolution 640x360 -- splash profile=user://smoke_profile.json

const Card := preload("res://scenes/screens/card_screen.gd")

var frames := 0
var card


func _ready() -> void:
	card = Card.new()
	card.t = Card.LENGTH - 0.2
	card.done = true
	card.show_skip = false
	card.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(holder)
	holder.add_child(card)
	add_child(layer)


func _process(_delta: float) -> void:
	frames += 1
	card.position = ((get_viewport().get_visible_rect().size - Vector2(640, 360)) / 2.0).floor()
	card.size = Vector2(640, 360)
	card.queue_redraw()
	if frames == 8:
		var img := get_viewport().get_texture().get_image()
		var vs := get_viewport().get_visible_rect().size
		var scale: float = img.get_width() / vs.x
		var crop := Rect2i((card.position * scale).round(), (Vector2(640, 360) * scale).round())
		img = img.get_region(crop)
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		print("splash saved: ", img.save_png("res://assets/splash.png") == OK)
		get_tree().quit()

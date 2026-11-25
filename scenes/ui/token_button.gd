extends Button
## A square pixel token: an icon (or chip) on a little velvet tile, with an optional badge and
## price tag. Used for the rack, bet denominations, House Rules and shop stock.
## Hover text goes to `hover_target` (a Callable taking the String) instead of OS tooltips.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")

var icon_id := ""
var chip_value := 0          ## > 0: draw a denomination chip instead of an icon
var badge := ""
var price := ""
var hover_text := ""
var selected := false
var dim := false
var hover_target: Callable


func _init(id: String = "", sz: Vector2 = Vector2(24, 24)) -> void:
	icon_id = id
	custom_minimum_size = sz
	size = sz
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_entered.connect(func():
		if hover_target.is_valid():
			hover_target.call(hover_text)
		queue_redraw())
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hot := is_hovered() and not disabled
	var bg: Color = P.PANEL_HI if not selected else Color("#3b2a12")
	if hot:
		bg = bg.lightened(0.1)
	draw_rect(r, P.BLACK)
	draw_rect(r.grow(-1), bg)
	draw_rect(Rect2(1, 1, size.x - 2, 1), bg.lightened(0.2))
	var border: Color = P.GOLD if selected else (P.LINE if hot else P.LINE.darkened(0.55))
	draw_rect(r, border, false, 1.0)
	var c := Vector2(size.x / 2.0, (size.y - (8 if price != "" else 0)) / 2.0).round()
	if hot and not disabled:
		c.y -= 1
	if chip_value > 0:
		Art.chip(self, c, min(size.x, size.y) * 0.36, Art.denom_color(chip_value))
		Art.text(self, P.font(), c + Vector2(0, 3), str(chip_value), P.FONT_SMALL, P.BLACK if chip_value < 5 else P.CREAM, true)
	elif icon_id != "":
		Art.icon(self, icon_id, c, 1 if size.x < 34 else 2)
	if badge != "":
		var w := P.font().get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT_SMALL).x
		draw_rect(Rect2(size.x - w - 4, 0, w + 4, 9), P.RED)
		draw_string(P.font(), Vector2(size.x - w - 2, 7), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT_SMALL, P.CREAM)
	if price != "":
		draw_rect(Rect2(1, size.y - 10, size.x - 2, 9), P.BLACK)
		Art.text(self, P.font(), Vector2(size.x / 2.0, size.y - 3), price, P.FONT_SMALL, P.GOLD if not dim else P.DIM, true)
	if disabled or dim:
		draw_rect(r.grow(-1), Color(0, 0, 0, 0.45))

extends Control
## Pawn Shop: spend Markers (earned per night cleared) to unlock wheels and content for future runs.
## Laid out as a tree: lanes of unlocks, cheapest at the top; each item needs the one above it.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Profile := preload("res://core/profile.gd")
const Token := preload("res://scenes/ui/token_button.gd")

const LANE_W := 86.0
const ROW_H := 44.0
const TOP := 62.0
const NODE := Vector2(30, 30)
## Icons for unlocks that aren't items (wheels, the feature, vendors, kits).
const ICON_FOR := {"call_bets": "call_bets", "fence": "hot", "banker_kit": "cash", "collector_kit": "perm",
	"high_roller_kit": "kingmaker"}

var main
var markers_lbl: Label
var detail: Label
var lines_view: Control
var nodes: Control
var catalogue := {}


func setup() -> void:
	P.place(P.label(self, "PAWN SHOP  -  Fifth Street", P.FONT_BIG, P.GOLD), Vector2(16, 8))
	markers_lbl = P.label(self, "", P.FONT, P.CREAM)
	P.place(markers_lbl, Vector2(16, 30))
	lines_view = Control.new()
	lines_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(lines_view, Vector2.ZERO, Vector2(640, 360))
	lines_view.draw.connect(_draw_lines)
	add_child(lines_view)
	nodes = Control.new()
	nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(nodes, Vector2.ZERO, Vector2(640, 360))
	add_child(nodes)
	var panel := Panel.new()
	P.place(panel, Vector2(104, 296), Vector2(520, 56))
	add_child(panel)
	detail = P.label(panel, "Hover an unlock. Each one needs the one above it in its lane.", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(6, 4), Vector2(508, 48))
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22)), Vector2(16, 326))


func _lane_x(i: int, n: int) -> float:
	var total: float = n * LANE_W
	return (640.0 - total) / 2.0 + i * LANE_W + LANE_W / 2.0


func _node_pos(lane: int, row: int, n: int) -> Vector2:
	return Vector2(_lane_x(lane, n), TOP + 14 + row * ROW_H)


func refresh() -> void:
	var prof = main.profile
	markers_lbl.text = "Markers: %d   (earned by clearing nights)" % prof.markers
	catalogue = {}
	for e in Profile.catalogue():
		catalogue[e.id] = e
	for c in nodes.get_children():
		c.queue_free()
	var lanes := Profile.tree()
	for li in range(lanes.size()):
		var lane: Dictionary = lanes[li]
		var head := P.label(nodes, lane.title, P.FONT_SMALL, P.DIM)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		P.place(head, Vector2(_lane_x(li, lanes.size()) - LANE_W / 2.0, TOP - 12), Vector2(LANE_W, 10))
		for ri in range(lane.ids.size()):
			var id: String = lane.ids[ri]
			var e: Dictionary = catalogue[id]
			var owned: bool = prof.is_unlocked(id)
			var open: bool = prof.can_unlock(id)
			var tok = Token.new(ICON_FOR.get(id, "spin" if e.category == "wheel" else id), NODE)
			tok.selected = owned
			tok.dim = not owned and not open
			tok.badge = "" if owned else "%dM" % e.cost
			var at: Vector2 = _node_pos(li, ri, lanes.size()) - NODE / 2.0
			P.place(tok, at)
			nodes.add_child(tok)
			var nm := P.label(nodes, e.name if e.name.length() <= 13 else e.name.substr(0, 12) + ".", P.FONT_SMALL, P.CREAM if owned else (P.GOLD if open else P.DIM))
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			P.place(nm, Vector2(at.x + NODE.x / 2.0 - LANE_W / 2.0, at.y + NODE.y + 1), Vector2(LANE_W, 9))
			tok.hover_target = func(_s):
				var req := Profile.requires(id)
				var state := "OWNED" if owned else ("%d Markers" % e.cost if open else "Needs %s first" % catalogue[req].name)
				detail.text = "%s  [%s]  -  %s\n%s" % [e.name, e.category.to_upper(), state, e.desc]
			tok.pressed.connect(_buy.bind(id))
	lines_view.queue_redraw()


func _draw_lines() -> void:
	if main == null:
		return
	var lanes := Profile.tree()
	for li in range(lanes.size()):
		var ids: Array = lanes[li].ids
		for ri in range(1, ids.size()):
			var a := _node_pos(li, ri - 1, lanes.size()) + Vector2(0, NODE.y / 2.0 + 10)
			var b := _node_pos(li, ri, lanes.size()) - Vector2(0, NODE.y / 2.0)
			var lit: bool = main.profile.is_unlocked(ids[ri - 1])
			lines_view.draw_line(a, b, P.GOLD if lit else P.LINE.darkened(0.4), 1.0)


func _buy(id: String) -> void:
	var prof = main.profile
	if prof.buy_unlock(id):
		main.save_profile()
		Sfx.play("unlock")
		main.fx.stamp("UNLOCKED", P.GOLD, 1.0)
		main.fx.burst(main.fx.get_local_mouse_position(), 30, [P.GOLD, P.CREAM, P.GOOD], 150.0)
		refresh()
	elif prof.is_unlocked(id):
		detail.text = "Already yours."
	elif not prof.can_unlock(id):
		detail.text = "Unlock %s first: it's the one above this in the lane." % catalogue[Profile.requires(id)].name
	else:
		detail.text = "Not enough Markers yet."
		Sfx.play("click")

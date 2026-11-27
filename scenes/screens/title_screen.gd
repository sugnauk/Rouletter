extends Control
## The home screen, dressed as a casino front: a neon sign ringed with chasing bulbs, a lit
## Markers board (click it for the Pawn Shop), a big pulsing NEW RUN, a ticket stub for the run
## you left, and chips tumbling past the wheel.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Board := preload("res://core/board.gd")
const Version := preload("res://core/version.gd")
const RunState := preload("res://core/run_state.gd")
const Wheels := preload("res://core/wheels.gd")
const Content := preload("res://core/content.gd")

const TableScene := preload("res://scenes/ui/table_scene.gd")
const SIGN := Rect2(18, 16, 320, 62)
const BOARD := Rect2(18, 84, 320, 32)
const TICKET := Rect2(18, 176, 320, 44)
const PANEL := Rect2(10, 10, 336, 312)

var main
var continue_btn   ## marquee buttons (scenes/ui/marquee_button.gd)
var new_btn
var info_lbl: Label
var continue_info: Label
var sign_view: Control
var board_view: Control
var ticket_view: Control
var _t := 0.0
var _flicker := 0.0
var board_text := ["", "", 0.0]   ## markers line, next-unlock line, progress 0..1
var portrait := false
var grid_ctl: GridContainer
var scene                 ## the live table behind the menu (scenes/ui/table_scene.gd)
var panel_view: Control   ## the smoked-glass panel the menu sits on
var hint_lbl: Label
var ver_lbl: Label


func setup() -> void:
	# Behind everything: a roulette table in play, in chunky pixel 3D.
	scene = TableScene.new()
	add_child(scene)
	# The menu sits on a pane of smoked glass with a brass hairline.
	panel_view = Control.new()
	panel_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(panel_view, PANEL.position, PANEL.size)
	panel_view.draw.connect(func():
		var r := Rect2(Vector2.ZERO, panel_view.size)
		panel_view.draw_rect(r.grow(2), Color(0, 0, 0, 0.35))
		panel_view.draw_rect(r, Color(0.05, 0.03, 0.03, 0.86))
		panel_view.draw_rect(r, Color("#8a6a3a"), false, 1.0)
		panel_view.draw_rect(r.grow(-2), Color(1, 0.85, 0.55, 0.06), false, 1.0))
	add_child(panel_view)
	sign_view = Control.new()
	sign_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(sign_view, SIGN.position, SIGN.size)
	sign_view.draw.connect(_draw_sign)
	add_child(sign_view)
	# The Markers board doubles as the way into the Pawn Shop.
	board_view = Button.new()
	board_view.flat = true
	board_view.focus_mode = Control.FOCUS_NONE
	P.place(board_view, BOARD.position, BOARD.size)
	board_view.draw.connect(_draw_board)
	board_view.pressed.connect(func():
		Sfx.play("click")
		main.show_screen("pawn"))
	board_view.mouse_entered.connect(board_view.queue_redraw)
	board_view.mouse_exited.connect(board_view.queue_redraw)
	add_child(board_view)
	info_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	P.place(info_lbl, Vector2(20, 120))
	# The big plaque, and Continue beside it when there's a run to pick up.
	# Only these two are lit marquees: everything else is a quiet everyday button.
	new_btn = P.button(self, "NEW RUN", func(): main.begin_flow(), Vector2(196, 38), P.FONT_BIG)
	new_btn.add_theme_font_override("font", P.title_font())
	new_btn.pulse = true
	new_btn.marquee = true
	P.place(new_btn, Vector2(18, 132))
	continue_btn = P.button(self, "CONTINUE", func(): main.continue_run(), Vector2(118, 38), P.FONT)
	continue_btn.accent = P.CYAN
	continue_btn.marquee = true
	P.place(continue_btn, Vector2(220, 132))
	# The ticket stub: what the saved run looks like.
	ticket_view = Control.new()
	ticket_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(ticket_view, TICKET.position, TICKET.size)
	ticket_view.draw.connect(_draw_ticket)
	add_child(ticket_view)
	continue_info = P.label(ticket_view, "", P.FONT_SMALL, P.BLACK)
	continue_info.add_theme_constant_override("line_spacing", -1)
	P.place(continue_info, Vector2(30, 5), Vector2(288, 36))
	# Everything else, smaller marquees in a grid.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	P.place(grid, Vector2(18, 230))
	add_child(grid)
	grid_ctl = grid
	for b in [["Pawn Shop", func(): main.show_screen("pawn")], ["Casebook", func(): _casebook("collection")],
			["How to Play", func(): _casebook("guide")], ["Options", func(): main.open_options()],
			["Credits", func(): main.show_screen("credits")], ["Quit", func(): get_tree().quit()]]:
		P.button(grid, b[0], b[1], Vector2(156, 22))
	# On the web, phones get the tip that matters: home-screen play is truly full screen.
	var hint := "On a phone: Share > Add to Home Screen plays full screen. Options > Screen fit if it's cut off." if OS.has_feature("web") \
		else "F2: CRT filter    F11: fullscreen"
	hint_lbl = P.label(self, hint, P.FONT_SMALL, P.DIM)
	P.place(hint_lbl, Vector2(20, 306))
	var ver := P.label(self, Version.label(), P.FONT_SMALL, P.CREAM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	P.place(ver, Vector2(408, 340), Vector2(224, 10))
	ver_lbl = ver


## Portrait: the wheel spins at the top, the sign and the buttons stack beneath it.
func relayout(tall: bool) -> void:
	portrait = tall
	var dy := 292.0 if tall else 0.0
	if tall:   # the table plays across the top, the menu stacks under it
		scene.position = Vector2.ZERO
		scene.set_size_px(Vector2(360, 300), Vector2i(180, 150), 0.5)
	else:
		scene.position = Vector2.ZERO
		scene.set_size_px(Vector2(640, 360), Vector2i(320, 180), 0.77)
	P.place(panel_view, PANEL.position + Vector2(0, dy), PANEL.size + (Vector2(4, 0) if tall else Vector2.ZERO))
	P.place(sign_view, SIGN.position + Vector2(0, dy))
	P.place(board_view, BOARD.position + Vector2(0, dy))
	P.place(info_lbl, Vector2(20, 120 + dy))
	P.place(new_btn, Vector2(18, 132 + dy))
	P.place(continue_btn, Vector2(220, 132 + dy))
	P.place(ticket_view, TICKET.position + Vector2(0, dy))
	P.place(grid_ctl, Vector2(18, 230 + dy))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if tall else TextServer.AUTOWRAP_OFF
	P.place(hint_lbl, Vector2(20, 306 + dy) if tall else Vector2(20, 306), Vector2(320, 20) if tall else Vector2(320, 10))
	P.place(ver_lbl, Vector2(116, 624) if tall else Vector2(408, 344), Vector2(224, 10))


func _casebook(t: String) -> void:
	main.screens.casebook.tab = t
	main.show_screen("casebook")


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# The sign flickers now and then, like an old tube.
	if _flicker > 0.0:
		_flicker -= delta
	elif randf() < delta * 0.25:
		_flicker = randf_range(0.08, 0.3)
	sign_view.queue_redraw()
	board_view.queue_redraw()


func _draw_sign() -> void:
	var c := sign_view
	var r := Rect2(Vector2.ZERO, SIGN.size)
	c.draw_rect(r, Color("#0a0608"))
	c.draw_rect(r.grow(-3), Color("#1a0b10"))
	c.draw_rect(r, P.GOLD.darkened(0.3), false, 1.0)
	c.draw_rect(r.grow(-3), P.GOLD.darkened(0.55), false, 1.0)
	# Bulbs round the frame, chasing.
	var chase := int(_t * 1.5)
	var i := 0
	var pts := []
	var x := 5.0
	while x < r.size.x - 4:
		pts.append(Vector2(x, 1))
		x += 7.0
	var y := 8.0
	while y < r.size.y - 4:
		pts.append(Vector2(r.size.x - 2, y))
		y += 7.0
	x = r.size.x - 5.0
	while x > 4:
		pts.append(Vector2(x, r.size.y - 2))
		x -= 7.0
	y = r.size.y - 8.0
	while y > 4:
		pts.append(Vector2(1, y))
		y -= 7.0
	for p in pts:
		var on: bool = (i * 5 + chase) % 9 != 0
		c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color("#ffe9a8") if on else Color("#5a3a1a"))
		if on:
			c.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.85, 0.5, 0.18))
		i += 1
	var lit: float = 0.25 if _flicker > 0.0 and int(_t * 30.0) % 2 == 0 else 1.0
	Art.neon(c, Vector2(r.size.x / 2.0, 30), "ROULETTER", 24, P.GOLD, 1.0, lit)
	Art.neon(c, Vector2(r.size.x / 2.0, 58), "THE GILDED ACE  -  1974", 8, P.DANGER, 1.0, 1.0 if int(_t * 1.5) % 6 != 0 else 0.6)


func _draw_board() -> void:
	var c := board_view
	var r := Rect2(Vector2.ZERO, BOARD.size)
	var hot: bool = board_view.is_hovered()
	c.draw_rect(r, Color("#0e1a12"))
	c.draw_rect(r, P.GOLD if hot else P.LINE.darkened(0.4), false, 1.0)
	Art.icon(c, "cash", Vector2(14, 16), 1)
	Art.text(c, P.font(), Vector2(26, 13), board_text[0], 8, P.GOLD)
	Art.text(c, P.font(), Vector2(26, 25), board_text[1], 8, P.CREAM if hot else P.DIM)
	var bar := Rect2(200, 9, 110, 6)
	c.draw_rect(bar, Color("#05100a"))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(board_text[2]), bar.size.y)), P.GOLD.lerp(P.GOOD, float(board_text[2])))
	c.draw_rect(bar, P.LINE.darkened(0.5), false, 1.0)
	c.draw_string(P.font(), Vector2(250, 26), "PAWN SHOP >", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.GOLD if hot else P.DIM)


## A cream ticket stub with a perforated edge, for the run waiting to be continued.
func _draw_ticket() -> void:
	var c := ticket_view
	var r := Rect2(Vector2.ZERO, TICKET.size)
	c.draw_rect(r, Color("#e8dcc0"))
	c.draw_rect(Rect2(0, 0, 24, r.size.y), Color("#c94a3a"))
	for yy in range(2, int(r.size.y), 4):
		c.draw_rect(Rect2(24, yy, 1, 2), Color("#8a7a60"))
	Art.text(c, P.font(), Vector2(12, 26), "RUN", 8, P.CREAM, true)
	c.draw_rect(r, Color("#8a6420"), false, 1.0)


func refresh() -> void:
	var p = main.profile
	var saved: bool = main.has_saved_run()
	continue_btn.visible = saved
	ticket_view.visible = false
	new_btn.custom_minimum_size.x = 196 if saved else 324
	new_btn.size.x = new_btn.custom_minimum_size.x
	if saved:
		var r = RunState.new()
		if r.load_from(main.run_save_path()):
			var top := "%s  -  NIGHT %d  -  %s" % [Wheels.get_def(r.wheel_id).name.to_upper(), r.night + 1,
				"IN THE CAGE" if r.phase == RunState.Phase.SHOP else (r.table_name() + " table").to_upper()]
			var mode := ""
			if r.challenge != "":
				mode = Content.CHALLENGES[r.challenge].name
			elif r.weekly != "":
				mode = "Weekly challenge"
			elif r.grade > 0:
				mode = "Grade %d marker" % (r.grade + 1)
			var ks: Array = main.kit_summary(r)
			continue_info.text = "\n".join([top, "Marker $%s left  -  $%d cash  -  seed %d%s" % [P.money(r.marker_left()), r.cash, r.run_seed, ("  -  " + mode) if mode != "" else ""],
				", ".join(ks) if not ks.is_empty() else "No chips on the felt yet"])
			ticket_view.visible = true
	var nu: Dictionary = p.next_unlock()
	board_text[0] = "MARKERS  %d" % p.markers
	if nu.is_empty():
		board_text[1] = "Everything in the Pawn Shop is yours"
		board_text[2] = 1.0
	elif p.markers >= nu.cost:
		board_text[1] = "%s is ready to buy!" % nu.name
		board_text[2] = 1.0
	else:
		board_text[1] = "Next: %s at %d" % [nu.name, nu.cost]
		board_text[2] = float(p.markers) / float(nu.cost)
	info_lbl.text = "RUNS %d    WINS %d    BEST NIGHT %d    BEST TAKE %d" % [p.runs, p.wins, p.best_night, p.best_take]

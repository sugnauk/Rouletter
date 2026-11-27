extends Control
## The home screen, floating over the live table (scenes/ui/table_scene.gd, hosted full-window
## by main.gd): the ROULETTER neon, a slim gold text menu down the left, the Markers plaque
## (click it for the Pawn Shop), and NEW RUN / CONTINUE as the only lit marquees, with the
## run you left as a ticket stub beside them. A soft shade keeps the text readable.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Version := preload("res://core/version.gd")
const RunState := preload("res://core/run_state.gd")
const Wheels := preload("res://core/wheels.gd")
const Content := preload("res://core/content.gd")

const PLAQUE := Vector2(156, 30)
const TICKET := Vector2(316, 44)

var main
var continue_btn   ## lit marquees (scenes/ui/marquee_button.gd)
var new_btn
var info_lbl: Label
var continue_info: Label
var shade: Control       ## darkens the side the menu floats on
var sign_view: Control
var board_view: Control
var ticket_view: Control
var links: Array = []    ## the text menu
var _t := 0.0
var _flicker := 0.0
var board_text := ["", "", 0.0]   ## markers line, next-unlock line, progress 0..1
var portrait := false
var hint_lbl: Label
var ver_lbl: Label


func setup() -> void:
	shade = Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_shade)
	add_child(shade)
	sign_view = Control.new()
	sign_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_view.draw.connect(_draw_sign)
	add_child(sign_view)
	# The Markers plaque doubles as the way into the Pawn Shop.
	board_view = Button.new()
	board_view.flat = true
	board_view.focus_mode = Control.FOCUS_NONE
	board_view.draw.connect(_draw_board)
	board_view.pressed.connect(func():
		Sfx.play("click")
		main.show_screen("pawn"))
	board_view.mouse_entered.connect(board_view.queue_redraw)
	board_view.mouse_exited.connect(board_view.queue_redraw)
	add_child(board_view)
	for b in [["Pawn Shop", func(): main.show_screen("pawn")], ["Casebook", func(): _casebook("collection")],
			["How to Play", func(): _casebook("guide")], ["Options", func(): main.open_options()],
			["Credits", func(): main.show_screen("credits")], ["Quit", func(): get_tree().quit()]]:
		links.append(P.link(self, b[0].to_upper(), b[1], Vector2(150, 18)))
	info_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	# The run you left, as a ticket stub.
	ticket_view = Control.new()
	ticket_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket_view.draw.connect(_draw_ticket)
	add_child(ticket_view)
	continue_info = P.label(ticket_view, "", P.FONT_SMALL, P.BLACK)
	continue_info.add_theme_constant_override("line_spacing", -1)
	continue_info.clip_text = true
	# Only these two are lit marquees.
	new_btn = P.button(self, "NEW RUN", func(): main.begin_flow(), Vector2(200, 40), P.FONT_BIG)
	new_btn.add_theme_font_override("font", P.title_font())
	new_btn.pulse = true
	new_btn.marquee = true
	continue_btn = P.button(self, "CONTINUE", func(): main.continue_run(), Vector2(110, 40), P.FONT)
	continue_btn.accent = P.CYAN
	continue_btn.marquee = true
	# On the web, phones get the tip that matters: home-screen play is truly full screen.
	var hint := "On a phone: Share > Add to Home Screen plays full screen. Options > Screen fit if it's cut off." if OS.has_feature("web") \
		else "F2: CRT filter    F11: fullscreen"
	hint_lbl = P.label(self, hint, P.FONT_SMALL, P.DIM)
	ver_lbl = P.label(self, Version.label(), P.FONT_SMALL, P.DIM)
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	relayout(false)


## Landscape: everything floats down the left, the table plays on the right. Portrait: the logo
## over the table at the top, the menu and the lit buttons under it.
func relayout(tall: bool) -> void:
	portrait = tall
	P.place(shade, Vector2.ZERO, Vector2(P.W, P.H))
	if not tall:
		P.place(sign_view, Vector2(14, 12), Vector2(260, 64))
		P.place(board_view, Vector2(474, 12), PLAQUE)
		for i in range(links.size()):
			P.place(links[i], Vector2(24, 92 + i * 20), Vector2(150, 18))
		P.place(info_lbl, Vector2(28, 218), Vector2(300, 10))
		P.place(ticket_view, Vector2(24, 244), TICKET)
		P.place(continue_info, Vector2(30, 5), Vector2(TICKET.x - 34, 36))
		P.place(new_btn, Vector2(24, 296))
		P.place(continue_btn, Vector2(230, 296))
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		P.place(hint_lbl, Vector2(28, 344), Vector2(360, 10))
		P.place(ver_lbl, Vector2(408, 344), Vector2(224, 10))
	else:
		P.place(sign_view, Vector2(50, 10), Vector2(260, 64))
		P.place(board_view, Vector2(102, 76), PLAQUE)
		for i in range(links.size()):
			P.place(links[i], Vector2(24 + (i % 2) * 166, 380 + (i / 2) * 22), Vector2(150, 18))
		P.place(info_lbl, Vector2(28, 448), Vector2(310, 10))
		P.place(new_btn, Vector2(20, 466))
		P.place(continue_btn, Vector2(20, 514))
		P.place(ticket_view, Vector2(136, 512), Vector2(204, 44))
		P.place(continue_info, Vector2(30, 5), Vector2(170, 36))
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		P.place(hint_lbl, Vector2(20, 570), Vector2(320, 24))
		P.place(ver_lbl, Vector2(116, 624), Vector2(224, 10))
	if main != null:
		refresh()


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


## A soft shade under the menu: from the left in landscape, up from the bottom on a phone.
func _draw_shade() -> void:
	var c := shade
	if portrait:   # the menu half of the phone: fade the near felt into a dark floor
		for i in range(10):
			c.draw_rect(Rect2(0, 300 + i * 8.0, P.W, 8), Color(0.02, 0.01, 0.02, 0.09 * (i + 1)))
		c.draw_rect(Rect2(-400, 380, P.W + 800, P.H - 380 + 800), Color(0.02, 0.01, 0.02, 0.9))   # on past the frame on tall phones
	for i in range(12):
		var a := 0.62 * (1.0 - i / 12.0)
		if portrait:
			pass
		else:
			c.draw_rect(Rect2(i * 30.0, -400, 30, P.H + 800), Color(0.02, 0.01, 0.02, a))
	if not portrait:   # on past the frame's left edge on wide phones
		c.draw_rect(Rect2(-800, -400, 800, P.H + 800), Color(0.02, 0.01, 0.02, 0.62))
	if portrait:   # and a little at the top behind the logo
		for i in range(4):
			c.draw_rect(Rect2(0, i * 26.0, P.W, 26), Color(0.02, 0.01, 0.02, 0.4 - i * 0.1))


## The ROULETTER neon, floating free (it still flickers now and then, like an old tube).
func _draw_sign() -> void:
	var c := sign_view
	var w: float = c.size.x
	var lit: float = 0.25 if _flicker > 0.0 and int(_t * 30.0) % 2 == 0 else 1.0
	Art.neon(c, Vector2(w / 2.0, 22), "ROULETTER", 24, P.GOLD, 1.0, lit)
	Art.neon(c, Vector2(w / 2.0, 50), "THE GILDED ACE  -  1974", 8, P.DANGER, 1.0, 1.0 if int(_t * 1.5) % 6 != 0 else 0.6)


## The Markers plaque: brass on lacquer, a thin progress bar to the next unlock.
func _draw_board() -> void:
	var c := board_view
	var r := Rect2(Vector2.ZERO, PLAQUE)
	var hot: bool = board_view.is_hovered()
	c.draw_rect(r.grow(1), Color(0, 0, 0, 0.5))
	c.draw_rect(r, Color(0.07, 0.05, 0.07, 0.92))
	c.draw_rect(r, P.GOLD if hot else Color("#8a6a3a"), false, 1.0)
	Art.icon(c, "cash", Vector2(12, 15), 1)
	Art.text(c, P.font(), Vector2(24, 12), board_text[0], 8, P.GOLD)
	Art.text(c, P.font(), Vector2(PLAQUE.x - 6 - P.font().get_string_size("PAWN SHOP >", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 12), "PAWN SHOP >", 8, P.GOLD if hot else P.DIM)
	var bar := Rect2(24, 18, PLAQUE.x - 32, 4)
	c.draw_rect(bar, Color("#05100a"))
	c.draw_rect(Rect2(bar.position, Vector2(floor(bar.size.x * float(board_text[2])), bar.size.y)), P.GOLD.lerp(P.GOOD, float(board_text[2])))
	if hot:
		Art.text(c, P.font(), Vector2(4, PLAQUE.y + 10), board_text[1], 8, P.CREAM)


## A cream ticket stub with a perforated edge, for the run waiting to be continued.
func _draw_ticket() -> void:
	var c := ticket_view
	var r := Rect2(Vector2.ZERO, ticket_view.size)
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
	var nw: float = 320.0 if portrait else (200.0 if saved else 316.0)
	new_btn.custom_minimum_size.x = nw
	new_btn.size.x = nw
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

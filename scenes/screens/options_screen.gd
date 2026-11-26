extends Control
## Options: display and comfort settings, saved in the profile.

const P := preload("res://scenes/ui/palette.gd")

const ITEMS := [
	["crt", "CRT filter", "Scanlines and a soft vignette over the whole screen (F2 toggles it anywhere)."],
	["cb_marks", "Colour-blind marks", "A small cross on every red square of the felt, so red and black don't rely on colour alone."],
	["cards", "Loading cards", "The themed cards between screens. Off switches screens instantly."],
	["shake", "Screen shake", "Shake on big wins and busts."],
	["fast_spins", "Fast spins", "A short wheel spin and a brisk count. Big moments still get their beat."],
	["zoom_felt", "Tap-to-zoom felt", "Clicking the felt first zooms it in, so splits and corners are easy to hit. Always on for touch screens."],
]

var main
var buttons: Dictionary = {}
var detail: Label
var reset_btn: Button
var reset_confirm := false
var fit_lbl: Button


func setup() -> void:
	P.place(P.label(self, "OPTIONS", P.FONT_BIG, P.GOLD), Vector2(16, 8))
	var y := 50
	for it in ITEMS:
		var b := P.button(self, "", _toggle.bind(it[0]), Vector2(260, 24))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func(): detail.text = it[2])
		P.place(b, Vector2(16, y))
		buttons[it[0]] = [b, it[1]]
		y += 28
	var panel := Panel.new()
	P.place(panel, Vector2(292, 50), Vector2(332, 114))
	add_child(panel)
	detail = P.label(panel, "Hover an option.", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(8, 8), Vector2(316, 100))
	for v in [["music", "Music volume", "The lounge band (and its darker cousin at Enforcer tables)."], ["sfx", "Sound volume", "Chips, the wheel, coins and fanfares."]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		P.place(row, Vector2(16, y))
		add_child(row)
		var minus := P.button(row, "-", _nudge.bind(v[0], -0.1), Vector2(24, 24))
		var lbl := P.button(row, "", func(): pass, Vector2(204, 24))
		lbl.mouse_entered.connect(func(): detail.text = v[2])
		minus.mouse_entered.connect(func(): detail.text = v[2])
		P.button(row, "+", _nudge.bind(v[0], 0.1), Vector2(24, 24))
		buttons[v[0]] = [lbl, v[1]]
		y += 28
	# Screen fit: for phone browsers that hide part of the page under their bars.
	var fit_tip := "Shrinks the game and pins it to the top of the screen. Use it if a phone browser cuts off the bottom (try 90%). On iPhone, Share > Add to Home Screen plays full screen."
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 4)
	P.place(frow, Vector2(16, y))
	add_child(frow)
	var fminus := P.button(frow, "-", _nudge_fit.bind(-1), Vector2(24, 24))
	fit_lbl = P.button(frow, "", func(): pass, Vector2(204, 24))
	P.button(frow, "+", _nudge_fit.bind(1), Vector2(24, 24))
	for c in [fminus, fit_lbl]:
		c.mouse_entered.connect(func(): detail.text = fit_tip)
	y += 28
	P.place(P.label(self, "F11: fullscreen    Keys at the table: 1/2/3 chip size, Z undo, C clear, Space spin", P.FONT_SMALL, P.DIM), Vector2(16, y + 6))
	P.place(P.button(self, "Back", func(): main.close_options(), Vector2(80, 22)), Vector2(16, 326))
	P.place(P.button(self, "Credits", func(): main.show_screen("credits"), Vector2(80, 22)), Vector2(104, 326))
	reset_btn = P.button(self, "Reset progress", _reset, Vector2(140, 22))
	P.place(reset_btn, Vector2(484, 326))


func refresh() -> void:
	reset_confirm = false
	reset_btn.text = "Reset progress"
	reset_btn.visible = main.options_return == "" or main.options_return == "title"
	for k in buttons:
		var val = main.profile.settings.get(k, false)
		if val is bool:
			buttons[k][0].text = "%s:  %s" % [buttons[k][1], "ON" if val else "OFF"]
		else:
			var bars := int(round(val * 10.0))
			buttons[k][0].text = "%s  %s" % [buttons[k][1], "|".repeat(bars) + ".".repeat(10 - bars)]
	var fit: float = float(main.profile.settings.get("fit", 1.0))
	fit_lbl.text = "Screen fit:  %s" % ("FULL" if fit >= 0.999 else "%d%%  (top)" % int(round(fit * 100.0)))


## Wipe Markers, unlocks, Feats, story and stats (options are kept). Two clicks.
func _reset() -> void:
	if not reset_confirm:
		reset_confirm = true
		reset_btn.text = "Really? Click again"
		detail.text = "This wipes your Markers, unlocks, Feats, story pages and stats, and any saved run. Your options are kept."
		Sfx.play("lose")
		return
	main.reset_progress()
	reset_confirm = false
	reset_btn.text = "Progress reset"
	detail.text = "A clean slate. Mr. Vance doesn't remember you. Yet."


func _nudge(key: String, d: float) -> void:
	main.set_option(key, clampf(snappedf(main.profile.settings.get(key, 0.5) + d, 0.1), 0.0, 1.0))
	Sfx.play("click")


func _nudge_fit(d: int) -> void:
	var Profile := preload("res://core/profile.gd")
	var cur: float = float(main.profile.settings.get("fit", 1.0))
	main.set_option("fit", clampf(snappedf(cur + d * Profile.FIT_STEP, Profile.FIT_STEP), Profile.FIT_MIN, 1.0))
	Sfx.play("click")


func _toggle(key: String) -> void:
	Sfx.play("click")
	main.set_option(key, not main.profile.settings.get(key, false))

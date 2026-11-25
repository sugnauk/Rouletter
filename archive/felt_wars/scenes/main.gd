extends Control
## Prototype UI for Felt Wars. Built in code so the whole layout lives in one readable file.
## All rules live in res://core; this script only draws state and forwards clicks.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")
const Content := preload("res://core/content.gd")
const Resolver := preload("res://core/resolver.gd")
const RunState := preload("res://core/run_state.gd")
const Wheel := preload("res://scenes/wheel.gd")

const CELL_W := 54
const CELL_H := 58
const GOLD := Color(1.0, 0.8, 0.2)
const VIOLET := Color(0.72, 0.32, 1.0)
const FELT_GREEN := Color(0.05, 0.3, 0.15)

var run
var tool := {"kind": "perm", "value": 1}
var spinning := false

var felt_buttons := {}
var screens := {}
var lbl_bankroll: Label
var lbl_bank: Label
var bar_bank: ProgressBar
var lbl_spins: Label
var lbl_ev: Label
var lbl_dealer: Label
var lbl_msg: Label
var log_box: RichTextLabel
var rack_box: VBoxContainer
var info_label: Label
var wheel
var spin_btn: Button
var map_box: VBoxContainer
var spoils_box: VBoxContainer
var event_box: VBoxContainer
var end_box: VBoxContainer


func _ready() -> void:
	run = get_node("/root/Game").run if has_node("/root/Game") else RunState.new()
	_build_ui()
	run.changed.connect(_refresh)
	run.start_run(int(Time.get_unix_time_from_system()))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_on_spin()


# --- Layout ---------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.12, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_right = -12
	root.offset_top = 8
	root.offset_bottom = -8
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	root.add_child(top)
	lbl_bankroll = _label(top, "", 20, GOLD)
	var bank_col := VBoxContainer.new()
	top.add_child(bank_col)
	lbl_bank = _label(bank_col, "", 14, VIOLET)
	bar_bank = ProgressBar.new()
	bar_bank.custom_minimum_size = Vector2(220, 10)
	bar_bank.show_percentage = false
	bank_col.add_child(bar_bank)
	lbl_spins = _label(top, "", 16, Color.WHITE)
	lbl_ev = _label(top, "", 16, Color(0.6, 1.0, 0.7))
	lbl_dealer = _label(top, "", 16, Color(0.9, 0.85, 0.75))

	lbl_msg = _label(root, "", 15, Color(0.95, 0.95, 0.9))
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stack)

	screens.table = _build_table()
	map_box = _screen_box()
	screens.map = map_box.get_parent()
	spoils_box = _screen_box()
	screens.spoils = spoils_box.get_parent()
	event_box = _screen_box()
	screens.event = event_box.get_parent()
	end_box = _screen_box()
	screens.end = end_box.get_parent()
	for k in screens:
		stack.add_child(screens[k])


func _screen_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


func _build_table() -> Control:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)

	var left := VBoxContainer.new()
	h.add_child(left)
	wheel = Wheel.new()
	wheel.custom_minimum_size = Vector2(260, 260)
	left.add_child(wheel)
	spin_btn = Button.new()
	spin_btn.custom_minimum_size = Vector2(260, 48)
	spin_btn.add_theme_font_size_override("font_size", 20)
	spin_btn.pressed.connect(_on_spin)
	left.add_child(spin_btn)
	info_label = _label(left, "", 13, Color(0.85, 0.85, 0.8))
	info_label.custom_minimum_size = Vector2(260, 0)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var felt := Control.new()
	felt.custom_minimum_size = Vector2(CELL_W * 14, CELL_H * 5)
	mid.add_child(felt)
	_build_felt(felt)
	_label(mid, "Resolution order: base -> felt upgrades -> chip effects -> House Rules", 12, Color(0.6, 0.7, 0.6))
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 13)
	mid.add_child(log_box)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(190, 0)
	h.add_child(right)
	_label(right, "CHIP RACK", 15, GOLD)
	rack_box = VBoxContainer.new()
	right.add_child(rack_box)
	return h


func _build_felt(felt: Control) -> void:
	var zero := _felt_button(felt, "S0", Rect2(0, 0, CELL_W, CELL_H * 3))
	zero.tooltip_text = "0"
	for n in range(1, 37):
		var x := (Board.grid_col(n) + 1) * CELL_W
		var y := (2 - Board.grid_row(n)) * CELL_H
		_felt_button(felt, Board.straight_key(n), Rect2(x, y, CELL_W, CELL_H))
	for r in range(3):
		_felt_button(felt, "COL%d" % (r + 1), Rect2(13 * CELL_W, (2 - r) * CELL_H, CELL_W, CELL_H))
	for d in range(3):
		_felt_button(felt, "DOZ%d" % (d + 1), Rect2((1 + d * 4) * CELL_W, 3 * CELL_H, CELL_W * 4, CELL_H))
	var evens := ["LOW", "EVEN", "RED", "BLACK", "ODD", "HIGH"]
	for i in range(evens.size()):
		_felt_button(felt, evens[i], Rect2((1 + i * 2) * CELL_W, 4 * CELL_H, CELL_W * 2, CELL_H))


func _felt_button(parent: Control, key: String, rect: Rect2) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size - Vector2(2, 2)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_bet.bind(key))
	parent.add_child(b)
	felt_buttons[key] = b
	return b


func _label(parent: Node, text: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable, min_size := Vector2(320, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	return s


# --- Refresh --------------------------------------------------------------------

func _refresh() -> void:
	lbl_bankroll.text = "Bankroll %d" % run.bankroll
	var p: int = run.phase
	var at_table: bool = p ==RunState.Phase.TABLE or (p == RunState.Phase.SPOILS and run.pending_upgrade != "")
	if p == RunState.Phase.TABLE:
		lbl_bank.text = "Table bank %d / %d" % [run.table.bank, run.table.bank_start]
		bar_bank.max_value = run.table.bank_start
		bar_bank.value = run.table.bank
		lbl_spins.text = "Spins left %d" % run.table.spins_left
		var ev: Dictionary = run.expected_value()
		lbl_ev.text = "EV/spin %+.1f (bank %+.1f)" % [ev.player, ev.bank]
		lbl_dealer.text = Content.DEALERS[run.table.dealer].name + ("  [PIT BOSS]" if run.table.boss else "")
	else:
		lbl_bank.text = "Tables broken: %d" % run.tables_won
		bar_bank.value = 0
		lbl_spins.text = ""
		lbl_ev.text = ""
		lbl_dealer.text = ""
	lbl_msg.text = run.message
	for k in screens:
		screens[k].visible = false
	if at_table:
		screens.table.visible = true
		_refresh_table()
	elif p == RunState.Phase.MAP:
		screens.map.visible = true
		_refresh_map()
	elif p == RunState.Phase.SPOILS:
		screens.spoils.visible = true
		_refresh_spoils()
	elif p == RunState.Phase.EVENT:
		screens.event.visible = true
		_refresh_event()
	else:
		screens.end.visible = true
		_refresh_end()


func _refresh_table() -> void:
	var targets: Array = run.upgrade_targets()
	for key in felt_buttons:
		var b: Button = felt_buttons[key]
		var felt = run.felt
		var lines := []
		var tip := []
		var bg := FELT_GREEN
		var border := Color(0.2, 0.45, 0.3)
		var width := 1
		if Board.is_straight(key):
			var n := Board.straight_number(key)
			bg = Color(0.05, 0.4, 0.2) if n == 0 else (Color(0.6, 0.1, 0.1) if Board.is_red(n) else Color(0.12, 0.12, 0.12))
			var up: String = felt.square_upgrades.get(n, "")
			lines.append(str(n) + _upgrade_tag(up))
			var pv: int = felt.raw_value(n, Chip.Side.PLAYER)
			var hv: int = felt.raw_value(n, Chip.Side.HOUSE)
			var marks := ""
			if pv > 0:
				marks += "Y%d" % pv
			if hv > 0:
				marks += (" " if marks != "" else "") + "H%d" % hv
			lines.append(marks)
			var o: int = felt.owner(n)
			if o == Chip.Side.PLAYER:
				border = GOLD
				width = 4
			elif o == Chip.Side.HOUSE:
				border = VIOLET
				width = 4
			if up != "":
				tip.append(Content.UPGRADES[up].name + ": " + Content.UPGRADES[up].desc)
			if o == Chip.Side.HOUSE and felt.is_flanked(n):
				tip.append("Flanked: weakens every spin")
				lines[0] += " !"
			if felt.is_walled(n):
				tip.append("Walled street: the House can't place here")
		else:
			lines.append(_outside_name(key) + (" HOT" if felt.bet_upgrades.get(key, "") == "hot" else ""))
			var total := 0
			for c in felt.chips_on(key, Chip.Side.PLAYER):
				total += c.value
			lines.append("Y%d" % total if total > 0 else "")
			if total > 0:
				border = GOLD
				width = 3
		for c in felt.chips_on(key):
			tip.append(("You: " if c.side == Chip.Side.PLAYER else "House: ") + "%s x%d" % [Content.CHIPS.get(c.kind, {"name": "House"}).name, c.value])
		var special := ""
		for c in felt.chips_on(key, Chip.Side.PLAYER):
			if c.kind != "perm" and c.kind != "temp":
				special += Content.CHIPS[c.kind].name.substr(0, 2) + " "
		if special != "":
			lines.append(special.strip_edges())
		if run.last_result.get("pocket", -1) == (Board.straight_number(key) if Board.is_straight(key) else -99):
			bg = bg.lightened(0.35)
		if key in targets:
			bg = Color(0.25, 0.5, 0.9)
		b.text = "\n".join(lines)
		b.tooltip_text = "\n".join(tip) if not tip.is_empty() else key
		var s := _style(bg, border, width)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", _style(bg.lightened(0.15), border, width))
		b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.2), border, width))
	wheel.felt = run.felt
	wheel.queue_redraw()
	spin_btn.disabled = spinning or run.phase != RunState.Phase.TABLE
	spin_btn.text = "SPIN  (space)" if run.phase == RunState.Phase.TABLE else "Lay your upgrade"
	_refresh_rack()
	_refresh_info()


func _upgrade_tag(up: String) -> String:
	match up:
		"gilded":
			return " G"
		"link":
			return " L"
		"double_felt":
			return " D"
	return ""


func _outside_name(key: String) -> String:
	match key:
		"COL1", "COL2", "COL3":
			return "2:1"
		"DOZ1":
			return "1st 12"
		"DOZ2":
			return "2nd 12"
		"DOZ3":
			return "3rd 12"
		"LOW":
			return "1-18"
		"HIGH":
			return "19-36"
	return key.capitalize()


func _refresh_rack() -> void:
	for c in rack_box.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	_label(rack_box, "Permanent (stays)", 12, Color(0.7, 0.8, 0.7))
	for v in Content.PERM_SIZES:
		_rack_button(group, "Perm x%d  (%dc)" % [v, run.perm_cost(v)], "perm", v)
	_label(rack_box, "Bet (one spin, fair odds)", 12, Color(0.7, 0.8, 0.7))
	for v in Content.TEMP_SIZES:
		_rack_button(group, "Bet %d" % v, "temp", v)
	if not run.inventory.is_empty():
		_label(rack_box, "Seized chips (free)", 12, Color(0.7, 0.8, 0.7))
		for k in run.inventory:
			var b := _rack_button(group, "%s x%d" % [Content.CHIPS[k].name, run.inventory[k]], k, 1)
			b.tooltip_text = Content.CHIPS[k].desc
	if tool.kind not in ["perm", "temp"] and not run.inventory.has(tool.kind):
		tool = {"kind": "perm", "value": 1}
		_refresh_rack()


func _rack_button(group: ButtonGroup, text: String, kind: String, value: int) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.button_pressed = tool.kind == kind and tool.value == value
	b.pressed.connect(func(): tool = {"kind": kind, "value": value})
	rack_box.add_child(b)
	return b


func _refresh_info() -> void:
	var lines := []
	if run.phase == RunState.Phase.TABLE:
		lines.append(Content.DEALERS[run.table.dealer].desc)
	for r in run.felt.pit_rules:
		lines.append("Pit Boss rule - %s: %s" % [Content.PIT_RULES[r].name, Content.PIT_RULES[r].desc])
	if not run.felt.house_rules.is_empty():
		lines.append("")
		lines.append("Your House Rules:")
		for r in run.felt.house_rules:
			lines.append(" - %s: %s" % [Content.HOUSE_RULES[r].name, Content.HOUSE_RULES[r].desc])
	if run.felt.red_streak > 0 and run.felt.has_rule("red_streak"):
		lines.append("Red streak: %d" % run.felt.red_streak)
	lines.append("")
	lines.append("Gold border = yours, violet = House. Most chip value on a number owns it (House wins ties). Ball on a House square: it collects 35x its stack and seizes your chips covering it. Own 3 neighbours to flank; own a whole street to wall it.")
	info_label.text = "\n".join(lines)


func _refresh_map() -> void:
	_clear(map_box)
	_label(map_box, "THE CASINO FLOOR", 26, GOLD)
	var avail: Array = run.available_nodes()
	for layer in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		map_box.add_child(row)
		for node in run.floor_map:
			if node.layer != layer:
				continue
			var text := ""
			match node.type:
				"table":
					text = "Table: %s" % Content.DEALERS[node.dealer].name
				"event":
					text = "Back room: %s" % Content.EVENTS[node.event].name
				"boss":
					text = "PIT BOSS (%s)" % Content.PIT_RULES[node.pit].name
			if node.done:
				text += "  [done]"
			var b := _button(row, text, run.enter_node.bind(node.id), Vector2(300, 52))
			b.disabled = node.id not in avail


func _refresh_spoils() -> void:
	_clear(spoils_box)
	_label(spoils_box, "SPOILS: seize one from the House", 24, GOLD)
	for i in range(run.spoils.size()):
		var s: Dictionary = run.spoils[i]
		var b := _button(spoils_box, "%s\n%s" % [run.spoil_name(s), run.spoil_desc(s)], run.take_spoil.bind(i), Vector2(560, 64))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(spoils_box, "Take nothing", run.skip_spoils, Vector2(560, 40))


func _refresh_event() -> void:
	_clear(event_box)
	var e: Dictionary = Content.EVENTS[run.event_id]
	_label(event_box, e.name, 26, GOLD)
	var d := _label(event_box, e.desc, 16, Color.WHITE)
	d.custom_minimum_size = Vector2(520, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(e.options.size()):
		_button(event_box, e.options[i], run.choose_event.bind(i))


func _refresh_end() -> void:
	_clear(end_box)
	var won: bool = run.phase == RunState.Phase.VICTORY
	_label(end_box, "VICTORY" if won else "GAME OVER", 40, GOLD if won else VIOLET)
	_label(end_box, run.message, 18, Color.WHITE)
	_label(end_box, "Tables broken: %d   Final bankroll: %d" % [run.tables_won, run.bankroll], 16, Color(0.8, 0.8, 0.8))
	_button(end_box, "New run", func(): run.start_run(int(Time.get_unix_time_from_system())))


func _clear(box: Node) -> void:
	for c in box.get_children():
		c.queue_free()


# --- Actions --------------------------------------------------------------------

func _on_bet(key: String) -> void:
	if spinning:
		return
	if run.phase == RunState.Phase.SPOILS and run.pending_upgrade != "":
		if not run.apply_upgrade(key):
			lbl_msg.text = "That upgrade can't go there. Pick a highlighted spot."
		return
	if run.phase != RunState.Phase.TABLE:
		return
	var ok := false
	match tool.kind:
		"perm":
			ok = run.buy_perm(key, tool.value)
		"temp":
			ok = run.place_temp(key, tool.value)
		_:
			ok = run.place_special(tool.kind, key)
	if not ok:
		lbl_msg.text = "Can't place %s on %s (cost, or wrong kind of spot)." % [Content.CHIPS[tool.kind].name, key]


func _on_spin() -> void:
	if spinning or run.phase != RunState.Phase.TABLE:
		return
	spinning = true
	spin_btn.disabled = true
	wheel.highlight = -1
	var pocket: int = run.rng.pocket()
	var idx: int = Board.WHEEL_ORDER.find(pocket)
	var base: float = floor(wheel.ball_angle / TAU) * TAU
	var target: float = base + TAU * 4.0 + wheel.angle_for(idx)
	var tw := create_tween()
	tw.tween_property(wheel, "ball_angle", target, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_spin.bind(pocket))


func _finish_spin(pocket: int) -> void:
	spinning = false
	wheel.highlight = pocket
	var res: Dictionary = run.spin(pocket)
	_write_log(res)
	_refresh()


func _write_log(res: Dictionary) -> void:
	if res.is_empty():
		return
	var p: int = res.pocket
	var who := "nobody"
	if res.owner == Chip.Side.PLAYER:
		who = "[color=#ffcc33]you[/color]"
	elif res.owner == Chip.Side.HOUSE:
		who = "[color=#b84dff]the House[/color]"
	var net: int = res.player
	var lines := ["[b]Ball: %d (%s), held by %s.  You %+d, bank %+d[/b]" % [p, Board.colour_name(p), who, net, res.bank]]
	if res.has("capped"):
		lines.append("The bank ran dry (%d unpaid)." % res.capped)
	for l in Resolver.log_lines(res):
		lines.append(l)
	for l in run.house_log:
		lines.append("[color=#b84dff][house] %s[/color]" % l)
	log_box.text = "\n".join(lines)

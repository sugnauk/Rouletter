extends Control
## Screen router. Owns the screens, the dialogue overlay, screen shake and the CRT filter.
## Game rules live in res://core; screens only draw state and forward input.

const P := preload("res://scenes/ui/palette.gd")
const DialogueBox := preload("res://scenes/ui/dialogue_box.gd")
const Backdrop := preload("res://scenes/ui/backdrop.gd")
const FxLayer := preload("res://scenes/ui/fx.gd")
const Transition := preload("res://scenes/ui/transition.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")
const RunState := preload("res://core/run_state.gd")
const Profile := preload("res://core/profile.gd")

const SCREENS := {
	"card": preload("res://scenes/screens/card_screen.gd"),
	"title": preload("res://scenes/screens/title_screen.gd"),
	"select": preload("res://scenes/screens/select_screen.gd"),
	"table": preload("res://scenes/screens/table_screen.gd"),
	"shop": preload("res://scenes/screens/shop_screen.gd"),
	"end": preload("res://scenes/screens/end_screen.gd"),
	"pawn": preload("res://scenes/screens/pawn_screen.gd"),
}

var run
var profile
var frame: Control  ## the fixed 640x360 play area, centred in whatever window we get
var stage: Control
var screens: Dictionary = {}
var current: String = ""
var dialogue
var fx
var crt: CanvasLayer
var transition
var fast_ui := false
var shake_t := 0.0
var shake_amt := 0.0
var pending_lines: Array = []
var last_summary: Dictionary = {}


func _ready() -> void:
	theme = P.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var game := get_node_or_null("/root/Game")
	if game != null:
		run = game.run
		profile = game.profile
		fast_ui = game.fast_ui
	else:
		run = RunState.new()
		profile = Profile.new()
	add_child(Backdrop.new())
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(640, 360)
	add_child(frame)
	resized.connect(_recenter)
	_recenter()
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(stage)
	for k in SCREENS:
		var s: Control = SCREENS[k].new()
		s.set("main", self)
		s.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.visible = false
		stage.add_child(s)
		s.call("setup")
		screens[k] = s
	fx = FxLayer.new()
	frame.add_child(fx)
	dialogue = DialogueBox.new()
	frame.add_child(dialogue)
	crt = CanvasLayer.new()
	crt.layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	rect.material = mat
	crt.add_child(rect)
	add_child(crt)
	var tl := CanvasLayer.new()
	tl.layer = 9
	transition = Transition.new()
	tl.add_child(transition)
	add_child(tl)
	run.changed.connect(_on_run_changed)
	run.table_cleared.connect(_on_table_cleared)
	run.run_ended.connect(_on_run_ended)
	show_screen("title" if fast_ui else "card")


func _recenter() -> void:
	frame.position = ((size - Vector2(640, 360)) / 2.0).floor()


func _on_run_changed() -> void:
	if screens.has(current) and screens[current].visible:
		screens[current].call("refresh")


func show_screen(n: String) -> void:
	for s in screens.values():
		s.visible = false
	current = n
	screens[n].visible = true
	screens[n].call("refresh")


## Switch screens behind a themed loading card (title + subtitle), or instantly when the
## card is empty or the UI runs in fast mode. Queued story lines play once the card lifts.
func go(n: String, title: String = "", subtitle: String = "", accent: Color = P.GOLD) -> void:
	if title == "" or fast_ui:
		show_screen(n)
		_flush_lines()
		return
	transition.play(title, subtitle, func():
		show_screen(n)
		_flush_lines.call_deferred(), accent)


func _flush_lines() -> void:
	if not pending_lines.is_empty():
		var lines := pending_lines
		pending_lines = []
		say(lines)


## The card shown before a table: night and table name, or the Enforcer's name and rule.
func table_card() -> Array:
	if run.table.boss:
		var e: Dictionary = Content.ENFORCERS[run.table.enforcer]
		return ["NIGHT %d" % (run.night + 1), "%s  -  %s" % [e.name, e.desc], P.DANGER]
	return ["NIGHT %d" % (run.night + 1), "%s table  -  pay %d" % [run.table_name(), run.table.target], P.GOLD]


## Go wherever the run's phase says, then play any queued story lines.
func route() -> void:
	match run.phase:
		RunState.Phase.TABLE:
			var card := table_card()
			go("table", card[0], card[1], card[2])
		RunState.Phase.SHOP:
			var names := []
			for v in run.shop.vendors:
				names.append(Content.VENDORS[v].name)
			go("shop", "THE CAGE", " and ".join(names) + " are open", P.GOLD)
		_:
			if run.phase == RunState.Phase.VICTORY:
				go("end", "PAID IN FULL", "Mr. Vance almost smiles", P.GOOD)
			else:
				go("end", "LAST CALL", "The marker stays on the books", P.DANGER)


func begin_flow() -> void:
	if "intro" not in profile.seen_beats:
		say(Story.INTRO, func():
			profile.seen_beats.append("intro")
			save_profile()
			show_screen("select"))
	else:
		show_screen("select")


func start_run(wheel: String) -> void:
	run.start_run(int(Time.get_unix_time_from_system()) ^ randi(), wheel, profile.unlocked)
	Sfx.play("click")
	var card := table_card()
	go("table", card[0], card[1], card[2])


func _on_table_cleared(info: Dictionary) -> void:
	if info.boss:
		var e: Dictionary = Content.ENFORCERS[info.enforcer]
		pending_lines.append({"speaker": e.name, "text": e.defeat})


func _on_run_ended(won: bool) -> void:
	var res: Dictionary = profile.record_run(run.nights_cleared, run.total_take, won)
	last_summary = {"won": won, "take": run.total_take, "nights": run.nights_cleared,
		"paid": res.paid, "markers": res.markers}
	save_profile()


func say(lines: Array, done: Callable = Callable()) -> void:
	dialogue.say(lines, done)


func shake(amount: float, t: float = 0.3) -> void:
	shake_amt = amount
	shake_t = t


func save_profile() -> void:
	profile.save()


func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		var a := int(ceil(shake_amt * clampf(shake_t / 0.3, 0.0, 1.0)))
		stage.position = Vector2(randi_range(-a, a), randi_range(-a, a))
	elif stage.position != Vector2.ZERO:
		stage.position = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			crt.visible = not crt.visible
		elif event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()


func toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 720)
		w.move_to_center()
	else:
		w.mode = Window.MODE_FULLSCREEN


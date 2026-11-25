extends Control
## Screen router. Owns the screens, the dialogue overlay, screen shake and the CRT filter.
## Game rules live in res://core; screens only draw state and forward input.

const P := preload("res://scenes/ui/palette.gd")
const DialogueBox := preload("res://scenes/ui/dialogue_box.gd")
const Backdrop := preload("res://scenes/ui/backdrop.gd")
const FxLayer := preload("res://scenes/ui/fx.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")
const RunState := preload("res://core/run_state.gd")
const Profile := preload("res://core/profile.gd")

const SCREENS := {
	"title": preload("res://scenes/screens/title_screen.gd"),
	"select": preload("res://scenes/screens/select_screen.gd"),
	"table": preload("res://scenes/screens/table_screen.gd"),
	"shop": preload("res://scenes/screens/shop_screen.gd"),
	"end": preload("res://scenes/screens/end_screen.gd"),
	"pawn": preload("res://scenes/screens/pawn_screen.gd"),
}

var run
var profile
var stage: Control
var screens: Dictionary = {}
var current: String = ""
var dialogue
var fx
var crt: CanvasLayer
var shake_t := 0.0
var shake_amt := 0.0
var pending_lines: Array = []
var last_summary: Dictionary = {}


func _ready() -> void:
	theme = P.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var game := get_node_or_null("/root/Game")
	if game != null:
		run = game.run
		profile = game.profile
	else:
		run = RunState.new()
		profile = Profile.new()
	add_child(Backdrop.new())
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	for k in SCREENS:
		var s: Control = SCREENS[k].new()
		s.set("main", self)
		s.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.visible = false
		stage.add_child(s)
		s.call("setup")
		screens[k] = s
	fx = FxLayer.new()
	add_child(fx)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	crt = CanvasLayer.new()
	crt.layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	rect.material = mat
	crt.add_child(rect)
	add_child(crt)
	run.changed.connect(_on_run_changed)
	run.table_cleared.connect(_on_table_cleared)
	run.run_ended.connect(_on_run_ended)
	show_screen("title")


func _on_run_changed() -> void:
	if screens.has(current) and screens[current].visible:
		screens[current].call("refresh")


func show_screen(n: String) -> void:
	for s in screens.values():
		s.visible = false
	current = n
	screens[n].visible = true
	screens[n].call("refresh")


## Go wherever the run's phase says, then play any queued story lines.
func route() -> void:
	match run.phase:
		RunState.Phase.TABLE:
			show_screen("table")
		RunState.Phase.SHOP:
			show_screen("shop")
		_:
			show_screen("end")
	if not pending_lines.is_empty():
		var lines := pending_lines
		pending_lines = []
		say(lines)


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
	show_screen("table")


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


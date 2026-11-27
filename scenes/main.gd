extends Control
## Screen router. Owns the screens, the dialogue overlay, screen shake and the CRT filter.
## Game rules live in res://core; screens only draw state and forward input.

const P := preload("res://scenes/ui/palette.gd")
const Tutorial := preload("res://core/tutorial.gd")
const DialogueBox := preload("res://scenes/ui/dialogue_box.gd")
const Backdrop := preload("res://scenes/ui/backdrop.gd")
const FxLayer := preload("res://scenes/ui/fx.gd")
const Transition := preload("res://scenes/ui/transition.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const InfoCard := preload("res://scenes/ui/info_card.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")
const RunState := preload("res://core/run_state.gd")
const Profile := preload("res://core/profile.gd")
const Feats := preload("res://core/feats.gd")

const SCREENS := {
	"card": preload("res://scenes/screens/card_screen.gd"),
	"title": preload("res://scenes/screens/title_screen.gd"),
	"select": preload("res://scenes/screens/select_screen.gd"),
	"table": preload("res://scenes/screens/table_screen.gd"),
	"shop": preload("res://scenes/screens/shop_screen.gd"),
	"end": preload("res://scenes/screens/end_screen.gd"),
	"pawn": preload("res://scenes/screens/pawn_screen.gd"),
	"casebook": preload("res://scenes/screens/casebook_screen.gd"),
	"options": preload("res://scenes/screens/options_screen.gd"),
	"credits": preload("res://scenes/screens/credits_screen.gd"),
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
var pause
var card   ## the pop-up info card for chips, rules and vouchers (scenes/ui/info_card.gd)
var options_return := ""   ## screen the Options screen goes back to (when opened mid-run)
var fast_ui := false
var shake_t := 0.0
var shake_amt := 0.0
var pending_lines: Array = []
var last_summary: Dictionary = {}
var last_clear: Dictionary = {}    ## the last table_cleared info, for the reward tally
var last_layout: Dictionary = {}   ## the bets on the felt when a table was missed (end screen)
var run_feats: Array = []          ## Feats earned during the current run (end screen)


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
	card = InfoCard.new()
	frame.add_child(card)
	dialogue = DialogueBox.new()
	frame.add_child(dialogue)
	pause = PauseMenu.new()
	pause.main = self
	frame.add_child(pause)
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
	crt.visible = profile.settings.crt
	Sfx.set_volumes(profile.settings.music, profile.settings.sfx)
	apply_speed()
	Sfx.play_music.call_deferred("lounge")
	get_tree().create_timer(4.0).timeout.connect(func(): Sfx.preload_track("enforcer"))
	var tl := CanvasLayer.new()
	tl.layer = 9
	transition = Transition.new()
	tl.add_child(transition)
	add_child(tl)
	run.changed.connect(_on_run_changed)
	run.table_cleared.connect(_on_table_cleared)
	run.run_ended.connect(_on_run_ended)
	show_screen("title" if fast_ui else "card")


## The part of the window that's really on screen, as fractions of it: {top, height, width}.
## On phones the browser can make the page taller than what's visible (iPhone Safari's bars);
## the web build measures window.visualViewport to find out. 1.0 everywhere else.
var visible_frac := {"top": 0.0, "height": 1.0, "width": 1.0}
var _view_poll := 0.0


## Fit the 640x360 play area into the visible part of the window. It's centred, as before,
## unless the screen is cut off (or the player asked for Screen fit), when it shrinks to fit and
## sits at the top of what's visible, so nothing ends up under a toolbar or off the bottom.
func _recenter() -> void:
	var fit: float = clampf(float(profile.settings.get("fit", 1.0)), Profile.FIT_MIN, 1.0) if profile != null else 1.0
	var vis_pos := Vector2(0, size.y * visible_frac.top)
	var vis_size := Vector2(size.x * visible_frac.width, size.y * visible_frac.height)
	_set_portrait(vis_size.y > vis_size.x * 1.05 and _screen_has_portrait())
	var dim := Vector2(P.W, P.H)
	# Landscape never scales up (the window always gives at least 640x360); portrait fills the width.
	var s: float = minf(vis_size.x / dim.x, vis_size.y / dim.y) * fit
	if not P.portrait:
		s = minf(1.0, s)
	var clipped: bool = visible_frac.height < 0.999 or visible_frac.top > 0.001
	frame.scale = Vector2(s, s)
	var used := dim * s
	var x: float = vis_pos.x + (vis_size.x - used.x) / 2.0
	var y: float = vis_pos.y + ((vis_size.y - used.y) / 2.0 if not (clipped or fit < 0.999) else 0.0)
	frame.position = Vector2(x, y).floor()


## Does the screen on show have a portrait layout yet? (Screens without one keep landscape.)
func _screen_has_portrait() -> bool:
	return screens.has(current) and screens[current].has_method("relayout")


## Switch the play area between 640x360 and 360x640, and re-lay out everything on it.
func _set_portrait(on: bool) -> void:
	if on == P.portrait and frame.size == Vector2(P.W, P.H):
		return
	P.portrait = on
	P.W = 360.0 if on else 640.0
	P.H = 640.0 if on else 360.0
	frame.size = Vector2(P.W, P.H)
	for k in screens:
		if screens[k].has_method("relayout"):
			screens[k].relayout(on)
	for o in [dialogue, pause]:
		if o != null:
			o.relayout()
	if card != null:
		card.hide_card()


## Web only: ask the page how much of the canvas is actually visible.
func _measure_view() -> void:
	if not OS.has_feature("web"):
		return
	# JavaScriptBridge only hands back plain values, so the page answers with "height,top,width".
	var raw = JavaScriptBridge.eval("(function(){var v=window.visualViewport;var h=window.innerHeight||1,w=window.innerWidth||1;" +
		"if(!v)return '1,0,1';return [Math.min(1,v.height/h),Math.max(0,v.offsetTop/h),Math.min(1,v.width/w)].join(',');})()", true)
	if not (raw is String):
		return
	var r: PackedStringArray = raw.split(",")
	if r.size() < 3:
		return
	var nf := {"top": clampf(float(r[1]), 0.0, 0.5), "height": clampf(float(r[0]), 0.5, 1.0), "width": clampf(float(r[2]), 0.5, 1.0)}
	if absf(nf.height - visible_frac.height) > 0.005 or absf(nf.top - visible_frac.top) > 0.005 or absf(nf.width - visible_frac.width) > 0.005:
		visible_frac = nf
		_recenter()


func _on_run_changed() -> void:
	if screens.has(current) and screens[current].visible:
		screens[current].call("refresh")


func show_screen(n: String) -> void:
	for s in screens.values():
		s.visible = false
	current = n
	if card != null:
		card.hide_card()
	screens[n].visible = true
	_recenter()
	screens[n].call("refresh")
	if n == "table" or n == "shop":
		save_run()
	if n == "end" and last_summary.get("won", false):
		Sfx.play_music("victory")
	else:
		Sfx.play_music("enforcer" if n == "table" and not run.table.is_empty() and run.table.boss else "lounge")
	if n != "table":
		Sfx.set_tension(0.0)


# --- Run saves: the run in progress is kept next to the profile ---------------------------

func run_save_path() -> String:
	return profile.save_path.get_basename() + "_run.save"


func save_run() -> void:
	if not fast_ui or profile.save_path != Profile.DEFAULT_PATH:
		run.save_to(run_save_path())


func has_saved_run() -> bool:
	return FileAccess.file_exists(run_save_path())


func delete_saved_run() -> void:
	if has_saved_run():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_save_path()))


func continue_run() -> void:
	if run.load_from(run_save_path()):
		run_feats = []
		Sfx.play("click")
		route()
	else:
		delete_saved_run()
		screens.title.refresh()


## Switch screens behind a themed loading card (title + subtitle), or instantly when the
## card is empty or the UI runs in fast mode. Queued story lines play once the card lifts.
func go(n: String, title: String = "", subtitle: String = "", accent: Color = P.GOLD, who: String = "") -> void:
	if title == "" or fast_ui or not profile.settings.cards:
		show_screen(n)
		_flush_lines()
		return
	transition.play(title, subtitle, func():
		show_screen(n)
		_flush_lines.call_deferred(), accent, who)


func _flush_lines() -> void:
	if not pending_lines.is_empty():
		var lines := pending_lines
		pending_lines = []
		say(lines)


## The card shown before a table: night and table name, or the Enforcer's name and rule.
func table_card() -> Array:
	if run.table.boss:
		var e: Dictionary = Content.ENFORCERS[run.table.enforcer]
		return ["NIGHT %d" % (run.night + 1), "%s  -  %s" % [e.name, e.desc], P.DANGER if not e.get("final", false) else P.GOLD, e.name]
	if run.upstairs() and run.table_idx == 0:
		return ["NIGHT %d" % (run.night + 1), "The Floor Above  -  %s  -  pay %d" % [run.table_name(), run.table.target], P.VIOLET]
	if run.table_idx == 0:
		return ["NIGHT %d" % (run.night + 1), "%s table  -  pay %d  -  marker $%s left" % [run.table_name(), run.table.target, P.money(run.marker_left())], P.GOLD]
	return ["NIGHT %d" % (run.night + 1), "%s table  -  pay %d" % [run.table_name(), run.table.target], P.GOLD]


## Go wherever the run's phase says, then play any queued story lines.
func route() -> void:
	match run.phase:
		RunState.Phase.TABLE:
			var card := table_card()
			go("table", card[0], card[1], card[2], card[3] if card.size() > 3 else "")
		RunState.Phase.SHOP:
			var names := []
			if tutorial_on():
				tutorial_did("shop")
			elif Story.TUTORIAL.shop.id not in profile.seen_beats:
				_queue_scene(Story.TUTORIAL.shop)
			for it in run.shop.stock:
				profile.note_seen(it.id)
			for v in run.shop.vendors:
				names.append(Content.VENDORS[v].name)
				var intro: Dictionary = Story.VENDOR_INTROS.get(v, {})
				if not intro.is_empty() and intro.id not in profile.seen_beats:
					_queue_scene(intro)
			if run.overflow > 0:
				tip("spare")
			if run.shop.stock.any(func(it): return it.get("flaw", "") != ""):
				tip("flaw")
			if run.shop.stock.any(func(it): return it.type in ["chip", "upgrade", "rule"] and Content.rarity_of(it.id) != "common"):
				tip("rarity")
			go("shop", "THE CAGE", " and ".join(names) + (" is open" if names.size() == 1 else " are open"), P.GOLD)
		_:
			if run.phase == RunState.Phase.VICTORY:
				go("end", "THE OWNER FALLS" if run.acts == 2 else "PAID IN FULL", "The Floor Above is yours, for tonight" if run.acts == 2 else "Mr. Vance almost smiles", P.GOOD)
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


## opts: {seed (0 = random), challenge, starter, weekly}
var last_share_code := ""   ## the weekly run just finished, as a code to share


func start_run(wheel: String, acts: int = 1, grade: int = 0, opts: Dictionary = {}) -> void:
	var seed_v: int = opts.get("seed", 0)
	if seed_v == 0:
		seed_v = (int(Time.get_unix_time_from_system()) ^ randi()) % 1000000000
	var g: int = grade if opts.get("weekly", "") != "" or opts.get("challenge", "") != "" else mini(grade, profile.max_grade())
	opts = opts.duplicate()
	opts.new_player = profile.best_night == 0 and profile.wins == 0
	run.start_run(seed_v, wheel, profile.unlocked, acts, g, opts)
	run_feats = []
	last_layout = {}
	Sfx.play("click")
	# A brand-new player's first run on the European wheel is guided, one step at a time.
	tutorial = null
	_tut_said = -1
	if Tutorial.DONE_ID not in profile.seen_beats and wheel == "european" and opts.get("challenge", "") == "" \
			and opts.get("weekly", "") == "" and opts.get("starter", "") == "":
		tutorial = Tutorial.new()
		run.table_offer = []
	elif Story.TUTORIAL.table.id not in profile.seen_beats:
		_queue_scene(Story.TUTORIAL.table)
	var card := table_card()
	go("table", card[0], card[1], card[2], card[3] if card.size() > 3 else "")


## Check Feats for an event and pay out any newly earned ones.
func check_feats(event: String, ctx: Dictionary) -> void:
	ctx.run = run
	var got := Feats.check(event, ctx, profile.feats)
	if got.is_empty():
		return
	for id in got:
		var f: Dictionary = Feats.FEATS[id]
		profile.feats.append(id)
		profile.markers += f.reward
		run_feats.append(id)
		fx.toast("FEAT: " + f.name.to_upper(), "+%d Marker%s" % [f.reward, "" if f.reward == 1 else "s"])
	save_profile()


func _on_table_cleared(info: Dictionary) -> void:
	last_clear = info
	check_feats("clear", {"info": info})
	if info.boss:
		var e: Dictionary = Content.ENFORCERS[info.enforcer]
		pending_lines.append({"speaker": e.name, "text": e.defeat})
		if run.phase == RunState.Phase.SHOP:
			_queue_scene(Story.interlude(run.night + 1, profile))


## Queue a one-time tip (Story.TIPS) if it hasn't been shown before.
func tip(key: String, now: bool = false) -> void:
	var t: Dictionary = Story.TIPS[key]
	if t.id in profile.seen_beats:
		return
	if now:
		profile.seen_beats.append(t.id)
		save_profile()
		say(t.lines)
	else:
		_queue_scene(t)


## Queue a story scene to play after the next loading card, and remember it for the Journal.
func _queue_scene(scene: Dictionary) -> void:
	if scene.is_empty():
		return
	pending_lines.append_array(scene.lines)
	if scene.id not in profile.seen_beats:
		profile.seen_beats.append(scene.id)
		save_profile()


func _on_run_ended(won: bool) -> void:
	delete_saved_run()
	check_feats("end", {"won": won, "wheels_won": profile.wheels_won})
	if won and run.challenge != "":
		var lvl: int = run.grade / 2 + 1
		profile.challenge_level[run.challenge] = maxi(int(profile.challenge_level.get(run.challenge, 0)), lvl)
	if run.weekly != "":
		var code: String = RunState.share_code(run.weekly, run.nights_cleared, int(run.total_take), won)
		profile.weekly_runs = profile.weekly_runs.filter(func(r): return r.id == run.weekly)
		profile.weekly_runs.append({"id": run.weekly, "nights": run.nights_cleared, "take": int(run.total_take), "won": won, "code": code})
		profile.weekly_runs.sort_custom(func(a, b): return [a.won, a.nights, a.take] > [b.won, b.nights, b.take])
		profile.weekly_runs = profile.weekly_runs.slice(0, 5)
		last_share_code = code
		DisplayServer.clipboard_set(code)
	if won and not run.wheel_id in profile.wheels_won:
		profile.wheels_won.append(run.wheel_id)
	var paid: int = run.marker_paid()
	profile.add_history({"wheel": run.wheel_id, "acts": run.acts, "nights": run.nights_cleared,
		"take": int(run.total_take), "best_spin": int(run.best_spin), "won": won, "grade": run.grade,
		"seed": run.run_seed, "challenge": run.challenge, "weekly": run.weekly, "kit": _kit_summary()})
	var res: Dictionary = profile.record_run(run.nights_cleared, run.total_take, won, run.acts, paid, run.grade)
	if run.weekly != "":
		var wb: Dictionary = profile.weekly_best
		if wb.get("id", "") != run.weekly or run.nights_cleared > int(wb.get("nights", -1)) or (won and not wb.get("won", false)):
			profile.weekly_best = {"id": run.weekly, "nights": run.nights_cleared, "won": won, "take": int(run.total_take)}
	last_summary = {"won": won, "take": run.total_take, "nights": run.nights_cleared,
		"paid": paid, "marker": run.marker_total(), "markers": res.markers, "feats": run_feats.duplicate(),
		"best_spin": run.best_spin, "beaten": run.beaten.duplicate()}
	save_profile()


## The run's key chips, biggest first (for the history and the Continue card).
func _kit_summary() -> Array:
	return kit_summary(run)


static func kit_summary(r) -> Array:
	var chips: Array = r.felt.perm_chips()
	chips.sort_custom(func(a, b): return a.value > b.value)
	var out := []
	for c in chips.slice(0, 3):
		out.append("%s%s" % [Content.CHIPS[c.kind].name, (" x%d" % c.value) if c.value > 1 else ""])
	return out


func say(lines: Array, done: Callable = Callable()) -> void:
	dialogue.say(lines, done)


# --- The guided first run (core/tutorial.gd) ----------------------------------------------------

var tutorial = null      ## a Tutorial while the first run is being guided, else null
var _tut_said := -1      ## the step Dolores last explained


func tutorial_on() -> bool:
	return tutorial != null and tutorial.active


## Dolores explains the current step (once), with a Skip button on every line.
func tutorial_prompt() -> void:
	if not tutorial_on() or dialogue.is_open() or _tut_said == tutorial.idx:
		return
	if current == "table" and screens.table.spinning:   # wait for the count to finish
		return
	_tut_said = tutorial.idx
	var lines := []
	for t in tutorial.step().say:
		lines.append({"speaker": "Dolores", "text": t})
	dialogue.on_skip = end_tutorial
	dialogue.say(lines, func():
		dialogue.on_skip = Callable()
		_refresh_current())


## The player did something the tutorial may be waiting for.
func tutorial_did(action: String, key: String = "") -> void:
	if not tutorial_on():
		return
	if tutorial.did(action, key):
		if not tutorial.active:
			end_tutorial()
		else:
			tutorial_prompt.call_deferred()


func end_tutorial() -> void:
	if tutorial != null:
		tutorial.finish()
	tutorial = null
	dialogue.on_skip = Callable()
	if Tutorial.DONE_ID not in profile.seen_beats:
		profile.seen_beats.append(Tutorial.DONE_ID)
		# The tutorial covered these: don't repeat them as first-time tips.
		for id in [Story.TUTORIAL.table.id, Story.TUTORIAL.shop.id]:
			if id not in profile.seen_beats:
				profile.seen_beats.append(id)
		save_profile()
	_refresh_current()


func _refresh_current() -> void:
	if screens.has(current) and screens[current].visible:
		screens[current].call("refresh")


## A short buzz on phones (Options > Vibration). kind: tick | place | win | big | jackpot.
func buzz(kind: String) -> void:
	if not profile.settings.get("vibrate", true) or not DisplayServer.is_touchscreen_available():
		return
	var ms: int = {"tick": 8, "place": 12, "win": 20, "big": 45, "jackpot": 90}.get(kind, 10)
	Input.vibrate_handheld(ms)


func shake(amount: float, t: float = 0.3) -> void:
	if not profile.settings.shake:
		return
	shake_amt = amount
	shake_t = t


func save_profile() -> void:
	profile.save()


func _process(delta: float) -> void:
	_view_poll -= delta
	if _view_poll <= 0.0:
		_view_poll = 0.5
		_measure_view()
	if shake_t > 0.0:
		shake_t -= delta
		var a := int(ceil(shake_amt * clampf(shake_t / 0.3, 0.0, 1.0)))
		stage.position = Vector2(randi_range(-a, a), randi_range(-a, a))
	elif stage.position != Vector2.ZERO:
		stage.position = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and in_run() and not pause.visible and not dialogue.is_open():
			open_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and in_run() and not dialogue.is_open():
			cycle_speed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			set_option("crt", not profile.settings.crt)
		elif event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()


# --- Pause menu ------------------------------------------------------------------------

func in_run() -> bool:
	return current in ["table", "shop"] and (run.phase == RunState.Phase.TABLE or run.phase == RunState.Phase.SHOP)


func open_pause() -> void:
	if current == "table" and screens.table.spinning:
		return
	pause.open()


## Options, remembering where to go back to.
func open_options(from_run: bool = false) -> void:
	options_return = current if from_run else "title"
	show_screen("options")


func close_options() -> void:
	var back := options_return if options_return != "" else "title"
	options_return = ""
	if back == "table" or back == "shop":
		show_screen(back)
	else:
		show_screen("title")


func reset_progress() -> void:
	profile.reset()
	delete_saved_run()
	save_profile()


func quit_to_title() -> void:
	save_run()
	go("title", "LAST ORDERS", "Your seat is kept for you", P.GOLD)


func abandon_run() -> void:
	if run.abandon():
		route()


## Change one option, apply it straight away and save it.
## The info card beside a control (rack tokens, rules) or a spot on a felt view.
func card_near(ctrl: Control, d: Dictionary) -> void:
	card.show_at(fx.local(ctrl.global_position + Vector2(ctrl.size.x, 0)), d)


func card_at_felt(felt_view, key: String, d: Dictionary) -> void:
	card.show_at(fx.local(felt_view.key_global(key)), d)


func hide_card() -> void:
	card.hide_card()


func set_option(key: String, value) -> void:
	profile.settings[key] = value
	crt.visible = profile.settings.crt
	_recenter()
	apply_speed()
	Sfx.set_volumes(profile.settings.music, profile.settings.sfx)
	save_profile()
	if screens.has(current) and screens[current].visible:
		screens[current].call("refresh")


## --- Game speed (the >> button) -------------------------------------------------------

func speed() -> int:
	return clampi(int(profile.settings.get("speed", 0)), 0, Profile.SPEEDS.size() - 1)


## The everyday time scale for the chosen speed (1.0 for screenshot runs, which need fixed timing).
func base_time_scale() -> float:
	return 1.0 if fast_ui else float(Profile.SPEEDS[speed()].time)


func apply_speed() -> void:
	Engine.time_scale = base_time_scale()


## Fastest also cuts the wheel spin and the count short.
func short_spins() -> bool:
	return bool(Profile.SPEEDS[speed()].short)


func cycle_speed() -> void:
	set_option("speed", (speed() + 1) % Profile.SPEEDS.size())
	Sfx.play("click")
	fx.pop_text(Vector2(560, 40), "SPEED: " + str(Profile.SPEEDS[speed()].name).to_upper(), P.GOLD, 0.8)


func toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 720)
		w.move_to_center()
	else:
		w.mode = Window.MODE_FULLSCREEN


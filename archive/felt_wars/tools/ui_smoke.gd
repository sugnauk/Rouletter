extends SceneTree
## Scripted UI smoke test with screenshots (needs a window, not --headless):
##   godot --path . --script res://tools/ui_smoke.gd -- <out_dir>
## Drives the real main scene: map -> table -> place chips -> spin, saving PNGs.

var main
var t := 0.0
var step := 0
var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	var plan := [
		[0.4, func(): main.run.start_run(7)],
		[0.5, func(): shot("1_map")],
		[0.6, func(): main.run.enter_node(0)],
		[0.8, func():
			main._on_bet("S17")
			main.tool = {"kind": "perm", "value": 5}
			main._on_bet("S20")
			main.tool = {"kind": "magnet", "value": 1}
			main._on_bet("S8")
			main.tool = {"kind": "temp", "value": 5}
			main._on_bet("RED")
			main._refresh()],
		[1.2, func(): shot("2_table")],
		[1.3, func(): main._on_spin()],
		[3.6, func(): shot("3_after_spin")],
		[3.7, func():
			for i in range(10):
				if main.run.phase != 1:
					break
				if main.run.felt.owner(20) != 0:
					main.run.buy_perm("S20", 1)
				main._finish_spin(20)],
		[4.2, func(): shot("4_spoils")],
		[4.3, func(): print("phase=", main.run.phase, " msg=", main.run.message)],
	]
	while step < plan.size() and t >= plan[step][0]:
		plan[step][1].call()
		step += 1
	return step >= plan.size()


func shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)

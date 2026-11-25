extends Node
## Scripted UI smoke test with screenshots. Runs inside the real game (autoloads included):
##   godot --path . -- smoke=<out_dir> profile=user://smoke_profile.json
## Walks title -> intro dialogue -> wheel select -> table -> spin -> shop -> upgrade ->
## Enforcer -> game over -> Pawn Shop, saving a PNG at each stop, then quits.

var out_dir := "user://"
var t := 0.0
var step := 0
var main


func _process(delta: float) -> void:
	t += delta
	if main == null:
		main = get_tree().current_scene
		return
	var run = main.run
	var plan := [
		[0.6, func(): shot("01_title")],
		[0.7, func(): main.begin_flow()],
		[1.6, func(): shot("02_intro_dialogue")],
		[1.7, func(): _close_dialogue()],
		[2.0, func(): shot("03_select")],
		[2.1, func(): main.start_run("european")],
		[2.3, func():
			run.place_chip(0, "S30")
			run.place_bet("S17", 5)
			run.place_bet("DOZ2", 5)
			run.place_bet("RED", 3)],
		[2.6, func(): shot("04_table_bets")],
		[2.7, func(): main.screens.table._on_spin()],
		[4.8, func(): shot("05a_counting")],
		[7.0, func(): shot("05_after_spin")],
		[7.1, func():
			var guard := 0
			while run.phase == 0 and guard < 20:
				guard += 1
				run.place_bet("S17", mini(5, run.table.stack))
				run.spin(17)
			run.cash = 40
			main.route()],
		[9.6, func(): shot("06_shop")],
		[9.7, func():
			for i in range(run.shop.stock.size()):
				if run.shop.stock[i].type == "upgrade":
					run.buy(i)
			main.screens.shop.refresh()],
		[10.0, func(): shot("07_shop_upgrade_target")],
		[10.1, func():
			if run.shop.pending_upgrade != "":
				run.apply_upgrade(run.upgrade_targets()[0])
			run.table_idx = 2
			run.leave_shop()
			main.route()],
		[10.9, func(): shot("08_enforcer")],
		[11.0, func():
			_close_dialogue()
			run.table.spins_left = 1
			run.spin(_empty_pocket(run))
			main.route()],
		[14.4, func(): shot("09_game_over")],
		[14.5, func(): main.show_screen("pawn")],
		[14.8, func(): shot("10_pawn")],
		[15.0, func(): get_tree().quit()],
	]
	while step < plan.size() and t >= plan[step][0]:
		plan[step][1].call()
		step += 1


func _close_dialogue() -> void:
	var guard := 0
	while main.dialogue.is_open() and guard < 100:
		guard += 1
		main.dialogue.advance()


func _empty_pocket(run) -> int:
	for p in run.felt.board.pockets:
		var covered := false
		for c in run.felt.chips:
			if p in run.felt.board.bet(c.bet).numbers:
				covered = true
		if not covered:
			return p
	return 0


func shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(n + ".png")
	img.save_png(path)
	print("saved ", path)


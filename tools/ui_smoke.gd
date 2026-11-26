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
		[2.5, func():
			_close_dialogue()
			main.profile.settings.cb_marks = true
			main.screens.table.refresh()],
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
		[9.5, func(): _close_dialogue()],
		[9.6, func(): shot("06_shop")],
		[9.8, func(): _staff(["cashier", "fence"])],
		[10.0, func(): shot("06b_shop_fence")],
		[10.1, func(): _staff(["cashier", "loan_shark"])],
		[10.3, func(): shot("06c_shop_loan_shark")],
		[10.4, func():
			main.run.overflow = 14
			_staff(["cashier", "dealer"])],
		[10.55, func(): shot("06d_shop_dealer")],
		[10.6, func(): _staff(["cashier", "pit_boss"])],
		[10.7, func():
			for i in range(run.shop.stock.size()):
				if run.shop.stock[i].type == "upgrade":
					run.buy(i)
			main.screens.shop.refresh()],
		[11, func(): shot("07_shop_upgrade_target")],
		[11.1, func():
			if run.shop.pending_upgrade != "":
				run.apply_upgrade(run.upgrade_targets()[0])
			run.table_idx = 2
			run.leave_shop()
			main.route()],
		[11.9, func(): shot("08_enforcer")],
		[12, func():
			_close_dialogue()
			run.table.spins_left = 1
			run.spin(_empty_pocket(run))
			main.route()],
		[15.4, func(): shot("09_game_over")],
		[15.5, func(): main.show_screen("pawn")],
		[15.8, func(): shot("10_pawn")],
		[16.0, func(): main.show_screen("journal")],
		[16.2, func(): shot("10b_journal")],
		[16.3, func(): main.show_screen("options")],
		[16.5, func(): shot("10c_options")],
		[16.7, func():
			main.fast_ui = false
			main.show_screen("card")],
		[19.4, func(): shot("11_title_card")],
		[19.5, func():
			main.screens.card.done = true
			main.go("title", "NIGHT 2", "High Roller table  -  pay 28")],
		[20.1, func(): shot("12_loading_card")],
		[21.4, func(): get_tree().quit()],
	]
	while step < plan.size() and t >= plan[step][0]:
		plan[step][1].call()
		step += 1


## Put specific vendors in the Cage (for screenshots of each window).
func _staff(vendors: Array) -> void:
	var run = main.run
	if not "fence" in run.unlocked:
		run.unlocked.append("fence")
	run.shop.vendors = vendors
	run._restock()
	main.screens.shop.refresh()


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


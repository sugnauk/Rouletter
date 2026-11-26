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
		[2.6, func(): main.screens.table._zoom()],
		[2.8, func(): shot("04z_zoomed_felt")],
		[2.85, func(): main.screens.table._unzoom()],
		[3, func(): shot("04_table_bets")],
		[3.1, func(): main.screens.table._on_spin()],
		[5.2, func(): shot("05a_counting")],
		[6.6, func():
			main.last_clear = {"take": 12.0, "target": 8, "table": 0, "spins_left": 3, "comps": 1, "reward": 7}
			main.screens.table._show_tally()],
		[7.4, func(): shot("05_after_spin")],
		[7.5, func():
			var guard := 0
			while run.phase == 0 and guard < 20:
				guard += 1
				run.place_bet("S17", mini(5, run.table.stack))
				run.spin(17)
			run.cash = 40
			main.route()],
		[9.9, func(): _close_dialogue()],
		[10, func(): shot("06_shop")],
		[10.05, func(): _staff(["cashier"])],
		[10.15, func(): shot("06e_shop_cashier_only")],
		[10.2, func():
			var it: Dictionary = main.run.shop.stock[0]
			main.screens.shop._describe("%s  -  CHIP  %s" % [main.run.item_name(it), main.run.price_text(it)], main.run.item_desc(it) + "\nYou own one: stack this on it to level it up.\nWorks with your Magnet, Gilded Number.\nGood against Big Sal at the next table.")],
		[10.35, func(): shot("06f_shop_hover")],
		[10.5, func(): _staff(["cashier", "fence"])],
		[10.7, func(): shot("06b_shop_fence")],
		[10.8, func(): _staff(["cashier", "loan_shark"])],
		[11, func(): shot("06c_shop_loan_shark")],
		[11.1, func():
			main.run.overflow = 14
			_staff(["cashier", "dealer"])],
		[11.25, func(): shot("06d_shop_dealer")],
		[11.3, func(): _staff(["cashier", "pit_boss"])],
		[11.4, func():
			for i in range(run.shop.stock.size()):
				if run.shop.stock[i].type == "upgrade":
					run.buy(i)
			main.screens.shop.refresh()],
		[11.7, func(): shot("07_shop_upgrade_target")],
		[11.8, func():
			if run.shop.pending_upgrade != "":
				run.apply_upgrade(run.upgrade_targets()[0])
			run.table_idx = 2
			run.leave_shop()
			main.route()],
		[12.6, func(): shot("08_enforcer")],
		[12.7, func():
			_close_dialogue()
			run.table.spins_left = 1
			run.spin(_empty_pocket(run))
			main.route()],
		[16.1, func(): shot("09_game_over")],
		[16.2, func(): main.show_screen("pawn")],
		[16.5, func(): shot("10_pawn")],
		[16.7, func(): main.show_screen("journal")],
		[16.9, func(): shot("10b_journal")],
		[17, func(): main.show_screen("options")],
		[17.2, func(): shot("10c_options")],
		[17.4, func():
			main.fast_ui = false
			main.show_screen("card")],
		[20.1, func(): shot("11_title_card")],
		[20.2, func():
			main.screens.card.done = true
			main.go("title", "NIGHT 2", "High Roller table  -  pay 28")],
		[20.8, func(): shot("12_loading_card")],
		[22.1, func():
			main.profile.feats = ["straight_up", "jackpot", "beat_sal"]
			main.show_screen("feats")
			main.fx.toast("FEAT: STRAIGHT UP", "+1 Marker")],
		[22.5, func(): shot("13_feats")],
		[22.7, func():
			main.profile.seen_items = ["perm", "magnet", "gilded", "la_partage", "patience"]
			main.profile.used_items = ["perm"]
			main.screens.feats.tab = "almanac"
			main.screens.feats.refresh()],
		[23, func(): shot("14_almanac")],
		[23.2, func():
			main.show_screen("title")
			main.say([{"speaker": "Mr. Vance", "text": "Portrait check."}])],
		[23.5, func(): shot("15_portrait_vance")],
		[23.6, func():
			main.dialogue.lines = [{"speaker": "Dolores", "text": "Portrait check."}]
			main.dialogue.idx = 0
			main.dialogue._show_line()],
		[23.9, func(): shot("16_portrait_dolores")],
		[24, func():
			main.dialogue.lines = [{"speaker": "Madame Oro", "text": "Portrait check."}]
			main.dialogue._show_line()],
		[24.3, func(): shot("17_portrait_oro")],
		[24.5, func(): get_tree().quit()],
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


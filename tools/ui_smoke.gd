extends Node

const Content := preload("res://core/content.gd")
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
		[0.7, func():
			main.profile.best_grade = 2
			main.screens.select.grade = 2
			main.begin_flow()],
		[1.6, func(): shot("02_intro_dialogue")],
		[1.7, func(): _close_dialogue()],
		[2, func(): shot("03_select")],
		[2.1, func(): main.start_run("european")],
		[2.3, func():
			run.place_chip(0, "S30")
			while not run.inventory.is_empty():
				run.place_chip(0, "S8")
			run.place_bet("S17", 5)
			run.place_bet("DOZ2", 5)
			run.place_bet("RED", 3)],
		[2.5, func():
			_close_dialogue()
			main.profile.settings.cb_marks = true
			main.screens.table.pinned = {"RED": true}
			main.screens.table.refresh()],
		[2.55, func(): shot("04s_table_offer")],
		[2.6, func():
			run.skip_table_offer()
			main.screens.table.refresh()
			main.screens.table._zoom()],
		[2.8, func(): shot("04z_zoomed_felt")],
		[2.85, func(): main.screens.table._unzoom()],
		[2.92, func(): main.screens.table._on_hover("S17")],
		[3, func(): shot("04_table_bets")],
		[3.1, func(): main.screens.table._on_spin()],
		[5.2, func(): shot("05a_counting")],
		[6.6, func():
			main.last_clear = {"take": 12.0, "target": 8, "table": 0, "spins_left": 3, "comps": 1, "reward": 7}
			main.screens.table.count.show_tally()],
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
		[10.1, func():
			run.skip_offer()
			if run.shop.bonus.is_empty():
				run.shop.bonus = [{"type": "cash", "amount": 5}, {"type": "favour", "id": "fat_stack"}, {"type": "reroll", "amount": 2}]
			main.screens.shop.refresh()],
		[10.2, func(): shot("06g_shop_bonus")],
		[10.3, func():
			run.shop.bonus = []
			var pc = run.felt.perm_chips()
			if not pc.is_empty():
				pc[0].value = 2
				main.screens.shop.refine_id = pc[0].id
			main.screens.shop.refresh()],
		[10.45, func(): shot("06h_shop_refine")],
		[10.55, func():
			main.screens.shop.refine_id = -1
			var pc = run.felt.perm_chips()
			if not pc.is_empty():
				pc[0].mod = "focused"
			main.screens.shop.refresh()],
		[10.75, func(): _staff(["cashier"])],
		[10.85, func(): shot("06e_shop_cashier_only")],
		[10.9, func():
			var it: Dictionary = main.run.shop.stock[0]
			var ch: Dictionary = preload("res://core/preview.gd").cage_hints(run, {"type": "chip", "id": "odd_fellow"})
			var fv = main.screens.shop.felt_view
			fv.preview = {}
			for p in ch.pockets:
				fv.preview["S%d" % p] = Color("#5fd3d3")
			fv.queue_redraw()
			main.screens.shop._describe("%s  -  CHIP  %s" % [main.run.item_name(it), main.run.price_text(it)], main.run.item_desc(it) + "\nWorks with your Magnet, Gilded Number.\n" + "\n".join(ch.lines))],
		[11.05, func(): shot("06f_shop_hover")],
		[11.2, func():
			main.screens.shop.felt_view.preview = {}
			_staff(["cashier", "fence"])],
		[11.4, func(): shot("06b_shop_fence")],
		[11.5, func(): _staff(["cashier", "loan_shark"])],
		[11.7, func(): shot("06c_shop_loan_shark")],
		[11.8, func():
			main.run.overflow = 14
			_staff(["cashier", "dealer"])],
		[11.95, func(): shot("06d_shop_dealer")],
		[12, func(): _staff(["cashier", "pit_boss"])],
		[12.1, func():
			for i in range(run.shop.stock.size()):
				if run.shop.stock[i].type == "upgrade":
					run.buy(i)
			main.screens.shop.refresh()],
		[12.4, func(): shot("07_shop_upgrade_target")],
		[12.5, func():
			if run.shop.pending_upgrade != "":
				run.apply_upgrade(run.upgrade_targets()[0])
			run.table_idx = 2
			run.leave_shop()
			main.route()],
		[13.3, func(): shot("08_enforcer")],
		[13.4, func():
			_close_dialogue()
			run.table.spins_left = 1
			run.spin(_empty_pocket(run))
			main.route()],
		[16.8, func(): shot("09_game_over")],
		[16.9, func(): main.show_screen("pawn")],
		[17.2, func(): shot("10_pawn")],
		[17.4, func(): main.show_screen("journal")],
		[17.6, func(): shot("10b_journal")],
		[17.7, func(): main.show_screen("options")],
		[17.9, func(): shot("10c_options")],
		[18.1, func():
			main.fast_ui = false
			main.show_screen("card")],
		[20.8, func(): shot("11_title_card")],
		[20.9, func():
			main.screens.card.done = true
			main.go("title", "NIGHT 2", "High Roller table  -  pay 28")],
		[21.5, func(): shot("12_loading_card")],
		[22.8, func():
			main.profile.feats = ["straight_up", "jackpot", "beat_sal"]
			main.show_screen("feats")
			main.fx.toast("FEAT: STRAIGHT UP", "+1 Marker")],
		[23.2, func(): shot("13_feats")],
		[23.4, func():
			main.profile.seen_items = ["perm", "magnet", "gilded", "la_partage", "patience"]
			main.profile.used_items = ["perm"]
			main.screens.feats.tab = "almanac"
			main.screens.feats.refresh()],
		[23.7, func(): shot("14_almanac")],
		[23.9, func():
			main.show_screen("title")
			main.say([{"speaker": "Mr. Vance", "text": "Portrait check."}])],
		[24.2, func(): shot("15_portrait_vance")],
		[24.3, func():
			main.dialogue.lines = [{"speaker": "Dolores", "text": "Portrait check."}]
			main.dialogue.idx = 0
			main.dialogue._show_line()],
		[24.6, func(): shot("16_portrait_dolores")],
		[24.7, func():
			main.dialogue.lines = [{"speaker": "Madame Oro", "text": "Portrait check."}]
			main.dialogue._show_line()],
		[25, func(): shot("17_portrait_oro")],
		[25.2, func():
			main.dialogue.visible = false
			main.show_screen("credits")],
		[25.5, func(): shot("18_credits")],
		[25.6, func():
			main.profile.add_history({"wheel": "european", "acts": 1, "nights": 2, "take": 140, "best_spin": 60, "won": false})
			main.profile.add_history({"wheel": "french", "acts": 1, "nights": 4, "take": 520, "best_spin": 210, "won": true})
			main.show_screen("feats")
			main.screens.feats.tab = "history"
			main.screens.feats.refresh()],
		[25.9, func(): shot("19_history")],
		[26, func(): main.pause.open()],
		[26.2, func(): shot("20_pause")],
		[26.4, func():
			main.pause.close()
			main.profile.seen_items = Content.CHIPS.keys() + Content.UPGRADES.keys() + Content.HOUSE_RULES.keys()
			main.show_screen("feats")
			main.screens.feats.tab = "almanac"
			main.screens.feats.refresh()],
		[26.7, func(): main.screens.feats.list.get_parent().scroll_vertical = 330],
		[26.95, func(): shot("21_almanac_chips")],
		[27.05, func(): main.screens.feats.list.get_parent().scroll_vertical = 990],
		[27.3, func(): shot("22_almanac_upgrades")],
		[27.5, func(): main.start_run("european")],
		[28.6, func():
			_close_dialogue()
			var r = main.run
			r.night = 1
			r.table.condition = "scarce"
			r.felt.condition = "scarce"
			r.table.objective = "three_hits"
			r.table.obj_hits = 1
			r.place_bet("S17", 3)
			r.place_bet("RED", 2)
			main.screens.table.refresh()],
		[28.9, func(): shot("23_table_job")],
		[29.0, func():
			var r = main.run
			var guard := 0
			while r.phase == 0 and guard < 20:
				guard += 1
				r.place_bet("S17", mini(5, r.table.stack))
				r.spin(17)
			r.shop.offer = []
			r.shop.bonus = []
			r.shop.event = "lou_bet"
			main.route()],
		[30.4, func():
			_close_dialogue()
			main.screens.shop.refresh()],
		[30.6, func(): shot("24_shop_event")],
		[30.7, func():
			main.run.shop.event = ""
			main.run.shop.routes = Content.ROUTES.keys()
			main.screens.shop.refresh()],
		[30.9, func(): shot("25_shop_routes")],
		[31.0, func(): main.say([{"speaker": "The Duchess", "text": "Darling, nobody needs that many chips in one place."}])],
		[31.3, func(): shot("26_portrait_duchess")],
		[31.5, func():
			main.dialogue.visible = false
			main.show_screen("select")
			main.screens.select.mode = "weekly"
			main.screens.select._cycle_mode(0)],
		[31.8, func(): shot("27_select_weekly")],
		[31.9, func():
			main.screens.select.mode = "gauntlet"
			main.screens.select._cycle_mode(0)],
		[32.1, func(): shot("28_select_challenge")],
		[32.2, func():
			main.run.run_seed = 424242
			main.save_run()
			main.show_screen("title")],
		[32.5, func(): shot("29_title_continue")],
		[32.7, func(): get_tree().quit()],
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


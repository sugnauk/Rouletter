extends Node

const Content := preload("res://core/content.gd")
const P := preload("res://scenes/ui/palette.gd")
## Scripted UI smoke test with screenshots. Runs inside the real game (autoloads included):
##   godot --path . -- smoke=<out_dir> profile=user://smoke_profile.json
## Walks title -> intro dialogue -> wheel select -> table -> spin -> shop -> upgrade ->
## Enforcer -> game over -> Pawn Shop, saving a PNG at each stop, then quits.

var out_dir := "user://"
var t := 0.0
var step := 0
var main
var portrait := false   ## `-- portrait`: a short tour of the portrait layouts (run at a tall window)


func _process(delta: float) -> void:
	t += delta
	if main == null:
		main = get_tree().current_scene
		return
	var run = main.run
	if portrait:
		_run_plan(_portrait_plan())
		return
	var plan := [
		[0.6, func():
			if "tutorial_done" not in main.profile.seen_beats:   # the guided run has its own tour below
				main.profile.seen_beats.append("tutorial_done")
			shot("01_title")
			_check_motion()
			_check_footer()
			_cast_sheet(true)],
		[0.64, func():
			shot("cast_sheet")
			_cast_sheet(false)],
		[0.7, func():
			main.profile.best_grade = 2
			main.screens.select.grade = 2
			main.begin_flow()],
		[1.6, func(): shot("02_intro_dialogue")],
		[1.7, func(): _close_dialogue()],
		[2, func(): shot("03_select")],
		[2.1, func(): main.start_run("european")],
		[2.3, func():
			run.place_chip(0, "DOZ1")   # the European kit: Box Office, then a Magnet
			var g := 0
			while not run.inventory.is_empty() and g < 10:
				g += 1
				if not run.place_chip(0, "S30"):
					run.inventory.remove_at(0)
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
		[3.01, func():   # hover a House Rule, then bet with the real mouse: the felt still takes it
			var t = main.screens.table
			main.run.felt.house_rules.append("crowd_pleaser")
			t.refresh()],
		[3.03, func():
			var t = main.screens.table
			var tok: Control = t.rules_flow.get_child(0)
			_mouse(tok.get_global_rect().get_center(), null)],
		[3.05, func():
			var t = main.screens.table
			_dbg_before = main.run.felt.chips_on("S8").size()
			_mouse(t.felt_view.key_global("S8"), null)],
		[3.07, func(): _mouse(main.screens.table.felt_view.key_global("S8"), true)],
		[3.08, func(): _mouse(main.screens.table.felt_view.key_global("S8"), false)],
		[3.1, func():
			var after: int = main.run.felt.chips_on("S8").size()
			print("BET AFTER RULE: ", "OK" if after == _dbg_before + 1 else "FAIL %d -> %d" % [_dbg_before, after])
			print("UNDO FIRST BET: ", "OK" if not main.screens.table.undo_btn.disabled else "FAIL")
			main.screens.table._on_spin()],
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
		[10, func():
			shot("06_shop")
			# Nothing affordable and nothing to place: NEXT TABLE lights up. With cash, it doesn't.
			var sh = main.screens.shop
			var keep: int = main.run.cash
			main.run.skip_offer()
			main.run.shop.bonus = []
			main.run.inventory.clear()
			main.run.cash = 0
			main.run.shop.free_rerolls = 0
			sh.refresh()
			var lit: bool = sh.nb.marquee
			main.run.cash = 99
			sh.refresh()
			print("NEXT LIT: ", "OK" if lit and not sh.nb.marquee else "FAIL lit=%s rich=%s" % [lit, sh.nb.marquee])
			main.run.cash = keep
			sh.refresh()],
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
		[16.9, func(): main.screens.end.tab_btn.emit_signal("pressed")],
		[17.05, func(): shot("09b_money")],
		[17.2, func(): main.show_screen("pawn")],
		[17.5, func(): shot("10_pawn")],
		[17.7, func():
			main.screens.casebook.tab = "story"
			main.show_screen("casebook")],
		[17.9, func(): shot("10b_casebook_story")],
		[18, func(): main.show_screen("options")],
		[18.2, func(): shot("10c_options")],
		[18.4, func():
			main.fast_ui = false
			main.show_screen("card")],
		[21.1, func(): shot("11_title_card")],
		[21.2, func():
			main.screens.card.done = true
			main.go("title", "NIGHT 2", "High Roller table  -  pay 28")],
		[21.8, func(): shot("12_loading_card")],
		[23.1, func():
			main.profile.feats = ["straight_up", "jackpot", "beat_sal"]
			main.profile.markers = 1
			main.screens.pawn.tab = "goals"
			main.show_screen("pawn")
			main.fx.toast("FEAT: STRAIGHT UP", "+1 Marker")],
		[23.5, func(): shot("13_pawn_goals")],
		[23.7, func():
			main.profile.seen_items = ["perm", "magnet", "gilded", "la_partage", "patience"]
			main.profile.used_items = ["perm"]
			main.screens.casebook.tab = "collection"
			main.show_screen("casebook")],
		[24, func(): shot("14_casebook_collection")],
		[24.2, func():
			main.show_screen("title")
			main.say([{"speaker": "Mr. Vance", "text": "Portrait check."}])],
		[24.5, func(): shot("15_portrait_vance")],
		[24.6, func():
			main.dialogue.lines = [{"speaker": "Rosa", "text": "Portrait check."}]
			main.dialogue.idx = 0
			main.dialogue._show_line()],
		[24.9, func(): shot("16_portrait_rosa")],
		[25, func():
			main.dialogue.lines = [{"speaker": "Madame Oro", "text": "Portrait check."}]
			main.dialogue._show_line()],
		[25.3, func(): shot("17_portrait_oro")],
		[25.5, func():
			main.dialogue.visible = false
			main.show_screen("credits")],
		[25.8, func(): shot("18_credits")],
		[25.9, func():
			main.profile.add_history({"wheel": "european", "acts": 1, "nights": 2, "take": 140, "best_spin": 60, "won": false})
			main.profile.add_history({"wheel": "french", "acts": 1, "nights": 4, "take": 520, "best_spin": 210, "won": true})
			main.screens.casebook.tab = "runs"
			main.show_screen("casebook")],
		[26.2, func(): shot("19_casebook_runs")],
		[26.3, func(): main.pause.open()],
		[26.5, func(): shot("20_pause")],
		[26.7, func():
			main.pause.close()
			main.profile.seen_items = Content.CHIPS.keys() + Content.UPGRADES.keys() + Content.HOUSE_RULES.keys()
			main.screens.casebook.tab = "collection"
			main.show_screen("casebook")],
		[27, func(): main.screens.casebook.scroll.scroll_vertical = 330],
		[27.25, func(): shot("21_casebook_collection_scrolled")],
		[27.35, func():
			main.screens.casebook.tab = "guide"
			main.screens.casebook.refresh()],
		[27.6, func(): shot("22_casebook_guide")],
		[27.8, func(): main.start_run("european")],
		[28.9, func():
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
		[29.2, func(): shot("23_table_job")],
		[29.3, func():
			for k in preload("res://core/story.gd").TIPS:
				main.profile.seen_beats.append(preload("res://core/story.gd").TIPS[k].id)
			_close_dialogue()
			main.run.table_offer = []
			main.screens.table.refresh()
			main.screens.table.overlays.on_bet_held("RED")],
		[29.5, func(): shot("23m_touch_menu")],
		[29.55, func(): main.screens.table.overlays.close_bet_menu()],
		[29.6, func():
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
		[31, func():
			_close_dialogue()
			main.screens.shop.refresh()],
		[31.2, func(): shot("24_shop_event")],
		[31.3, func():
			main.run.shop.event = ""
			main.run.shop.routes = Content.ROUTES.keys()
			main.screens.shop.refresh()],
		[31.5, func(): shot("25_shop_routes")],
		[31.6, func():
			main.run.shop.routes = []
			main.run.shop.stash = main.run._enforcer_stash("sal")
			main.screens.shop.refresh()],
		[31.8, func(): shot("25b_shop_stash")],
		[31.85, func():
			main.run.shop.stash = []
			main.screens.shop.refresh()],
		[32, func(): main.say([{"speaker": "The Duchess", "text": "Darling, nobody needs that many chips in one place."}])],
		[32.3, func(): shot("26_portrait_duchess")],
		[32.5, func():
			main.dialogue.visible = false
			main.show_screen("select")
			main.screens.select.mode = "weekly"
			main.screens.select._cycle_mode(0)],
		[32.8, func(): shot("27_select_weekly")],
		[32.9, func():
			main.screens.select.mode = "gauntlet"
			main.screens.select._cycle_mode(0)],
		[33.1, func(): shot("28_select_challenge")],
		[33.2, func():
			main.run.run_seed = 424242
			main.save_run()
			main.show_screen("title")],
		[33.5, func(): shot("29_title_continue")],
		[33.7, func():
			main.transition.play("NIGHT 3", "Big Sal  -  Every 3rd spin is called.", func(): pass, Color("#e05252"), "Big Sal")],
		[34.6, func(): shot("30_enforcer_card")],
		[36.3, func():
			main.run.start_run(5, "french", main.profile.unlocked)
			main.run.table_offer = []
			main.show_screen("table")],
		[36.7, func(): shot("31_french_felt")],
		[36.9, func():
			# A phone browser hiding the bottom 25% of the page: the play area must fit what's visible.
			main.visible_frac = {"top": 0.08, "height": 0.75, "width": 1.0}
			main._recenter()
			var bottom: float = main.frame.position.y + 360.0 * main.frame.scale.y
			var vis_bottom: float = main.size.y * (0.08 + 0.75)
			print("FIT CHECK ", "OK" if bottom <= vis_bottom + 1.0 and main.frame.position.y >= main.size.y * 0.08 - 1.0 else "FAIL", " ", bottom, " <= ", vis_bottom)],
		[37.1, func(): shot("32_clipped_screen_fit")],
		[37.2, func():
			main.visible_frac = {"top": 0.0, "height": 1.0, "width": 1.0}
			main.set_option("fit", 0.85)
			main.show_screen("options")],
		[37.5, func(): shot("33_options_screen_fit")],
		[37.7, func():
			main.set_option("fit", 1.0)
			main.start_run("european")],
		[38.9, func():
			_close_dialogue()
			main.run.table_offer = []
			var ts = main.screens.table
			ts.refresh()
			ts._select_item(0)
			ts.felt_view.hover_key = "S17"
			ts._on_hover("S17")],
		[39.2, func(): shot("34_placing_ghost")],
		[39.3, func():
			var ts = main.screens.table
			ts._place_selected("S17")
			ts.selected_item = -1
			ts.refresh()
			ts.felt_view.hover_key = "S17"
			ts._on_hover("S17")],
		[39.6, func(): shot("35_chip_card")],
		[39.7, func():
			main.hide_card()
			var r = main.run
			r.inventory = []
			var guard := 0
			while r.phase == 0 and guard < 20:
				guard += 1
				r.place_bet("S17", mini(5, r.table.stack))
				r.spin(17)
			r.shop.bonus = []
			r.shop.routes = []
			r.shop.event = ""
			r.cash = 30
			main.route()],
		[41.1, func():
			_close_dialogue()
			main.screens.shop._pick(0)],
		[41.4, func(): shot("36_cage_pick")],
		[41.6, func():
			main.hide_card()
			main.run.start_run(9, "mini", main.profile.unlocked)
			main.run.table_offer = []
			main.run.place_bet("S5", 3)
			main.run.place_bet("SP1_2", 2)
			main.run.place_bet("DOZ1", 1)
			main.show_screen("table")],
		[42, func(): shot("37_mini_felt")],
		[42.1, func():
			var r = main.run
			r.inventory = []
			r.table.take = r.table.target
			r.spin(5)
			r.shop.bonus = []
			r.shop.routes = []
			r.shop.event = ""
			main.show_screen("shop")],
		[42.5, func(): shot("38_mini_cage")],
		[42.6, func():
			main.run.start_run(10, "european", main.profile.unlocked)
			main.show_screen("table")],
		[43.6, func():
			_close_dialogue()
			var ts = main.screens.table
			ts.refresh()
			var toks := _tokens(ts.overlays.offer_panel) if ts.overlays.offer_panel != null else []
			if not toks.is_empty():
				toks[0].hover_target.call("")],
		[43.9, func(): shot("39_free_chip_card")],
		[44.0, func():
			main.hide_card()
			var r = main.run
			r.table_offer = []
			r.inventory = []
			r.table.take = r.table.target
			r.spin(5)
			r.shop.bonus = []
			r.shop.routes = []
			r.shop.event = ""
			r.shop.offer = []
			r.cash = 40
			r.shop.vendors = ["cashier"]
			r.shop.stock = [
				{"type": "chip", "id": "hedge", "price": 5, "vendor": "cashier", "currency": "cash", "sold": false},
				{"type": "chip", "id": "kingmaker", "price": 9, "vendor": "cashier", "currency": "cash", "sold": false},
				{"type": "upgrade", "id": "lucky_colour", "price": 5, "vendor": "cashier", "currency": "cash", "sold": false},
				{"type": "rule", "id": "momentum", "price": 7, "vendor": "cashier", "currency": "cash", "sold": false}]
			main.show_screen("shop")],
		[44.6, func():
			_close_dialogue()
			var toks := _tokens(main.screens.shop.counter)
			toks[0].hover_target.call("")],
		[44.9, func(): shot("40_cage_card")],
		[45.0, func():
			main.hide_card()
			main.screens.shop._start_stock_drag(0)
			main.screens.shop.felt_view.hover_key = "RED"],
		[45.3, func(): shot("41_drag_hedge")],
		[45.4, func():
			var sh = main.screens.shop
			sh._on_stock_dropped(0, "RED")
			sh._start_stock_drag(2)],
		[45.7, func(): shot("42_drag_upgrade")],
		[45.8, func():
			var sh = main.screens.shop
			sh._end_stock_drag()
			main.run.inventory = [{"kind": "ace", "value": 1}]
			sh.selected_item = 0
			sh.mode = "place"
			sh.refresh()],
		[46.1, func(): shot("43_holding_ace")],
		[46.2, func():
			var r = main.run
			r.inventory = []
			main.screens.shop.selected_item = -1
			r.cash = 40
			r.shop.stock = [{"type": "chip", "id": "black_cat", "price": 5, "vendor": "cashier", "currency": "cash", "sold": false}]
			main.screens.shop.refresh()],
		[46.4, func():
			var tok = _tokens(main.screens.shop.counter)[0]
			_mouse(tok.global_position + tok.size / 2.0, true)],
		[46.45, func():
			var tok = _tokens(main.screens.shop.counter)[0]
			_mouse(tok.global_position + tok.size / 2.0 + Vector2(12, 4), null)],
		[46.5, func(): _mouse(main.screens.shop.felt_view.key_global("S20") + Vector2(-20, 0), null)],
		[46.55, func(): _mouse(main.screens.shop.felt_view.key_global("S20"), null)],
		[46.6, func(): shot("44_real_drag")],
		[46.7, func(): _mouse(main.screens.shop.felt_view.key_global("S20"), false)],
		[46.9, func():
			var on: Array = main.run.felt.chips_on("S20").filter(func(c): return c.kind == "black_cat")
			print("DRAG-TO-BUY: ", ("OK placed on 20, cash %d" % main.run.cash) if not on.is_empty() else "FAILED")
			shot("45_after_drag")],
		[47.2, func():
			main.run.start_run(11, "european", main.profile.unlocked)
			main.run.table_offer = []
			main.show_screen("table")],
		[48.0, func():
			_close_dialogue()
			var ts = main.screens.table
			ts.refresh()
			main.run.place_chip(0, "COL2")
			ts.refresh()
			ts.felt_view.hover_key = "COL2"
			ts._on_hover("COL2")],
		[48.3, func(): shot("46_box_office_card")],
		[48.4, func():
			main.hide_card()
			var r = main.run
			r.night = 4
			r.table_idx = 0
			r._start_table()
			main.screens.table.refresh()],
		[48.8, func():
			_close_dialogue()
			shot("47_upstairs_balls")],
		[49.0, func():
			main.profile.unlocked.append_array(["twin", "crooked", "carousel"])
			main.show_screen("select")
			main.screens.select.selected = "twin"
			main.screens.select.refresh()],
		[49.4, func(): shot("48_select_twin")],
		[49.5, func():
			main.run.start_run(12, "twin", main.profile.unlocked)
			main.run.table_offer = []
			main.run.inventory = []
			main.run.place_bet("RED", 3)
			main.run.place_bet("S17", 2)
			main.run.place_bet("DOZ2", 2)
			main.show_screen("table")],
		[50.3, func():
			_close_dialogue()
			main.screens.table._on_spin()],
		[52.6, func(): shot("49_twin_count")],
		[54.5, func():
			main.run.start_run(13, "crooked", main.profile.unlocked)
			main.run.table_offer = []
			main.run.inventory = []
			main.show_screen("table")],
		[55.3, func():
			_close_dialogue()
			var fat: Array = main.run.felt.weights.keys()
			main.run.place_bet("S%d" % fat[0], 3)
			main.screens.table.refresh()
			main.screens.table.felt_view.hover_key = "S%d" % fat[0]
			main.screens.table._on_hover("S%d" % fat[0])],
		[55.6, func(): shot("50_crooked_table")],
		[55.7, func():
			main.run.start_run(14, "carousel", main.profile.unlocked)
			main.run.table_offer = []
			main.run.inventory = []
			main.show_screen("table")],
		[56.5, func():
			_close_dialogue()
			main.screens.table.refresh()],
		[56.8, func(): shot("51_carousel_table")],
		[57.0, func():
			main.run.start_run(16, "european", main.profile.unlocked)
			main.run.table_offer = []
			main.run.inventory = [{"kind": "odds_maker", "value": 1}]
			main.run.place_chip(0, "RED")
			main.run.felt.chips_on("RED")[0].value = 4
			main.run.felt.house_rules = ["encore", "second_wind"]
			main.run.table.spins_left += 1   # a respin: the last ball is an extra one
			main.run.place_bet("RED", 3)
			main.show_screen("table")],
		[57.8, func():
			_close_dialogue()
			var ts = main.screens.table
			ts.refresh()
			ts.felt_view.hover_key = "RED"
			ts._on_hover("RED")],
		[58.1, func(): shot("52_odds_maker")],
		[58.2, func():
			while "tutorial_done" in main.profile.seen_beats:
				main.profile.seen_beats.erase("tutorial_done")
			main.start_run("european")],
		[59.0, func():
			_close_dialogue()
			shot("53_tutorial_start")
			var ts = main.screens.table
			ts._on_bet_clicked("RED", MOUSE_BUTTON_LEFT)   # not allowed yet: the Box Office comes first
			ts._select_item(0)
			ts._place_selected("COL2")
			_close_dialogue()
			ts._place_selected("S7")
			_close_dialogue()
			ts.refresh()],
		[59.4, func(): shot("54_tutorial_bet_red")],
		[59.5, func():
			_close_dialogue()   # Rosa explains the bet step first
			var ts = main.screens.table
			ts._on_bet_clicked("RED", MOUSE_BUTTON_LEFT)
			_close_dialogue()
			ts._on_spin()],
		[62.5, func():
			print("TUTORIAL: step ", main.tutorial.idx if main.tutorial != null else -1, " take ", main.run.table.take)
			shot("55_tutorial_after_spin")],
		[63.0, func(): _gallery()],
		[65.0, func():
			_close_dialogue()
			shot("56_chip_gallery")
			main.screens.table._on_hover("S5")],
		[65.2, func(): shot("57_stacked_square")],
		[65.5, func(): get_tree().quit()],
	]
	while step < plan.size() and t >= plan[step][0]:
		plan[step][1].call()
		step += 1


## A real mouse event at `at` (viewport coords): pressed true/false, or null for a move.
var touch_open := false
var _dbg_before := 0
var _touch_at := Vector2.ZERO


## A finger on the glass: a screen touch in window coordinates, as a phone's browser sends it.
func _touch(at: Vector2, pressed: bool) -> void:
	if pressed:
		_touch_at = at
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = get_viewport().get_final_transform() * (get_viewport().get_canvas_transform() * _touch_at)
	Input.parse_input_event(e)


func _mouse(at: Vector2, pressed) -> void:
	var e: InputEvent
	if pressed == null:
		e = InputEventMouseMotion.new()
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		e.relative = Vector2(4, 0)
	else:
		e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.warp_mouse(get_viewport().get_final_transform() * at)   # keep the real cursor with the fake one
	e.position = at
	e.global_position = at
	get_viewport().push_input(e, true)


func _run_plan(plan: Array) -> void:
	while step < plan.size() and t >= plan[step][0]:
		plan[step][1].call()
		step += 1


## The home table's ball and rake move continuously: sample two whole loops at 120 fps and
## report the biggest step between frames (in scene pixels, per scene-pixel scale k).
var _sheet: Control = null


## Every cast member's portrait in one grid (a contact sheet), over the screen for one shot.
func _cast_sheet(on: bool) -> void:
	if not on:
		if _sheet != null:
			_sheet.queue_free()
			_sheet = null
		return
	var Portraits = load("res://scenes/ui/portraits.gd")
	var names: Array = Portraits.CAST.keys()
	names.append("Narrator")
	var sh := Control.new()
	sh.size = Vector2(640, 360)
	sh.draw.connect(func():
		sh.draw_rect(Rect2(0, 0, 640, 360), Color("#0b0a10"))
		for i in range(names.size()):
			var x: float = 6 + (i % 9) * 70
			var y: float = 6 + (i / 9) * 88
			Portraits.draw(sh, names[i], Rect2(x, y, 64, 64))
			var nm: String = names[i]
			sh.draw_string(P.font(), Vector2(x, y + 74), nm.to_upper().substr(0, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.CREAM))
	_sheet = sh
	main.frame.add_child(sh)


## The home footer: the phone tip (as the web build shows it) never touches the version.
func _check_footer() -> void:
	var ts = main.screens.title
	ts.hint_lbl.text = "On a phone: Share > Add to Home Screen plays full screen. Options > Screen fit if it's cut off."
	var lines: int = maxi(1, ts.hint_lbl.get_line_count())
	var hint := Rect2(ts.hint_lbl.position, Vector2(ts.hint_lbl.size.x, lines * 10.0))
	var font: Font = P.font()
	var vw: float = font.get_string_size(ts.ver_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var ver := Rect2(ts.ver_lbl.position + Vector2(ts.ver_lbl.size.x - vw, 0), Vector2(vw, 10))
	print("FOOTER: ", "OK" if not hint.intersects(ver) else "FAIL %s vs %s" % [hint, ver])


func _check_motion() -> void:
	var sc = main.home_scene
	var worst_ball := 0.0
	var worst_rake := 0.0
	var prev_b = null
	var prev_r = null
	for i in range(int(2 * sc.LOOP * 120)):
		var tt: float = i / 120.0
		var rnd := int(tt / sc.LOOP)
		var ph: float = fmod(tt, sc.LOOP)
		var b: Array = sc._ball_at(rnd, ph)
		var bp: Vector2 = sc.proj(b[0])
		if prev_b != null and b[1] > 0.5 and prev_b[1] > 0.5:
			worst_ball = maxf(worst_ball, bp.distance_to(prev_b[0]) / sc.k)
		prev_b = [bp, b[1]]
		var rp: Vector2 = sc.proj(sc._rake_head(ph))
		if prev_r != null:
			worst_rake = maxf(worst_rake, rp.distance_to(prev_r) / sc.k)
		prev_r = rp
	print("BALL SMOOTH: ", "OK" if worst_ball < 4.0 else "FAIL", " (worst step %.2f)" % worst_ball)
	# Once the ball has settled, the pocket under it is the number on the marker.
	var wrong := []
	for rnd in range(40):
		var want: int = sc.order[sc._land_index(rnd)]
		for ph in [sc.T_SETTLE + 0.11, 5.5, 7.0, 8.3]:
			var got: int = sc.order[sc._pocket_under_ball(rnd, ph)]
			if got != want:
				wrong.append([rnd, ph, want, got])
	print("BALL POCKET: ", "OK" if wrong.is_empty() else "FAIL %s" % [wrong.slice(0, 4)])
	print("RAKE SMOOTH: ", "OK" if worst_rake < 4.0 else "FAIL", " (worst step %.2f)" % worst_rake)


func _portrait_plan() -> Array:
	return [
		[0.6, func():
			shot("p01_title")
			_check_motion()
			_check_footer()],
		[0.7, func():
			main.profile.best_grade = 2
			main.start_run("european")],
		[1.6, func():
			_close_dialogue()
			main.screens.table.refresh()],
		[1.9, func(): shot("p02_free_chip")],
		[2.0, func():
			var r = main.run
			r.skip_table_offer()
			r.place_chip(0, "DOZ1")
			r.place_chip(0, "S17")
			r.place_bet("S17", 3)
			r.place_bet("RED", 4)
			r.place_bet("SP1_2", 1)
			main.screens.table.refresh()
			main.screens.table._on_hover("S17")],
		[2.3, func(): shot("p03_table_bets")],
		[2.4, func(): main.screens.table._on_spin()],
		[4.6, func(): shot("p04_counting")],
		[7.0, func():
			var r = main.run
			var guard := 0
			while r.phase == 0 and guard < 20:
				guard += 1
				r.place_bet("S17", mini(5, r.table.stack))
				r.spin(17)
			r.shop.bonus = []
			r.shop.routes = []
			r.shop.event = ""
			r.shop.offer = []
			r.cash = 30
			main.route()],
		[7.8, func():
			_close_dialogue()
			main.screens.shop.refresh()],
		[8.1, func(): shot("p05_cage")],
		[8.2, func():
			main.screens.shop._start_stock_drag(0)
			main.screens.shop.felt_view.hover_key = "RED"],
		[8.5, func(): shot("p06_cage_drag")],
		[8.6, func():
			main.screens.shop._end_stock_drag()
			main.run.start_run(12, "twin", main.profile.unlocked)
			main.run.table_offer = []
			main.run.inventory = []
			main.run.place_bet("RED", 3)
			main.show_screen("table")],
		[9.4, func():
			_close_dialogue()
			main.screens.table._on_spin()],
		[11.6, func(): shot("p07_twin")],
		[12.6, func(): main.show_screen("select")],
		[13.0, func(): shot("p08_select")],
		[13.2, func(): main.show_screen("pawn")],
		[13.5, func(): shot("p09_pawn")],
		[13.6, func():
			main.screens.pawn.tab = "goals"
			main.screens.pawn.refresh()],
		[13.9, func(): shot("p10_pawn_goals")],
		[14.0, func():
			main.screens.casebook.tab = "collection"
			main.show_screen("casebook")],
		[14.4, func(): shot("p11_casebook")],
		[14.5, func(): main.open_options()],
		[14.8, func(): shot("p12_options")],
		[14.9, func(): main.show_screen("credits")],
		[15.2, func(): shot("p13_credits")],
		[15.3, func():
			var r = main.run
			r.start_run(15, "european", main.profile.unlocked)
			r.table_offer = []
			r.place_bet("RED", r.table.stack)
			var guard := 0
			while r.phase == 0 and guard < 20:
				guard += 1
				if r.table.stack > 0:
					r.place_bet("S1", r.table.stack)
				r.spin(2)
			main.route()],
		[16.4, func():
			_close_dialogue()
			shot("p14_end")],
		[16.6, func(): main.show_screen("title")],
		[17.0, func():
			_close_dialogue()
			shot("p15_title")],
		[17.1, func():
			# Rotate both ways on every screen (what a phone does mid-run): nothing may error.
			for k in main.screens:
				if main.screens[k].has_method("relayout"):
					main.screens[k].relayout(false)
					main.screens[k].relayout(true)
			print("ROTATE: OK")],
		[17.2, func(): _gallery()],
		[19.2, func():
			_close_dialogue()
			shot("p16_chip_gallery")
			main.screens.table._on_hover("S5")],
		[19.4, func():
			shot("p17_stacked_square")
			# Touch: a tapped card ignores hover-off, and the next press anywhere closes it.
			var t := InputEventScreenTouch.new()
			t.pressed = false
			main._input(t)
			main.hide_card(true)
			main.screens.table._on_hover("S5")
			main.hide_card()
			var stays: bool = main.card.visible
			t.pressed = true
			main._input(t)   # the same tap that opened it: still open
			var same_tap: bool = main.card.visible
			main.card.shown_at -= 1000
			main._input(t)   # a later press: closed
			print("STICKY CARD: ", "OK" if stays and same_tap and not main.card.visible else "FAIL %s %s %s" % [stays, same_tap, main.card.visible])
			var m := InputEventMouseMotion.new()
			main._input(m)
			print("MOUSE MODE: ", "OK" if not main.touch_mode else "FAIL")
			# A real finger: tap a House Rule icon in the tray (through Input, with mouse emulation).
			main.hide_card(true)
			main.run.felt.house_rules.append("crowd_pleaser")
			main.screens.table.refresh()],
		[19.5, func():
			var tok: Control = main.screens.table.rules_flow.get_child(main.screens.table.rules_flow.get_child_count() - 1)
			_touch(tok.get_global_rect().get_center(), true)],
		[19.55, func(): _touch(Vector2.ZERO, false)],
		[19.7, func():
			touch_open = main.card.visible
			shot("p18_touch_card")
			_touch(main.fx.get_global_transform() * Vector2(60, 300), true)],   # the next press, on an empty spot
		[19.75, func(): _touch(Vector2.ZERO, false)],
		[19.9, func():
			print("TOUCH CARD: ", "OK" if touch_open and not main.card.visible and main.touch_mode else "FAIL open=%s after=%s touch=%s" % [touch_open, main.card.visible, main.touch_mode])],
		[19.95, func():   # after a rule's card, tap a rack chip then a number: it still places
			main.hide_card(true)
			main.run.inventory.append({"kind": "magnet", "value": 1})
			main.screens.table.refresh()
			var tok: Control = main.screens.table.rules_flow.get_child(main.screens.table.rules_flow.get_child_count() - 1)
			_touch(tok.get_global_rect().get_center(), true)],
		[20.0, func(): _touch(Vector2.ZERO, false)],
		[20.1, func():
			var t = main.screens.table
			var rt: Control = t.rack_grid.get_child(t.rack_grid.get_child_count() - 1)
			_touch(rt.get_global_rect().get_center(), true)],
		[20.15, func(): _touch(Vector2.ZERO, false)],
		[20.25, func():
			var t = main.screens.table
			_dbg_before = main.run.felt.chips_on("S11").size()
			_touch(t.felt_view.key_global("S11"), true)],
		[20.3, func(): _touch(Vector2.ZERO, false)],
		[20.45, func():
			var after: int = main.run.felt.chips_on("S11").size()
			print("PLACE AFTER RULE: ", "OK" if after == _dbg_before + 1 else "FAIL %d -> %d" % [_dbg_before, after])],
		[20.6, func(): get_tree().quit()],
	]


func _tokens(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch.get_script() == preload("res://scenes/ui/token_button.gd"):
			out.append(ch)
		out += _tokens(ch)
	return out


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


## Every chip kind and felt upgrade laid out on one felt, with a bet chip beside a Snowball on 1,
## to check each placed item reads differently at felt size.
func _gallery() -> void:
	main.end_tutorial()
	main.start_run("european")
	_close_dialogue()
	var r = main.run
	r.skip_table_offer()
	for c in r.felt.perm_chips():
		r.felt.remove(c.id)
	r.inventory.clear()
	r.felt.add_chip("snowball", "S1", 1)
	r.place_bet("S1", 1)
	var n := 0
	for kind in Content.CHIPS:
		if kind == "snowball":
			continue
		var best := ""
		var low := 99
		for k in r.felt.board.all_bet_keys():
			if r.can_place_chip(kind, k):
				var cnt: int = r.felt.chips_on(k).size()
				if cnt < low:
					low = cnt
					best = k
		if best != "":
			r.felt.add_chip(kind, best, 3 if n % 5 == 0 else 1)
			n += 1
	var sq := 2
	for up in Content.UPGRADES:
		match Content.UPGRADES[up].target:
			"outside":
				r.felt.bet_upgrades["DOZ%d" % (1 + r.felt.bet_upgrades.size() % 3)] = up
			"even":
				r.felt.bet_upgrades[["RED", "BLACK", "ODD", "EVEN", "LOW", "HIGH"][r.felt.bet_upgrades.size() % 6]] = up
			_:
				r.felt.square_upgrades[sq] = up
				sq += 2
	# A crowded square: four items on 5 (three show, then a "+1").
	for kind in ["magnet", "keystone", "echo", "compounding"]:
		r.felt.add_chip(kind, "S5", 2)
	main.screens.table.refresh()


func shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(n + ".png")
	img.save_png(path)
	print("saved ", path)


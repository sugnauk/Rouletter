extends "res://core/run_table.gd"
## The run, part 2: the Cage. Vendors and their stock, prices, buying, rerolls, the Cashier's
## services, the Enforcer's stash and the between-table choices. The run's state, saves, tables
## and spins are in run_table.gd. Scene-independent; UI and tests drive it as one RunState.


# --- Shop ---------------------------------------------------------------------------------

func _open_shop(info: Dictionary = {}) -> void:
	phase = Phase.SHOP
	shop = {"stock": [], "reroll": Content.REROLL_BASE, "pending_upgrade": "", "vendors": _pick_vendors(),
		"reserved": -1, "free_rerolls": 0, "offer": [], "bonus": []}
	_restock()
	# Roll the next table's twist and side job now, so the Cage can show them.
	shop.next_condition = _roll_condition() if not table_is_boss(table_idx) else ""
	shop.next_objective = _roll_objective()
	# Before the High Roller table: pick a route (from night 2, or always for veterans).
	if table_idx == 1 and feature_on("route") and not table_is_boss(1):
		shop.routes = Content.ROUTES.keys()
	# Before the Enforcer: sometimes someone in the Cage has an offer.
	if table_idx == 2 and feature_on("event") and rng.chance(Content.EVENT_CHANCE):
		shop.event = rng.pick(Content.EVENTS.keys())
	# Cleared with balls to spare: choose a bonus.
	if info.get("boss", false) and phase == Phase.SHOP:
		shop.stash = _enforcer_stash(info.enforcer)
	if info.get("bonus_pick", false):
		var fav: String = rng.pick(Content.FAVOURS.keys())
		shop.bonus = [
			{"type": "cash", "amount": info.spins_left * Content.CASH_PER_SPIN_LEFT},
			{"type": "favour", "id": fav},
			{"type": "reroll", "amount": 1},
		]


## What the next table holds, for the Cage's preview card.
func next_table_lines() -> Array:
	var out := []
	var route: Dictionary = Content.ROUTES.get(shop.get("route", ""), {})
	var cond: String = route.get("condition", shop.get("next_condition", ""))
	if table_is_boss(table_idx):
		var e: Dictionary = Content.ENFORCERS[table_enforcer(table_idx)]
		out.append("%s: %s" % [e.name, e.desc])
	var bits := []
	if not route.is_empty():
		bits.append(route.name)
	if cond != "":
		bits.append(Content.CONDITIONS[cond].name)
	var o: String = shop.get("next_objective", "")
	if o != "":
		bits.append("Job: %s +$%d" % [Content.OBJECTIVES[o].name, Content.OBJECTIVES[o].cash])
	if not bits.is_empty():
		out.append("  ·  ".join(bits))
	return out


## The full text behind next_table_lines(), for the Cage's description panel.
func next_table_detail() -> String:
	var out := []
	var route: Dictionary = Content.ROUTES.get(shop.get("route", ""), {})
	var cond: String = route.get("condition", shop.get("next_condition", ""))
	if table_is_boss(table_idx):
		var e: Dictionary = Content.ENFORCERS[table_enforcer(table_idx)]
		out.append("%s: %s" % [e.name, e.desc])
	if not route.is_empty():
		out.append("%s: %s" % [route.name, route.desc])
	if cond != "":
		out.append("%s: %s" % [Content.CONDITIONS[cond].name, Content.CONDITIONS[cond].desc])
	var o: String = shop.get("next_objective", "")
	if o != "":
		out.append("Side job, %s: %s +$%d" % [Content.OBJECTIVES[o].name, Content.OBJECTIVES[o].desc, Content.OBJECTIVES[o].cash])
	return "\n".join(out)


## Three free items, each pointing the build a different way.
## Beat an Enforcer, raid their stash: their trophy (a rule sold nowhere else) and two rare chips.
func _enforcer_stash(enforcer: String) -> Array:
	var out := []
	var trophy: String = Content.ENFORCERS.get(enforcer, {}).get("trophy", "")
	if trophy == "" or felt.has_rule(trophy):
		var left: Array = Content.HOUSE_RULES.keys().filter(func(k): return Content.HOUSE_RULES[k].get("trophy", false) and not felt.has_rule(k))
		trophy = rng.pick(left) if not left.is_empty() else ""
	if trophy != "":
		out.append({"type": "rule", "id": trophy})
	var pool := []
	for k in Content.CHIPS:
		if (k in unlocked) and Content.rarity_of(k) != "common":
			pool.append(k)
	for i in range(2):
		if pool.is_empty():
			break
		var k: String = _pick_rare(pool)
		pool.erase(k)
		out.append({"type": "chip", "id": k})
	return out


func take_stash(i: int) -> bool:
	if phase != Phase.SHOP or i < 0 or i >= shop.get("stash", []).size():
		return false
	var item: Dictionary = shop.stash[i]
	if item.type == "rule":
		if felt.house_rules.size() >= relic_slots():
			return false
		felt.house_rules.append(item.id)
	else:
		inventory.append({"kind": item.id, "value": 1})
	shop.stash = []
	changed.emit()
	return true


func take_offer(i: int) -> bool:
	if phase != Phase.SHOP or i < 0 or i >= shop.get("offer", []).size():
		return false
	var item: Dictionary = shop.offer[i]
	if item.type == "rule":
		if felt.house_rules.size() >= relic_slots():
			return false
		felt.house_rules.append(item.id)
	else:
		inventory.append({"kind": item.id, "value": 1})
	shop.offer = []
	changed.emit()
	return true


func take_table_offer(i: int) -> bool:
	if phase != Phase.TABLE or i < 0 or i >= table_offer.size():
		return false
	inventory.append({"kind": table_offer[i].id, "value": 1})
	table_offer = []
	changed.emit()
	return true


func skip_table_offer() -> void:
	table_offer = []
	changed.emit()


func skip_offer() -> void:
	if shop.has("offer"):
		shop.offer = []
		changed.emit()


func pick_route(id: String) -> bool:
	if phase != Phase.SHOP or (id != "" and not id in shop.get("routes", [])):
		return false
	shop.route = id
	shop.routes = []
	changed.emit()
	return true


## Answer a between-table event (option 0 or 1).
func answer_event(opt: int) -> String:
	var ev: String = shop.get("event", "")
	if phase != Phase.SHOP or ev == "":
		return ""
	var out := ""
	match [ev, opt]:
		["dolores_tip", 0]:
			favours.append("extra_spin")
			out = "+1 ball at the next table."
		["dolores_tip", 1]:
			cash += 2
			log_cash("Dolores", 2)
			out = "+$2."
		["lou_bet", 0]:
			if cash < Content.LOU_STAKE:
				return ""
			cash -= Content.LOU_STAKE
			shop.lou_bet = true
			out = "Lou holds your $%d. Clear with 2 balls left for $%d." % [Content.LOU_STAKE, Content.LOU_PAYOUT]
		["fence_hot", 0]:
			var pool := ["perm"]
			for k in Content.CHIPS:
				if k in unlocked:
					pool.append(k)
			var k: String = _pick_rare(pool)
			inventory.append({"kind": k, "value": 1, "flaw": "hot"})
			out = "A hot %s chip, on the house." % Content.CHIPS[k].name
	shop.event = ""
	changed.emit()
	return out


func take_bonus(i: int) -> bool:
	if phase != Phase.SHOP or i < 0 or i >= shop.get("bonus", []).size():
		return false
	var b: Dictionary = shop.bonus[i]
	match b.type:
		"cash":
			cash += b.amount
			log_cash("Balls left", b.amount)
		"favour":
			favours.append(b.id)
		"reroll":
			shop.free_rerolls = shop.get("free_rerolls", 0) + b.amount
	shop.bonus = []
	changed.emit()
	return true


func bonus_text(b: Dictionary) -> String:
	match b.type:
		"cash":
			return "+$%d cash" % b.amount
		"favour":
			return "%s (free): %s" % [Content.FAVOURS[b.id].name, Content.FAVOURS[b.id].desc]
		"reroll":
			return "%d free rerolls this visit" % b.amount
	return ""


## Hold one stock item through rerolls (one at a time; reserve it again to let it go).
func reserve(i: int) -> bool:
	if phase != Phase.SHOP or i < 0 or i >= shop.stock.size() or shop.stock[i].sold or shop.stock[i].type == "loan":
		return false
	shop.reserved = -1 if shop.get("reserved", -1) == i else i
	changed.emit()
	return true


## Refine a levelled number chip down one of two paths (Content.REFINES), at the Cashier.
func can_refine(chip_id: int) -> bool:
	var c = felt.find(chip_id)
	return phase == Phase.SHOP and c != null and not c.is_bet() and c.mod == "" and Board.is_straight(c.bet) \
		and c.value >= Content.REFINE_LEVEL and "cashier" in shop.get("vendors", [])


func refine(chip_id: int, path: String) -> bool:
	if not can_refine(chip_id) or not Content.REFINES.has(path) or cash < Content.REFINE_PRICE:
		return false
	cash -= Content.REFINE_PRICE
	felt.find(chip_id).mod = path
	changed.emit()
	return true


## Cashier trade-in: swap a placed chip for a different one from the same build family,
## keeping its level and square. Returns the new kind ("" if none fits).
func convert_chip(chip_id: int) -> String:
	var c = felt.find(chip_id)
	if phase != Phase.SHOP or c == null or c.is_bet() or c.flaw == "sticky" or cash < Content.CONVERT_PRICE:
		return ""
	if not "cashier" in shop.get("vendors", []):
		return ""
	var tags := Content.tags_of(c.kind)
	var pool := []
	felt.remove(chip_id)
	for k in Content.CHIPS:
		if k != c.kind and (k in unlocked or k == "perm") and Content.tags_of(k).any(func(t): return t in tags) and can_place_chip(k, c.bet):
			pool.append(k)
	if pool.is_empty():
		felt.chips.append(c)
		return ""
	var nk: String = _pick_rare(pool)
	cash -= Content.CONVERT_PRICE
	felt.add_chip(nk, c.bet, c.value, c.flaw).copies = c.copies
	changed.emit()
	return nk


## Who is working the Cage this visit: the Cashier, plus others drawn from the unlocked pool.
## They stay for the whole visit (rerolls refresh their stock, not the staff).
## New players meet the Cage a window at a time: only the Cashier on night 1, the Pit Boss
## from night 2, the Loan Shark and Dealer once an Enforcer has been beaten.
func _vendor_open(v: String) -> bool:
	if not new_player:
		return true
	match v:
		"pit_boss":
			return night >= 1
		"loan_shark", "dealer":
			return not beaten.is_empty()
	return true


func _pick_vendors() -> Array:
	if challenge == "fence_run":
		return ["fence"]
	if graded(7):   # One Window
		return [Content.ALWAYS_VENDOR]
	var vendors := [Content.ALWAYS_VENDOR]
	var pool := []
	for v in Content.VENDORS:
		if challenge == "shoestring" and v in ["pit_boss", "loan_shark"]:
			continue
		if v != Content.ALWAYS_VENDOR and (Content.VENDORS[v].unlock == 0 or v in unlocked) and _vendor_open(v):
			pool.append(v)
	pool = rng.shuffle(pool)
	while vendors.size() < Content.VENDORS_PER_VISIT and not pool.is_empty():
		vendors.append(pool.pop_front())
	return vendors


func _restock() -> void:
	if not shop.has("vendors"):
		shop.vendors = _pick_vendors()
	var vendors: Array = shop.vendors
	var stock := []
	var r: int = shop.get("reserved", -1)
	var kept = shop.stock[r] if r >= 0 and r < shop.get("stock", []).size() and not shop.stock[r].sold else null
	shop.reserved = -1
	for v in vendors:
		var vs := _vendor_stock(v)
		if kept != null and kept.vendor == v:
			# The reserved item keeps its place at the front of its window, replacing one new one.
			vs.pop_back()
			vs.push_front(kept)
			shop.reserved = stock.size()
		stock.append_array(vs)
	shop.vendors = vendors
	shop.stock = stock


## One chip for a shop slot: mostly special chips, now and then a plain Permanent (for levelling).
func _shop_chip() -> String:
	var pool := []
	for k in Content.CHIPS:
		if k in unlocked and k != "perm":
			pool.append(k)
	if pool.is_empty() or rng.chance(Content.PERM_CHANCE):
		return "perm"
	return _pick_rare(pool)


func _vendor_stock(v: String) -> Array:
	var out := []
	var cur: String = Content.VENDORS[v].currency
	match v:
		"cashier":
			for i in range(Content.CASHIER_CHIPS):
				var k: String = _shop_chip()
				out.append({"type": "chip", "id": k, "price": Content.CHIPS[k].price})
			var ups := []
			for k in Content.UPGRADES:
				if k in unlocked and not _targets_for(k).is_empty():
					ups.append(k)
			if not ups.is_empty():
				var u: String = _pick_rare(ups)
				out.append({"type": "upgrade", "id": u, "price": Content.UPGRADES[u].price})
		"dealer":
			var fav: String = rng.pick(Content.FAVOURS.keys())
			out.append({"type": "favour", "id": fav, "icon": Content.FAVOURS[fav].icon, "price": Content.FAVOURS[fav].price})
			var vs := []
			for k in Content.VOUCHERS:
				if k not in vouchers:
					vs.append(k)
			if not vs.is_empty():
				var vo: String = rng.pick(vs)
				out.append({"type": "voucher", "id": vo, "icon": Content.VOUCHERS[vo].icon, "price": Content.VOUCHERS[vo].price})
		"pit_boss":
			var rules := []
			for k in Content.HOUSE_RULES:
				if k in unlocked and not felt.has_rule(k) and not Content.HOUSE_RULES[k].get("trophy", false):
					rules.append(k)
			for n in range(2):
				if rules.is_empty():
					break
				var r: String = _pick_rare(rules)
				rules.erase(r)
				out.append({"type": "rule", "id": r, "price": Content.HOUSE_RULES[r].price})
		"loan_shark":
			for l in Content.LOANS:
				out.append({"type": "loan", "id": "loan", "price": l.cash, "pct": l.pct})
		"fence":
			for i in range(2):
				var k: String = _shop_chip()
				out.append({"type": "chip", "id": k, "flaw": rng.pick(Content.FLAWS.keys()),
					"price": maxi(1, int(ceil(Content.CHIPS[k].price * Content.FENCE_SHARE)))})
	for item in out:
		item.vendor = v
		item.currency = cur
		item.sold = false
	return out


## What an item costs right now, in its vendor's currency.
func price_of(item: Dictionary) -> int:
	if item.get("vendor", "") == "pit_boss":
		return item.price + Content.PIT_BOSS_STEP * felt.house_rules.size()
	if item.get("currency", "cash") == "take":
		return int(ceil(item.price * Content.targets_for(night)[0] / float(Content.NIGHT_BASE[0])))
	var p: int = item.price
	if item.get("currency", "cash") == "cash" and graded(2):
		p += 1
	if item.get("currency", "cash") == "cash" and "house_credit" in vouchers:
		p = maxi(1, p - 1)
	return p


## Chips you could still hand the Pit Boss without dropping below the minimum stack.
func stack_spare() -> int:
	return stack_size - stack_owed - Content.MIN_STACK


func can_afford(item: Dictionary) -> bool:
	if item.get("currency", "cash") == "loan":
		return true
	if item.get("currency", "cash") == "take":
		return overflow >= price_of(item)
	if item.get("currency", "cash") == "stack":
		return stack_spare() >= price_of(item)
	return cash >= price_of(item)


## "$6" or "8 chips", for price tags.
func price_text(item: Dictionary) -> String:
	if item.get("currency", "cash") == "loan":
		return "+%d%% DUE" % int(round(item.pct * 100))
	if item.get("currency", "cash") == "take":
		return "%d TAKE" % price_of(item)
	if item.get("currency", "cash") == "stack":
		return "%d CHIPS" % price_of(item)
	return "$%d" % price_of(item)


## "Works with your Porch Light" / "Good against Big Sal": hints for a Cage item.
func item_hints(item: Dictionary) -> Array:
	var out := []
	var tags := Content.tags_of(item.id)
	if tags.is_empty():
		return out
	var owned := {}
	for c in felt.perm_chips():
		owned[c.kind] = Content.CHIPS[c.kind].name
	for r in felt.house_rules:
		owned[r] = Content.HOUSE_RULES[r].name
	for u in felt.square_upgrades.values() + felt.bet_upgrades.values():
		owned[u] = Content.UPGRADES[u].name
	var friends := []
	for id in owned:
		if id == item.id:
			continue
		for t in Content.tags_of(id):
			if t in tags and t != "easy":
				friends.append(owned[id])
				break
	if not friends.is_empty():
		out.append("Works with your " + ", ".join(friends.slice(0, 3)) + ".")
	# The next Enforcer (the third table of this night, once we're past the first two).
	if table_is_boss(table_idx):
		var e: Dictionary = Content.ENFORCERS[table_enforcer(table_idx)]
		var rules: Array = Content.OWNER_RULES if e.rule == "owner" else [e.rule]
		for r in rules:
			var c: Dictionary = Content.COUNTERS.get(r, {})
			if tags.any(func(t): return t in c.get("bad", [])):
				out.append("Useless against %s at the next table." % e.name)
				break
			if tags.any(func(t): return t in c.get("good", [])):
				out.append("Good against %s at the next table." % e.name)
				break
	return out


func item_name(item: Dictionary) -> String:
	match item.type:
		"chip":
			var flaw: String = item.get("flaw", "")
			return ("%s " % Content.FLAWS[flaw].name if flaw != "" else "") + Content.CHIPS[item.id].name + " chip"
		"loan":
			return "$%d loan" % item.price
		"favour":
			return Content.FAVOURS[item.id].name
		"voucher":
			return Content.VOUCHERS[item.id].name + " voucher"
		"upgrade":
			return Content.UPGRADES[item.id].name
	return Content.HOUSE_RULES[item.id].name


func item_desc(item: Dictionary) -> String:
	match item.type:
		"chip":
			var flaw: String = item.get("flaw", "")
			return Content.CHIPS[item.id].desc + ("  FLAW: " + Content.FLAWS[flaw].desc if flaw != "" else "")
		"loan":
			return "+$%d now. Your next payment is %d%% bigger." % [item.price, int(round(item.pct * 100))]
		"favour":
			return Content.FAVOURS[item.id].desc
		"voucher":
			return Content.VOUCHERS[item.id].desc
		"upgrade":
			return Content.UPGRADES[item.id].desc
	return Content.HOUSE_RULES[item.id].desc


func buy(i: int) -> bool:
	if phase != Phase.SHOP or shop.pending_upgrade != "" or i < 0 or i >= shop.stock.size():
		return false
	var item: Dictionary = shop.stock[i]
	if item.sold or not can_afford(item):
		return false
	if item.type == "rule" and felt.house_rules.size() >= relic_slots():
		return false
	match item.get("currency", "cash"):
		"stack":
			stack_owed += price_of(item)
		"loan":
			cash += item.price
			log_cash("Loan Shark", item.price)
			loan_pct += item.pct
		"take":
			overflow -= price_of(item)
		_:
			cash -= price_of(item)
	item.sold = true
	match item.type:
		"chip":
			var inv := {"kind": item.id, "value": 1}
			if item.get("flaw", "") != "":
				inv.flaw = item.flaw
			inventory.append(inv)
		"rule":
			felt.house_rules.append(item.id)
		"upgrade":
			shop.pending_upgrade = item.id
		"favour":
			favours.append(item.id)
		"voucher":
			vouchers.append(item.id)
	changed.emit()
	return true


func upgrade_targets() -> Array:
	return _targets_for(shop.get("pending_upgrade", ""))


## Felt spots an upgrade could still go on (empty when the felt is full of that kind).
func _targets_for(up: String) -> Array:
	if up == "":
		return []
	var out := []
	if Content.UPGRADES[up].target == "outside":
		for k in ["COL1", "COL2", "COL3", "DOZ1", "DOZ2", "DOZ3"]:
			if not felt.bet_upgrades.has(k):
				out.append(k)
	elif Content.UPGRADES[up].target == "even":
		for k in Content.EVEN_KEYS:
			if not felt.bet_upgrades.has(k):
				out.append(k)
	else:
		for p in felt.board.pockets:
			if not felt.square_upgrades.has(p):
				out.append(Board.straight_key(p))
	return out


func apply_upgrade(target: String) -> bool:
	if target not in upgrade_targets():
		return false
	var up: String = shop.pending_upgrade
	if Content.UPGRADES[up].target in ["outside", "even"]:
		felt.bet_upgrades[target] = up
	else:
		felt.square_upgrades[Board.straight_number(target)] = up
	shop.pending_upgrade = ""
	changed.emit()
	return true


func reroll() -> bool:
	var free: bool = shop.get("free_rerolls", 0) > 0
	if phase != Phase.SHOP or (cash < shop.reroll and not free) or shop.pending_upgrade != "":
		return false
	if free:
		shop.free_rerolls -= 1
	else:
		cash -= shop.reroll
		shop.reroll += 1
	_restock()
	changed.emit()
	return true


func stack_price() -> int:
	return Content.STACK_UPGRADE_PRICE + 2 * stack_buys


func buy_stack() -> bool:
	if phase != Phase.SHOP or cash < stack_price():
		return false
	cash -= stack_price()
	stack_buys += 1
	stack_size += Content.STACK_UPGRADE
	changed.emit()
	return true


func sell_chip(chip_id: int) -> bool:
	var c = felt.find(chip_id)
	if phase != Phase.SHOP or c == null or c.is_bet() or c.flaw == "sticky":
		return false
	var got := int(Content.CHIPS[c.kind].price * c.copies * Content.SELL_SHARE * (Content.FENCE_SHARE if c.flaw != "" else 1.0))
	cash += got
	log_cash("Sold chips", got)
	felt.remove(chip_id)
	changed.emit()
	return true


## Pick a placed chip back up into the inventory to move it.
func pick_up(chip_id: int) -> bool:
	var c = felt.find(chip_id)
	if phase != Phase.SHOP or c == null or c.is_bet() or c.flaw == "sticky" or cash < Content.RELOCATE_PRICE:
		return false
	cash -= Content.RELOCATE_PRICE
	var inv := {"kind": c.kind, "value": c.value}
	if c.flaw != "":
		inv.flaw = c.flaw
	if c.mod != "":
		inv.mod = c.mod
	if c.copies > 1:
		inv.copies = c.copies
	inventory.append(inv)
	felt.remove(chip_id)
	changed.emit()
	return true


## True while a rack chip is waiting that could go somewhere on the felt. The UI makes you
## place those before leaving the Cage or spinning.
func has_unplaced_chips() -> bool:
	for item in inventory:
		for k in felt.board.all_bet_keys():
			if can_place_chip(item.kind, k):
				return true
	return false


func leave_shop() -> bool:
	if phase != Phase.SHOP or shop.pending_upgrade != "":
		return false
	_start_table()
	return true

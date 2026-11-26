extends RefCounted
## Run state machine.
##   Night 1..4, each: Floor -> High Roller -> Enforcer. Each table: reach the Take target
##   within the spins. Clear -> SHOP -> next table. Clear Night 4's Enforcer -> VICTORY.
##   Miss a target, or run out of chips with nothing on the felt -> GAME_OVER.
## Take (score) and cash (shop money) are separate. Scene-independent; UI and tests drive it.

signal changed
signal table_cleared(info: Dictionary)
signal run_ended(won: bool)

const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")
const FeltState := preload("res://core/felt_state.gd")
const Resolver := preload("res://core/resolver.gd")
const Profile := preload("res://core/profile.gd")
const GameRng := preload("res://core/rng.gd")

enum Phase { TABLE, SHOP, GAME_OVER, VICTORY }

var rng = GameRng.new()
var wheel_id: String = "european"
var felt = FeltState.new()
var phase: int = Phase.TABLE
var unlocked: Array = []
var cash: int = 0
var inventory: Array = []        ## unplaced permanent chips: {kind, value}
var stack_size: int = Content.START_STACK
var stack_buys: int = 0
var stack_owed: int = 0        ## betting chips owed to the Pit Boss, docked at the next table
var loan_pct: float = 0.0      ## Loan Shark: the next table's payment grows by this much
var last_bets: Dictionary = {}   ## bet layout at the last real spin: key -> chips (for rebet)
var night: int = 0
var table_idx: int = 0
var table: Dictionary = {}
var shop: Dictionary = {}
var enforcer_order: Array = []
var acts: int = 1               ## 1: the Floor (4 nights). 2: on upstairs to the Owner (8 nights). 3: endless.
var overflow: int = 0            ## spare Take (scored past each payment): the Dealer's currency
var favours: Array = []          ## Dealer favours waiting for the next table
var vouchers: Array = []         ## run-wide perks from the Dealer
var best_spin: float = 0.0       ## run summary: the biggest single spin
var beaten: Array = []           ## run summary: Enforcers beaten this run
var new_player := false
var grade: int = 0               ## marker grade (difficulty), see Content.GRADES          ## first runs: vendors open up one at a time (see _vendor_open)
var total_take: float = 0.0
var nights_cleared: int = 0
var message: String = ""
var last_result: Dictionary = {}


func start_run(seed_in: int, wheel: String = "european", unlocked_ids: Array = [], acts_in: int = 1, grade_in: int = 0) -> void:
	acts = acts_in
	grade = clampi(grade_in, 0, Content.GRADES.size() - 1)
	rng = GameRng.new(seed_in)
	wheel_id = wheel
	unlocked = unlocked_ids.duplicate() if not unlocked_ids.is_empty() else Profile.default_unlocks()
	felt = FeltState.new(wheel)
	var def: Dictionary = Wheels.get_def(wheel)
	cash = Content.START_CASH + def.cash
	inventory = []
	for k in def.kit:
		inventory.append(k.duplicate())
	stack_size = Content.START_STACK - (5 if graded(1) else 0)
	stack_buys = 0
	stack_owed = 0
	loan_pct = 0.0
	overflow = 0
	favours = []
	vouchers = []
	best_spin = 0.0
	beaten = []
	night = 0
	table_idx = 0
	total_take = 0.0
	nights_cleared = 0
	# Act I Enforcers in a random order, then Act II's, then the Owner last.
	var act1 := []
	var act2 := []
	var finale := []
	for k in Content.ENFORCERS:
		var e: Dictionary = Content.ENFORCERS[k]
		if e.get("final", false):
			finale.append(k)
		elif e.get("act", 1) == 2:
			act2.append(k)
		else:
			act1.append(k)
	enforcer_order = rng.shuffle(act1) + rng.shuffle(act2) + finale
	shop = {}
	_start_table()


# --- Run saves ------------------------------------------------------------------------------

const SAVE_FIELDS := ["wheel_id", "phase", "unlocked", "cash", "inventory", "stack_size", "stack_buys",
	"stack_owed", "loan_pct", "last_bets", "night", "table_idx", "table", "shop", "enforcer_order", "acts",
	"total_take", "nights_cleared", "message", "overflow", "favours", "vouchers", "best_spin", "beaten", "new_player", "grade"]


## Everything needed to pick the run up again later (only meaningful mid-run).
func to_dict() -> Dictionary:
	var d := {"version": 1, "rng": rng.get_state(), "felt": felt.to_dict()}
	for k in SAVE_FIELDS:
		var v = get(k)
		d[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return d


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != 1:
		return false
	for k in SAVE_FIELDS:
		if not d.has(k):
			return false
	for k in SAVE_FIELDS:
		var v = d[k]
		set(k, v.duplicate(true) if (v is Dictionary or v is Array) else v)
	rng.set_state(d.rng)
	felt = FeltState.from_dict(d.felt)
	last_result = {}
	changed.emit()
	return true


func save_to(path: String) -> bool:
	if phase != Phase.TABLE and phase != Phase.SHOP:
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(to_dict())
	return true


func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	return d is Dictionary and from_dict(d)


func has_feature(id: String) -> bool:
	return id in unlocked


# --- Tables -----------------------------------------------------------------------------

## Payment due at the current night/table (also used by the shop to preview the next table).
func current_target() -> int:
	var target: int = int(round(Content.targets_for(night)[table_idx] * Wheels.get_def(wheel_id).get("target", 1.0)))
	if felt.has_rule("rent_control"):
		target = int(round(target * (1.0 - Content.RENT_CONTROL_CUT)))
	var gm := 1.0
	if graded(3):
		gm *= 1.1
	if graded(6) and table_idx == 2:
		gm *= 1.1
	if graded(8):
		gm *= 1.1
	if gm > 1.0:
		target = int(ceil(target * gm))
	return target


## Is grade `n`'s twist in force? (Grades are cumulative.)
func graded(n: int) -> bool:
	return grade >= n


## The Enforcer waiting at this night's boss table.
func nights_total() -> int:
	match acts:
		1:
			return Content.NIGHTS
		2:
			return Content.ACT2_NIGHTS
	return 1 << 30  # endless


# --- The run's marker: what you owe Mr. Vance tonight ------------------------------------

func marker_total() -> int:
	var base: int = Content.MARKER_ACT1 if acts == 1 else Content.MARKER_ACT2
	return int(round(base * (1.0 + Content.MARKER_GRADE_STEP * grade)))


## Each table's share of the marker is its base payment over the whole run's payments.
func _marker_weight_total() -> float:
	var t := 0.0
	for n in range(mini(nights_total(), Content.ACT2_NIGHTS)):
		for x in Content.targets_for(n):
			t += x
	return t


## Dollars paid so far: every table cleared before the current one (all of them on a win).
func marker_paid() -> int:
	if phase == Phase.VICTORY:
		return marker_total()
	var w := 0.0
	for n in range(night + 1):
		var tg: Array = Content.targets_for(n)
		for i in range(3):
			if n < night or i < table_idx:
				w += tg[i]
	return int(round(marker_total() * w / _marker_weight_total() / 1000.0)) * 1000


func marker_left() -> int:
	return maxi(0, marker_total() - marker_paid())


func endless() -> bool:
	return acts >= 3


func relic_slots() -> int:
	return Content.RELIC_SLOTS + (1 if "vip_rack" in vouchers else 0)


## Act II nights (5-8) are upstairs.
func upstairs() -> bool:
	return night >= Content.NIGHTS


func night_enforcer() -> String:
	return enforcer_order[night % enforcer_order.size()]


func _start_table() -> void:
	var target: int = current_target()
	var loan := loan_pct
	if loan > 0.0:
		target = int(ceil(target * (1.0 + loan)))
	loan_pct = 0.0
	var boss := table_idx == 2
	var enforcer: String = night_enforcer() if boss else ""
	felt.clear_bets()
	felt.boss_rule = Content.ENFORCERS[enforcer].rule if boss else ""
	felt.frozen_id = -1
	if felt.boss_is("frozen"):
		var best = null
		for c in felt.perm_chips():
			if best == null or c.value > best.value:
				best = c
		if best != null:
			felt.frozen_id = best.id
	felt.red_streak = 0
	felt.hit_streak = 0
	felt.last_pocket = -99
	var spins: int = Content.SHORT_SPINS if felt.boss_is("short") else Content.SPINS
	if graded(5) and table_idx >= 1:
		spins -= 1
	if "patience" in vouchers:
		spins += 1
	table = {"target": target, "take": 0.0, "spins_left": spins, "spins_used": 0,
		"stack": stack_size - stack_owed, "boss": boss, "enforcer": enforcer, "docked": stack_owed, "loan": loan,
		"favours": favours.duplicate()}
	for f in favours:
		match f:
			"extra_spin":
				table.spins_left += 1
			"fat_stack":
				table.stack += Content.FAT_STACK
			"head_start":
				table.take = floor(target * Content.HEAD_START)
	favours = []
	stack_owed = 0
	last_result = {}
	last_bets = {}
	phase = Phase.TABLE
	if boss:
		message = "%s: %s" % [Content.ENFORCERS[enforcer].name, Content.ENFORCERS[enforcer].desc]
	else:
		message = "Night %d, %s table. Payment due: %d." % [night + 1, table_name(), target]
	if table.docked > 0:
		message += " The Pit Boss takes %d chips off your stack." % table.docked
	if table.loan > 0.0:
		message += " The Loan Shark's cut: +%d%% on this payment." % int(round(table.loan * 100))
	changed.emit()


func table_name() -> String:
	return (Content.TABLE_NAMES_ACT2 if upstairs() else Content.TABLE_NAMES)[table_idx]


## Enforcer "Big Sal": every 3rd spin is called and new bets can't be placed.
func is_called_spin() -> bool:
	return phase == Phase.TABLE and felt.boss_is("called") and table.spins_used % 3 == 2


func can_bet_on(key: String) -> bool:
	if not felt.board.has_bet(key):
		return false
	var b: Dictionary = felt.board.bet(key)
	if b.type == "sector" and not has_feature("call_bets"):
		return false
	if felt.boss_is("no_outside") and felt.board.is_outside(key):
		return false
	if felt.boss_is("no_inside") and felt.board.is_line_bet(key):
		return false
	return true


func place_bet(key: String, amount: int) -> bool:
	if phase != Phase.TABLE or is_called_spin() or amount <= 0 or table.stack < amount or not can_bet_on(key):
		return false
	table.stack -= amount
	for c in felt.chips_on(key):
		if c.is_bet():
			c.value += amount
			changed.emit()
			return true
	felt.add_chip("bet", key, amount)
	changed.emit()
	return true


## Take `amount` betting chips back off one bet (for Undo). Returns how many came back.
func unbet(key: String, amount: int) -> int:
	if phase != Phase.TABLE or amount <= 0:
		return 0
	for c in felt.chips_on(key):
		if c.is_bet():
			var back: int = mini(amount, c.value)
			c.value -= back
			table.stack += back
			if c.value <= 0:
				felt.remove(c.id)
			changed.emit()
			return back
	return 0


## Pick up every betting chip on the felt (permanent chips stay put).
func clear_bets() -> bool:
	if phase != Phase.TABLE or is_called_spin():
		return false
	var got := false
	for c in felt.chips.duplicate():
		if c.is_bet():
			table.stack += c.value
			felt.remove(c.id)
			got = true
	if got:
		changed.emit()
	return got


## Lay the previous spin's bets again, as far as the stack allows (bets already out count).
## Returns the number of chips placed. Does nothing on a called spin.
func rebet() -> int:
	if phase != Phase.TABLE or is_called_spin():
		return 0
	var placed := 0
	for key in last_bets:
		var have := 0
		for c in felt.chips_on(key):
			if c.is_bet():
				have += c.value
		var amt: int = mini(last_bets[key] - have, table.stack)
		if amt > 0 and place_bet(key, amt):
			placed += amt
	return placed


## Pick your betting chips back up from a square before spinning.
func take_back(key: String) -> bool:
	if phase != Phase.TABLE:
		return false
	var got := false
	for c in felt.chips_on(key):
		if c.is_bet():
			table.stack += c.value
			felt.remove(c.id)
			got = true
	if got:
		changed.emit()
	return got


func can_place_chip(kind: String, key: String) -> bool:
	if not felt.board.has_bet(key):
		return false
	var straight := Board.is_straight(key)
	if kind == "wildcard_zero":
		return straight and Board.straight_number(key) <= 0
	if kind == "perm":
		return can_bet_on(key) or (straight and not felt.boss_is("no_outside"))
	if Content.CHIPS.get(kind, {}).get("line_only", false):
		return felt.board.is_line_bet(key)
	return straight


## Place an inventory chip onto the felt (at a table or in the shop).
func place_chip(index: int, key: String) -> bool:
	if phase != Phase.TABLE and phase != Phase.SHOP:
		return false
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	if not can_place_chip(item.kind, key):
		return false
	inventory.remove_at(index)
	for c in felt.chips_on(key):
		# Stacking a chip on its twin levels it up instead of adding a second chip.
		if not c.is_bet() and c.kind == item.kind and c.flaw == item.get("flaw", ""):
			c.value += item.value
			changed.emit()
			return true
	felt.add_chip(item.kind, key, item.value, item.get("flaw", ""))
	changed.emit()
	return true


func expected_value() -> Dictionary:
	return Resolver.expected_value(felt)


func spin(forced_pocket: int = -99) -> Dictionary:
	if phase != Phase.TABLE:
		return {}
	var pockets: Array = felt.board.pockets
	var pocket: int = forced_pocket if forced_pocket != -99 else pockets[rng.range_i(0, pockets.size() - 1)]
	if not is_called_spin():
		last_bets = {}
		for c in felt.chips:
			if c.is_bet():
				last_bets[c.bet] = last_bets.get(c.bet, 0) + c.value
	var res := Resolver.resolve_spin(felt, pocket)
	felt = res.felt_after
	if res.zero_tax:
		table.take *= 1.0 - Content.ZERO_TAX
	table.take += res.take
	best_spin = maxf(best_spin, res.take)
	table.stack += res.stack
	if felt.boss_is("drain") and table.stack > 0:
		var d: int = mini(Content.DRAIN_PER_SPIN, table.stack)
		table.stack -= d
		res.log.rules.append("Velvet's minimum: -%d chips from your stack" % d)
	cash += res.cash
	table.spins_used += 1
	table.spins_left += res.respins - 1
	last_result = res
	if table.take >= table.target:
		_clear_table()
	elif table.spins_left <= 0:
		_lose("Payment missed: %d of %d. Mr. Vance's men walk you out back." % [int(table.take), table.target])
	elif table.stack <= 0 and felt.chips.is_empty():
		_lose("Out of chips with nothing on the felt. Bust.")
	changed.emit()
	return res


func _clear_table() -> void:
	var t: float = table.take
	var comps := mini(cash / Content.COMPS_PER, Content.COMPS_MAX)
	var reward: int = Content.CLEAR_CASH[table_idx] + (0 if graded(4) else table.spins_left * Content.CASH_PER_SPIN_LEFT) + comps
	if "comp_card" in vouchers:
		reward += Content.COMP_CARD_CASH
	cash += reward
	overflow += maxi(0, int(t - table.target))
	total_take += t
	felt.clear_bets()
	felt.frozen_id = -1
	var info := {"night": night, "table": table_idx, "take": t, "target": table.target,
		"reward": reward, "spins_left": table.spins_left, "comps": comps, "boss": table.boss,
		"enforcer": table.enforcer}
	if table.boss:
		beaten.append(table.enforcer)
		nights_cleared += 1
		if night >= nights_total() - 1:
			phase = Phase.VICTORY
			message = "The last payment clears. Mr. Vance almost smiles."
			table_cleared.emit(info)
			run_ended.emit(true)
			return
		night += 1
		table_idx = 0
	else:
		table_idx += 1
	message = "Paid! +$%d (%d base, %d spins left, %d comps)." % [reward, Content.CLEAR_CASH[info.table], info.spins_left, comps]
	_open_shop()
	table_cleared.emit(info)


## Walk away mid-run: counts as a loss (Markers for nights already cleared are kept).
func abandon() -> bool:
	if phase != Phase.TABLE and phase != Phase.SHOP:
		return false
	if table.is_empty():
		table = {"take": 0.0}
	_lose("You walk away from the table. Mr. Vance keeps what's left of the marker.")
	return true


func _lose(why: String) -> void:
	total_take += table.take
	phase = Phase.GAME_OVER
	message = why
	run_ended.emit(false)


# --- Shop ---------------------------------------------------------------------------------

func _open_shop() -> void:
	phase = Phase.SHOP
	shop = {"stock": [], "reroll": 4 if graded(7) else Content.REROLL_BASE, "pending_upgrade": "", "vendors": _pick_vendors()}
	_restock()


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
	var vendors := [Content.ALWAYS_VENDOR]
	var pool := []
	for v in Content.VENDORS:
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
	for v in vendors:
		stock.append_array(_vendor_stock(v))
	shop.vendors = vendors
	shop.stock = stock


## Pick by rarity: common items show up more often than rare and legendary ones.
func _pick_rare(ids: Array):
	var w := []
	for id in ids:
		w.append(Content.RARITY_WEIGHT[Content.rarity_of(id)])
	return rng.pick_weighted(ids, w)


func _vendor_stock(v: String) -> Array:
	var out := []
	var cur: String = Content.VENDORS[v].currency
	match v:
		"cashier":
			var chips := ["perm"]
			for k in Content.CHIPS:
				if k in unlocked:
					chips.append(k)
			for i in range(2):
				var k: String = _pick_rare(chips)
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
				if k in unlocked and not felt.has_rule(k):
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
			var chips := ["perm"]
			for k in Content.CHIPS:
				if k in unlocked:
					chips.append(k)
			for i in range(2):
				var k: String = _pick_rare(chips)
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
	if table_idx == 2:
		var e: Dictionary = Content.ENFORCERS[night_enforcer()]
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
	else:
		for p in felt.board.pockets:
			if not felt.square_upgrades.has(p):
				out.append(Board.straight_key(p))
	return out


func apply_upgrade(target: String) -> bool:
	if target not in upgrade_targets():
		return false
	var up: String = shop.pending_upgrade
	if Content.UPGRADES[up].target == "outside":
		felt.bet_upgrades[target] = up
	else:
		felt.square_upgrades[Board.straight_number(target)] = up
	shop.pending_upgrade = ""
	changed.emit()
	return true


func reroll() -> bool:
	if phase != Phase.SHOP or cash < shop.reroll or shop.pending_upgrade != "":
		return false
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
	cash += int(Content.CHIPS[c.kind].price * Content.SELL_SHARE * (Content.FENCE_SHARE if c.flaw != "" else 1.0))
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

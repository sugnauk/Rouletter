extends RefCounted
## The run, part 1: its state, saves, tables and spins. The Cage (shop) lives in run_state.gd,
## which extends this, so everything outside uses RunState as one object.
##
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
var cash_log: Dictionary = {}    ## run summary: where the money came from (source -> dollars)
var contrib: Dictionary = {}     ## run summary: Take scored per chip kind ("bet" for betting chips)
var best_spin_info: Dictionary = {}   ## run summary: the biggest spin's breakdown
var table_offer: Array = []      ## the free pick-1-of-3 special chip waiting at this table
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
var used_outside := false        ## any outside bet placed this run (the "no outside bets" Feat)
var run_seed: int = 0           ## the run's seed (shareable: the same seed deals the same run)
var challenge: String = ""       ## a named challenge (Content.CHALLENGES), or ""
var starter: String = ""         ## an alternative starting kit (Content.STARTERS), or "" for the wheel's
var weekly: String = ""          ## the weekly challenge's id ("W2917"), or ""
var grade: int = 0               ## marker grade (difficulty), see Content.GRADES          ## first runs: vendors open up one at a time (see _vendor_open)
var total_take: float = 0.0
var nights_cleared: int = 0
var message: String = ""
var last_result: Dictionary = {}


func start_run(seed_in: int, wheel: String = "european", unlocked_ids: Array = [], acts_in: int = 1, grade_in: int = 0, opts: Dictionary = {}) -> void:
	run_seed = seed_in
	challenge = opts.get("challenge", "")
	starter = opts.get("starter", "")
	new_player = opts.get("new_player", false)
	weekly = opts.get("weekly", "")
	if challenge != "":
		acts_in = 1
		grade_in = clampi(grade_in, 0, (Content.CHALLENGE_LEVELS - 1) * 2)
	acts = acts_in
	grade = clampi(grade_in, 0, Content.GRADES.size() - 1)
	rng = GameRng.new(seed_in)
	wheel_id = wheel
	unlocked = unlocked_ids.duplicate() if not unlocked_ids.is_empty() else Profile.default_unlocks()
	felt = FeltState.new(wheel)
	var def: Dictionary = Wheels.get_def(wheel)
	cash = Content.START_CASH + def.cash
	inventory = []
	var st: Dictionary = Content.STARTERS.get(starter, {})
	if st.is_empty():
		for k in def.kit:
			inventory.append(k.duplicate())
	else:
		cash += st.cash
		for k in st.get("kit", []):
			inventory.append(k.duplicate())
		var commons := []
		for k in Content.CHIPS:
			if (k in unlocked or k == "perm") and Content.rarity_of(k) == "common" and not Content.CHIPS[k].get("zero_only", false):
				commons.append(k)
		for i in range(st.get("random", 0)):
			inventory.append({"kind": rng.pick(commons), "value": 1})
	if challenge == "fence_run":
		inventory = [{"kind": "magnet", "value": 1}, {"kind": "perm", "value": 1}]
		cash += Content.FENCE_RUN_CASH
	cash_log = {"Starting cash": cash}
	for r in def.get("house", []):
		felt.house_rules.append(r)
	stack_size = Content.START_STACK - (5 if graded(1) else 0)
	if challenge == "shoestring":
		stack_size = Content.SHOESTRING_STACK
	stack_buys = 0
	stack_owed = 0
	loan_pct = 0.0
	overflow = 0
	favours = []
	vouchers = []
	best_spin = 0.0
	beaten = []
	used_outside = false
	contrib = {}
	best_spin_info = {}
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
	enforcer_order = rng.shuffle(act1).slice(0, 4) + rng.shuffle(act2).slice(0, 3) + finale
	if challenge == "gauntlet":
		enforcer_order = rng.shuffle(act1) + rng.shuffle(act1)
	shop = {}
	_start_table()


# --- Run saves ------------------------------------------------------------------------------

## The weekly challenge for the week containing `unix` (UTC): the same wheel, seed and grade
## for everyone, worked out from the date alone (no server).
static func weekly_preset(unix: int) -> Dictionary:
	var week: int = int(floor((unix / 86400.0 + 3.0) / 7.0))   # Monday-based weeks since 1970
	var monday: int = (week * 7 - 3) * 86400
	var wheels: Array = Wheels.ORDER
	return {"id": "W%d" % week, "seed": week * 7919 + 104729, "wheel": wheels[week % wheels.size()],
		"grade": 1, "monday": Time.get_date_string_from_unix_time(monday)}


## A short code for a weekly result, so friends can compare: RLT-W2917-N4-T1234-W-<check>.
## The check stops casual typos and edits; it isn't meant to be tamper-proof.
static func share_code(week: String, nights: int, take: int, won: bool) -> String:
	var body := "%s-N%d-T%d-%s" % [week, nights, take, "W" if won else "L"]
	return "RLT-%s-%s" % [body, ("%x" % (absi((body + "gilded-ace").hash()) % 0xFFFF)).to_upper()]


## Read a share code back: {week, nights, take, won} or {} if it doesn't check out.
static func read_share_code(code: String) -> Dictionary:
	var parts := code.strip_edges().to_upper().split("-")
	if parts.size() != 6 or parts[0] != "RLT":
		return {}
	var body := "-".join(parts.slice(1, 5))
	if share_code(parts[1], parts[2].substr(1).to_int(), parts[3].substr(1).to_int(), parts[4] == "W") != code.strip_edges().to_upper():
		return {}
	return {"week": parts[1], "nights": parts[2].substr(1).to_int(), "take": parts[3].substr(1).to_int(), "won": parts[4] == "W", "body": body}


## A seed typed by a player: digits are used as-is, anything else is hashed.
static func parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t == "":
		return 0
	if t.is_valid_int():
		return absi(t.to_int())
	return absi(t.hash())


const SAVE_VERSION := 2   ## run save format (see migrate())

## Saved too, but optional, so saves from before they existed still load.
const OPTIONAL_FIELDS := {"run_seed": 0, "challenge": "", "starter": "", "weekly": "", "table_offer": [],
	"contrib": {}, "best_spin_info": {}, "cash_log": {}}
const SAVE_FIELDS := ["wheel_id", "phase", "unlocked", "cash", "inventory", "stack_size", "stack_buys",
	"stack_owed", "loan_pct", "last_bets", "night", "table_idx", "table", "shop", "enforcer_order", "acts",
	"total_take", "nights_cleared", "message", "overflow", "favours", "vouchers", "best_spin", "beaten", "new_player", "grade", "used_outside"]


## Everything needed to pick the run up again later (only meaningful mid-run).
func to_dict() -> Dictionary:
	var d := {"version": SAVE_VERSION, "rng": rng.get_state(), "felt": felt.to_dict()}
	for k in SAVE_FIELDS:
		var v = get(k)
		d[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	for k in OPTIONAL_FIELDS:
		var ov = get(k)
		d[k] = ov.duplicate(true) if (ov is Array or ov is Dictionary) else ov
	return d


## Bring an older save up to SAVE_VERSION, one step at a time; {} if it can't be read.
## Each new save change adds a step here instead of breaking old saves.
static func migrate(d_in: Dictionary) -> Dictionary:
	var v := int(d_in.get("version", 0))
	if v < 1 or v > SAVE_VERSION:
		return {}
	var d := d_in.duplicate(true)
	if v == 1:
		# 1 -> 2: the fields added in 0.0.20-0.0.30 (seed, mode, offers, summaries) get their
		# defaults, and chips get their stacked-chip count and refine path.
		for k in OPTIONAL_FIELDS:
			if not d.has(k):
				var dv = OPTIONAL_FIELDS[k]
				d[k] = dv.duplicate(true) if (dv is Array or dv is Dictionary) else dv
		for c in d.get("felt", {}).get("chips", []):
			if not c.has("copies"):
				c["copies"] = 1
			if not c.has("mod"):
				c["mod"] = ""
		v = 2
	d["version"] = v
	return d


func from_dict(d_in: Dictionary) -> bool:
	var d := migrate(d_in)
	if d.is_empty():
		return false
	for k in SAVE_FIELDS:
		if not d.has(k):
			return false
	for k in SAVE_FIELDS:
		var v = d[k]
		set(k, v.duplicate(true) if (v is Dictionary or v is Array) else v)
	for k in OPTIONAL_FIELDS:
		var ov = d.get(k, OPTIONAL_FIELDS[k])
		set(k, ov.duplicate(true) if (ov is Array or ov is Dictionary) else ov)
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


## Is table `idx` of this night an Enforcer table? (Every table is, in the Gauntlet.)
func table_is_boss(idx: int) -> bool:
	return idx == 2 or challenge == "gauntlet"


func table_enforcer(idx: int) -> String:
	if challenge == "gauntlet":
		return enforcer_order[(night * 3 + idx) % enforcer_order.size()]
	return night_enforcer()


func _start_table() -> void:
	var target: int = current_target()
	var loan := loan_pct
	if loan > 0.0:
		target = int(ceil(target * (1.0 + loan)))
	loan_pct = 0.0
	var boss := table_is_boss(table_idx)
	var enforcer: String = table_enforcer(table_idx) if boss else ""
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
	var route: Dictionary = Content.ROUTES.get(shop.get("route", ""), {}) if not boss else {}
	if not route.is_empty():
		target = int(ceil(target * route.target))
	var spins: int = Content.SHORT_SPINS if felt.boss_is("short") else route.get("spins", Content.SPINS)
	if graded(5) and table_idx >= 1:
		spins -= 1
	if boss and felt.has_rule("patron"):
		spins += 1
	if "patience" in vouchers:
		spins += 1
	if felt.has_rule("klines_watch"):
		spins += 1
	table = {"target": target, "take": 0.0, "spins_left": spins, "spins_used": 0,
		"stack": stack_size - stack_owed, "boss": boss, "enforcer": enforcer, "docked": stack_owed, "loan": loan,
		"favours": favours.duplicate(), "base_target": target, "route": shop.get("route", ""),
		"lou_bet": shop.get("lou_bet", false), "condition": "", "objective": "", "obj_ok": true, "obj_hits": 0, "obj_spins": 0,
		"prev_keys": []}
	# Table conditions (ordinary tables from night 2) and a side objective (every table).
	var cond: String = route.get("condition", "")
	if cond == "" and not boss:
		cond = shop.get("next_condition", _roll_condition())
	table.condition = cond
	felt.condition = cond
	if cond == "short_stack":
		table.stack = maxi(Content.MIN_STACK, table.stack - 4)
	table.objective = shop.get("next_objective", _roll_objective())
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
	# Cracked Luck (grade 5): from night 2, each night one permanent chip cracks.
	if graded(4) and night >= 1 and table_idx == 0:
		var whole: Array = felt.perm_chips().filter(func(c): return c.flaw == "")
		if not whole.is_empty():
			var cc = rng.pick(whole)
			cc.flaw = "cracked"
			message += " Cracked Luck: your %s chip cracks." % Content.CHIPS[cc.kind].name
	# Every table opens with a free special chip to pick (not in the Fence's Run).
	table_offer = [] if challenge == "fence_run" else _opening_offer(true)
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
	if (felt.boss_is("no_outside") or challenge == "no_outside") and felt.board.is_outside(key):
		return false
	if felt.boss_is("no_inside") and felt.board.is_line_bet(key):
		return false
	if phase == Phase.TABLE and not table.is_empty():
		if felt.boss_is("no_repeat") and key in table.get("prev_keys", []):
			return false
		if felt.condition == "scarce" and not felt.chips_on(key).any(func(c): return c.is_bet()):
			var spots := {}
			for c in felt.chips:
				if c.is_bet():
					spots[c.bet] = true
			if spots.size() >= Content.SCARCE_SPOTS:
				return false
	return true


## Why a spot can't take a bet right now ("" if it can), for the status line.
func bet_block_reason(key: String) -> String:
	if can_bet_on(key):
		return ""
	if felt.boss_is("no_repeat") and key in table.get("prev_keys", []):
		return "Countess Ilsa: no encores. You bet there last spin."
	if felt.condition == "scarce":
		return "Tight Felt: %d spots at most." % Content.SCARCE_SPOTS
	return ""


func place_bet(key: String, amount: int) -> bool:
	if phase != Phase.TABLE or is_called_spin() or amount <= 0 or table.stack < amount or not can_bet_on(key):
		return false
	table.stack -= amount
	if felt.board.is_outside(key):
		used_outside = true
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
func clear_bets(keep: Array = []) -> bool:
	if phase != Phase.TABLE or is_called_spin():
		return false
	var got := false
	for c in felt.chips.duplicate():
		if c.is_bet() and not c.bet in keep:
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
	if Content.CHIPS.get(kind, {}).get("zero_only", false):
		return straight and Board.straight_number(key) <= 0
	if Content.CHIPS.get(kind, {}).get("even_only", false):
		return key in Content.EVEN_KEYS and can_bet_on(key)
	if Content.CHIPS.get(kind, {}).get("black_only", false):
		return straight and Board.straight_number(key) > 0 and not felt.board.is_red(Board.straight_number(key))
	if Content.CHIPS.get(kind, {}).get("column_only", false):
		return key.begins_with("COL") and can_bet_on(key)
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
			c.copies += int(item.get("copies", 1))
			changed.emit()
			return true
	var nc = felt.add_chip(item.kind, key, item.value, item.get("flaw", ""))
	nc.mod = item.get("mod", "")
	nc.copies = int(item.get("copies", 1))
	changed.emit()
	return true


func expected_value() -> Dictionary:
	return Resolver.expected_value(felt)


func spin(forced_pocket: int = -99) -> Dictionary:
	if phase != Phase.TABLE:
		return {}
	table_offer = []   # spinning passes on the free pick (the table screen asks first)
	var pockets: Array = felt.board.pockets
	var pocket: int = forced_pocket if forced_pocket != -99 else pockets[rng.range_i(0, pockets.size() - 1)]
	if not is_called_spin():
		last_bets = {}
		for c in felt.chips:
			if c.is_bet():
				last_bets[c.bet] = last_bets.get(c.bet, 0) + c.value
	felt.final_spin = table.spins_left <= 1
	felt.spin_no = table.spins_used + 1
	var keys := {}
	for c in felt.chips:
		if c.is_bet():
			keys[c.bet] = true
	var res := Resolver.resolve_spin(felt, pocket)
	felt = res.felt_after
	if res.zero_tax:
		table.take *= 1.0 - Content.ZERO_TAX
	if felt.boss_is("tempo") and res.take <= 0.0 and table.take > 0.0:
		var cut: float = floor(table.take * Content.TEMPO_CUT)
		table.take -= cut
		res.log.rules.append("Miss Tempo: a missed beat costs %d Take" % int(cut))
		res.tempo_cut = cut
	table.take += res.take
	# Side objective bookkeeping.
	if not keys.is_empty():
		table.obj_spins = table.get("obj_spins", 0) + 1
		match table.get("objective", ""):
			"outside_only":
				if keys.keys().any(func(k): return not felt.board.is_outside(k)):
					table.obj_ok = false
			"few":
				if keys.size() > 3:
					table.obj_ok = false
	if res.take > 0.0:
		table.obj_hits = table.get("obj_hits", 0) + 1
	if res.events.any(func(e): return e.kind == "win" and e.label == "straight"):
		table.obj_straight = true
	table.prev_keys = keys.keys()
	if res.take > best_spin:
		best_spin_info = spin_breakdown(res)
	best_spin = maxf(best_spin, res.take)
	for e in res.events:
		if e.kind in ["win", "bonus"] and e.get("chip", "") != "":
			contrib[e.chip] = contrib.get(e.chip, 0.0) + e.amount
	table.stack += res.stack
	if felt.boss_is("drain") and table.stack > 0:
		var d: int = mini(Content.DRAIN_PER_SPIN, table.stack)
		table.stack -= d
		res.log.rules.append("Velvet's minimum: -%d chips from your stack" % d)
	cash += res.cash
	if res.cash > 0:
		var from_events := 0
		for e in res.events:
			if e.kind == "cash":
				var src: String = Content.CHIPS[e.chip].name if Content.CHIPS.has(e.get("chip", "")) else e.label.capitalize()
				log_cash(src, int(e.amount))
				from_events += int(e.amount)
		if res.cash > from_events:
			log_cash("Felt upgrades", res.cash - from_events)
	table.spins_used += 1
	table.spins_left += res.respins - 1
	last_result = res
	if felt.boss_is("clock") and table.take < table.target:
		var grow := int(ceil(table.get("base_target", table.target) * Content.CLOCK_STEP))
		table.target += grow
		res.log.rules.append("The Timekeeper: the payment grows by %d" % grow)
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
	# Cleared with balls to spare: the balls-left cash becomes one option of a bonus pick.
	var pick: bool = table.spins_left >= Content.EARLY_CLEAR_SPINS
	var reward: int = Content.CLEAR_CASH[table_idx] + (0 if pick else table.spins_left * Content.CASH_PER_SPIN_LEFT) + comps
	log_cash("Base pay", Content.CLEAR_CASH[table_idx])
	if not pick:
		log_cash("Balls left", table.spins_left * Content.CASH_PER_SPIN_LEFT)
	log_cash("Comps", comps)
	if "comp_card" in vouchers:
		reward += Content.COMP_CARD_CASH
		log_cash("Comp Card", Content.COMP_CARD_CASH)
	if felt.has_rule("comped"):
		reward += Content.COMPED_CASH
		log_cash("Comped", Content.COMPED_CASH)
	if felt.has_rule("compound_interest"):
		reward += cash / 10
		log_cash("Compound Interest", cash / 10)
	var extras := []   # [label, cash]: conditions, routes, objectives and side bets
	match table.get("condition", ""):
		"early":
			if table.spins_used <= 3:
				extras.append(["EARLY BIRD", 2])
		"short_stack":
			extras.append(["THIN STACK", 2])
	var route: Dictionary = Content.ROUTES.get(table.get("route", ""), {})
	if not route.is_empty() and not table.boss:
		extras.append([route.name.to_upper(), route.cash])
	if objective_met():
		extras.append([Content.OBJECTIVES[table.objective].name.to_upper(), Content.OBJECTIVES[table.objective].cash])
	if table.get("lou_bet", false) and table.spins_left >= 2:
		extras.append(["LOU'S SIDE BET", Content.LOU_PAYOUT])
	for x in extras:
		reward += x[1]
		log_cash("Side jobs" if x[0] in Content.OBJECTIVES.values().map(func(o): return o.name.to_upper()) else x[0].capitalize(), x[1])
	cash += reward
	overflow += maxi(0, int(t - table.target))
	total_take += t
	felt.clear_bets()
	felt.frozen_id = -1
	var info := {"night": night, "table": table_idx, "take": t, "target": table.target,
		"reward": reward, "spins_left": table.spins_left, "spins_used": table.spins_used, "comps": comps, "boss": table.boss, "bonus_pick": pick, "extras": extras,
		"enforcer": table.enforcer}
	if table.boss:
		beaten.append(table.enforcer)
	if table_idx == 2:
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
	_open_shop(info)
	table_cleared.emit(info)


func log_cash(source: String, amount: int) -> void:
	if amount > 0:
		cash_log[source] = cash_log.get(source, 0) + amount


## Where the run's money came from, biggest first: [[source, dollars], ...].
func cash_sources() -> Array:
	var ks: Array = cash_log.keys()
	ks.sort_custom(func(a, b): return cash_log[a] > cash_log[b])
	return ks.map(func(k): return [k, cash_log[k]])


## The biggest parts of a spin, for the run summary: {take, pocket, parts: [[label, text]]}.
func spin_breakdown(res: Dictionary) -> Dictionary:
	var by := {}
	for e in res.events:
		if e.kind in ["win", "bonus"]:
			var k: String = "Bets" if e.get("chip", "") == "bet" else (Content.CHIPS[e.chip].name if Content.CHIPS.has(e.get("chip", "")) else e.label.capitalize())
			by[k] = by.get(k, 0.0) + e.amount
	var parts := []
	var keys: Array = by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	for k in keys.slice(0, 4):
		parts.append([k, "+%d" % int(by[k])])
	for e in res.events:
		if e.kind == "mult":
			parts.append([e.label, "x%s" % (str(snappedf(e.amount, 0.01)))])
	return {"take": int(res.take), "pocket": felt.board.label(res.pocket), "parts": parts.slice(0, 7)}


## Chip kinds that scored the most this run: [[kind, take], ...], biggest first.
func top_contributors(n: int = 3) -> Array:
	var ks: Array = contrib.keys().filter(func(k): return k != "bet")
	ks.sort_custom(func(a, b): return contrib[a] > contrib[b])
	var out := []
	for k in ks.slice(0, n):
		out.append([k, int(contrib[k])])
	return out


## Has this table's side objective been done (checked at the clear)?
func objective_met() -> bool:
	match table.get("objective", ""):
		"outside_only", "few":
			return table.obj_ok and table.get("obj_spins", 0) > 0
		"straight":
			return table.get("obj_straight", false)
		"three_hits":
			return table.get("obj_hits", 0) >= 3
	return false


## Progress text for the HUD.
func objective_text() -> String:
	var o: String = table.get("objective", "")
	if o == "":
		return ""
	var d: Dictionary = Content.OBJECTIVES[o]
	var state := ""
	match o:
		"outside_only", "few":
			state = "" if table.obj_ok else "  (blown)"
		"straight":
			state = "  DONE" if table.get("obj_straight", false) else ""
		"three_hits":
			state = "  %d/3" % mini(3, table.get("obj_hits", 0))
	return "%s: %s +$%d%s" % [d.name, d.desc, d.cash, state]


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


## New players meet the extra systems one night at a time: side jobs from night 2, table
## conditions and the route pick from night 3, Cage events from night 4. Veterans get them all.
const ONBOARD_NIGHT := {"objective": 1, "condition": 2, "route": 2, "event": 3}


func feature_on(f: String) -> bool:
	return not new_player or night >= ONBOARD_NIGHT.get(f, 0)


func _roll_condition() -> String:
	return rng.pick(Content.CONDITIONS.keys()) if night >= 1 and feature_on("condition") and not table_is_boss(table_idx) else ""


func _roll_objective() -> String:
	return rng.pick(Content.OBJECTIVES.keys()) if feature_on("objective") else ""


## chips_only: just special chips (the per-table pick), never the plain Permanent.
func _opening_offer(chips_only: bool = false) -> Array:
	var out := []
	var dirs: Array = rng.shuffle(Content.DIRECTIONS.keys())
	for d in dirs:
		if out.size() >= 3:
			break
		var pool := []
		for k in Content.CHIPS:
			if chips_only and (k == "perm" or (Content.CHIPS[k].get("zero_only", false) and felt.board.zeros.is_empty())):
				continue
			if (k in unlocked or k == "perm") and d in Content.tags_of(k):
				pool.append(k)
		if not chips_only:
			for k in Content.HOUSE_RULES:
				if k in unlocked and d in Content.tags_of(k) and not felt.has_rule(k) and not Content.HOUSE_RULES[k].get("trophy", false):
					pool.append(k)
		pool = pool.filter(func(k): return not out.any(func(o): return o.id == k))
		if pool.is_empty():
			continue
		var id: String = _pick_rare(pool)
		out.append({"type": "chip" if Content.CHIPS.has(id) else "rule", "id": id, "dir": d, "price": 0,
			"vendor": "gift", "currency": "cash", "sold": false})
	return out


## Pick by rarity: common items show up more often than rare and legendary ones.
func _pick_rare(ids: Array):
	var w := []
	for id in ids:
		w.append(Content.RARITY_WEIGHT[Content.rarity_of(id)])
	return rng.pick_weighted(ids, w)


## The Cage opens after a table is paid (run_state.gd fills this in).
func _open_shop(_info: Dictionary = {}) -> void:
	pass

extends RefCounted
## Run state machine for Felt Wars against the House.
##   MAP -> TABLE (spin loop vs a dealer) -> SPOILS -> MAP ... -> Pit Boss -> VICTORY
##   MAP -> EVENT -> MAP
##   any TABLE -> GAME_OVER when the bankroll hits zero.
## Win a table by breaking its bank. If the shift's spins run out first, you are shown the
## door: you lose a share of your bankroll and get no spoils.
## Scene-independent: the UI and the tests both drive this class directly.

signal changed

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")
const Content := preload("res://core/content.gd")
const FeltState := preload("res://core/felt_state.gd")
const Resolver := preload("res://core/resolver.gd")
const HouseAI := preload("res://core/house_ai.gd")
const GameRng := preload("res://core/rng.gd")

enum Phase { MAP, TABLE, SPOILS, EVENT, GAME_OVER, VICTORY }

const PL := Chip.Side.PLAYER
const HO := Chip.Side.HOUSE

var rng = GameRng.new()
var phase: int = Phase.MAP
var felt = FeltState.new()
var bankroll: int = 0
var inventory: Dictionary = {}   ## chip kind -> count, placed for free
var floor_map: Array = []        ## nodes: {id, layer, type, dealer, tier, event, done}
var current_layer: int = -1
var current_node: int = -1
var bank_bonus: int = 0          ## Loan Shark debt makes every later bank bigger
var table: Dictionary = {}       ## active table: dealer, bank, spins_left, budget, ctx, boss
var spoils: Array = []           ## offered spoils: {kind: chip|upgrade|rule, id}
var pending_upgrade: String = "" ## upgrade waiting for a target square/bet
var event_id: String = ""
var message: String = ""
var last_result: Dictionary = {}
var house_log: Array = []
var tables_won: int = 0


func start_run(seed_in: int) -> void:
	rng = GameRng.new(seed_in)
	felt = FeltState.new()
	bankroll = Content.START_BANKROLL
	inventory = {"magnet": 1, "mint": 1}
	bank_bonus = 0
	tables_won = 0
	current_layer = -1
	current_node = -1
	spoils = []
	pending_upgrade = ""
	message = "Climb the floor. Break each dealer's bank."
	_build_map()
	phase = Phase.MAP
	changed.emit()


# --- Floor map ------------------------------------------------------------------

func _build_map() -> void:
	var dealers := ["shuffler", "zero_priest", "banker"]
	var events := rng.shuffle(Content.EVENTS.keys())
	floor_map = [
		{"layer": 0, "type": "table", "dealer": "shuffler", "tier": 0},
		{"layer": 0, "type": "table", "dealer": "zero_priest", "tier": 0},
		{"layer": 1, "type": "event", "event": events[0], "tier": 1},
		{"layer": 1, "type": "table", "dealer": "banker", "tier": 1},
		{"layer": 2, "type": "table", "dealer": rng.pick(dealers), "tier": 2},
		{"layer": 2, "type": "event", "event": events[1], "tier": 2},
		{"layer": 3, "type": "boss", "dealer": "banker", "tier": 3,
			"pit": rng.pick(Content.PIT_RULES.keys())},
	]
	for i in range(floor_map.size()):
		floor_map[i]["id"] = i
		floor_map[i]["done"] = false


## Every node in the next layer is reachable from any node in the current one.
func available_nodes() -> Array:
	var out := []
	if phase != Phase.MAP:
		return out
	for n in floor_map:
		if n.layer == current_layer + 1:
			out.append(n.id)
	return out


func enter_node(id: int) -> bool:
	if id not in available_nodes():
		return false
	var node: Dictionary = floor_map[id]
	current_node = id
	current_layer = node.layer
	if node.type == "event":
		event_id = node.event
		phase = Phase.EVENT
		message = Content.EVENTS[event_id].name
	else:
		_start_table(node)
	changed.emit()
	return true


func _start_table(node: Dictionary) -> void:
	var boss: bool = node.type == "boss"
	var def := Content.table_def(node.tier, node.dealer, boss)
	felt.clear_side(HO)
	felt.clear_temp()
	felt.pit_rules = [node.pit] if boss else []
	felt.red_streak = 0
	HouseAI.seed_table(felt, rng, def.house_start)
	table = {
		"dealer": def.dealer, "bank": def.bank + bank_bonus, "bank_start": def.bank + bank_bonus,
		"spins_left": def.spins, "budget": def.budget, "boss": boss,
		"ctx": {"dozen": rng.range_i(0, 2)},
	}
	last_result = {}
	house_log = []
	phase = Phase.TABLE
	var who: String = Content.DEALERS[def.dealer].name
	if boss:
		message = "Pit Boss (%s): %s" % [Content.PIT_RULES[node.pit].name, Content.PIT_RULES[node.pit].desc]
	else:
		message = "%s: %s" % [who, Content.DEALERS[def.dealer].desc]


# --- Placing chips --------------------------------------------------------------

func perm_cost(value: int) -> int:
	return value * Content.PERM_PRICE


func can_place(kind: String, bet: String) -> bool:
	if phase != Phase.TABLE or not Board.has_bet(bet):
		return false
	var def: Dictionary = Content.CHIPS[kind]
	if def.get("straight_only", false) and not Board.is_straight(bet):
		return false
	if def.get("zero_only", false) and bet != "S0":
		return false
	if bet == "S0" and kind != "wildcard_zero" and kind != "temp" and kind != "perm":
		return false
	return true


func buy_perm(bet: String, value: int) -> bool:
	if not can_place("perm", bet) or bankroll < perm_cost(value):
		return false
	bankroll -= perm_cost(value)
	_stack(bet, "perm", value)
	changed.emit()
	return true


func place_temp(bet: String, value: int) -> bool:
	if not can_place("temp", bet) or bankroll < value:
		return false
	bankroll -= value
	_stack(bet, "temp", value)
	changed.emit()
	return true


func place_special(kind: String, bet: String) -> bool:
	if inventory.get(kind, 0) <= 0 or not can_place(kind, bet):
		return false
	inventory[kind] -= 1
	if inventory[kind] == 0:
		inventory.erase(kind)
	felt.add_chip(PL, kind, bet, 1)
	changed.emit()
	return true


## Plain chips of the same kind merge into one stack on a bet.
func _stack(bet: String, kind: String, value: int) -> void:
	for c in felt.chips_on(bet, PL):
		if c.kind == kind:
			c.value += value
			return
	felt.add_chip(PL, kind, bet, value)


# --- Spinning -------------------------------------------------------------------

func expected_value() -> Dictionary:
	return Resolver.expected_value(felt)


## Spin the fair wheel (or a forced pocket, for tests) and run the House's turn.
func spin(forced_pocket: int = -1) -> Dictionary:
	if phase != Phase.TABLE:
		return {}
	var pocket := forced_pocket if forced_pocket >= 0 else rng.pocket()
	var res := Resolver.resolve_spin(felt, pocket)
	felt = res.felt_after
	var to_player: int = res.player
	var paid_out := -int(res.bank) if res.bank < 0 else 0
	# The bank can only pay what it holds.
	if paid_out > table.bank:
		to_player -= paid_out - table.bank
		res["capped"] = paid_out - table.bank
	bankroll += to_player
	table.bank = maxi(0, table.bank + res.bank)
	table.spins_left += res.respins - 1
	last_result = res
	house_log = []

	if bankroll <= 0:
		bankroll = 0
		phase = Phase.GAME_OVER
		message = "Busted on %d. The House always collects." % pocket
	elif table.bank <= 0:
		_win_table()
	elif table.spins_left <= 0:
		_shift_over()
	else:
		house_log = HouseAI.take_turn(felt, rng, table.dealer, table.budget, table.ctx)
	changed.emit()
	return res


func _win_table() -> void:
	tables_won += 1
	floor_map[current_node]["done"] = true
	felt.clear_side(HO)
	felt.clear_temp()
	felt.pit_rules = []
	if table.boss:
		phase = Phase.VICTORY
		message = "You broke the Pit Boss. The floor is yours."
		return
	_roll_spoils()
	phase = Phase.SPOILS
	message = "Bank broken! Seize something from the House."


func _shift_over() -> void:
	var loss := int(bankroll * Content.SHIFT_PENALTY)
	bankroll -= loss
	floor_map[current_node]["done"] = true
	felt.clear_side(HO)
	felt.clear_temp()
	felt.pit_rules = []
	if table.boss:
		phase = Phase.GAME_OVER
		message = "The Pit Boss outlasted you."
		return
	phase = Phase.MAP
	message = "The shift ended. Security walks you out (-%d coins, no spoils)." % loss


# --- Spoils ---------------------------------------------------------------------

func _roll_spoils() -> void:
	var pool := []
	for k in Content.SPOIL_CHIPS:
		pool.append({"kind": "chip", "id": k})
	for k in Content.UPGRADES.keys():
		pool.append({"kind": "upgrade", "id": k})
	for k in Content.HOUSE_RULES.keys():
		if not felt.has_rule(k):
			pool.append({"kind": "rule", "id": k})
	spoils = rng.shuffle(pool).slice(0, 3)


func spoil_name(s: Dictionary) -> String:
	match s.kind:
		"chip":
			return "%s chip" % Content.CHIPS[s.id].name
		"upgrade":
			return Content.UPGRADES[s.id].name
		_:
			return "House Rule: %s" % Content.HOUSE_RULES[s.id].name


func spoil_desc(s: Dictionary) -> String:
	match s.kind:
		"chip":
			return Content.CHIPS[s.id].desc
		"upgrade":
			return Content.UPGRADES[s.id].desc
		_:
			return Content.HOUSE_RULES[s.id].desc


## Take spoil i. Felt upgrades then wait for `apply_upgrade(target)`.
func take_spoil(i: int) -> bool:
	if phase != Phase.SPOILS or i < 0 or i >= spoils.size() or pending_upgrade != "":
		return false
	var s: Dictionary = spoils[i]
	match s.kind:
		"chip":
			inventory[s.id] = inventory.get(s.id, 0) + 1
			_leave_spoils()
		"rule":
			felt.house_rules.append(s.id)
			_leave_spoils()
		"upgrade":
			pending_upgrade = s.id
			message = "Pick where to lay the %s." % Content.UPGRADES[s.id].name
	changed.emit()
	return true


func upgrade_targets() -> Array:
	if pending_upgrade == "":
		return []
	if Content.UPGRADES[pending_upgrade].target == "outside":
		return ["COL1", "COL2", "COL3", "DOZ1", "DOZ2", "DOZ3"]
	var out := []
	for n in range(37):
		if not felt.square_upgrades.has(n):
			out.append(Board.straight_key(n))
	return out


func apply_upgrade(target: String) -> bool:
	if target not in upgrade_targets():
		return false
	if Content.UPGRADES[pending_upgrade].target == "outside":
		felt.bet_upgrades[target] = pending_upgrade
	else:
		felt.square_upgrades[Board.straight_number(target)] = pending_upgrade
	pending_upgrade = ""
	_leave_spoils()
	changed.emit()
	return true


func skip_spoils() -> void:
	if phase == Phase.SPOILS:
		pending_upgrade = ""
		_leave_spoils()
		changed.emit()


func _leave_spoils() -> void:
	spoils = []
	phase = Phase.MAP
	message = "Choose your next table."


# --- Events ---------------------------------------------------------------------

func choose_event(option: int) -> void:
	if phase != Phase.EVENT:
		return
	var out := "You walk away."
	if option == 0:
		match event_id:
			"loan_shark":
				bankroll += Content.LOAN_SHARK_CASH
				bank_bonus += Content.LOAN_SHARK_BANK_BONUS
				out = "+%d coins. The tables will know." % Content.LOAN_SHARK_CASH
			"crooked_croupier":
				var mine := []
				for c in felt.side_chips(PL):
					if c.kind != "temp":
						mine.append(c)
				if bankroll >= 40 and not mine.is_empty():
					bankroll -= 40
					mine.sort_custom(func(a, b): return a.value > b.value)
					mine[0].value += 3
					out = "Your chip on %s is now worth %d." % [mine[0].bet, mine[0].value]
				else:
					out = "He looks at your empty felt and shrugs."
			"back_room":
				if bankroll >= 40:
					if rng.chance(0.5):
						bankroll += 40
						out = "Heads. +40."
					else:
						bankroll -= 40
						out = "Tails. -40."
	floor_map[current_node]["done"] = true
	phase = Phase.MAP
	message = out
	if bankroll <= 0:
		phase = Phase.GAME_OVER
		message = "Broke in the back room."
	changed.emit()

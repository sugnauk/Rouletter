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
var night: int = 0
var table_idx: int = 0
var table: Dictionary = {}
var shop: Dictionary = {}
var enforcer_order: Array = []
var total_take: float = 0.0
var nights_cleared: int = 0
var message: String = ""
var last_result: Dictionary = {}


func start_run(seed_in: int, wheel: String = "european", unlocked_ids: Array = []) -> void:
	rng = GameRng.new(seed_in)
	wheel_id = wheel
	unlocked = unlocked_ids.duplicate() if not unlocked_ids.is_empty() else Profile.default_unlocks()
	felt = FeltState.new(wheel)
	var def: Dictionary = Wheels.get_def(wheel)
	cash = Content.START_CASH + def.cash
	inventory = []
	for k in def.kit:
		inventory.append(k.duplicate())
	stack_size = Content.START_STACK
	stack_buys = 0
	night = 0
	table_idx = 0
	total_take = 0.0
	nights_cleared = 0
	enforcer_order = rng.shuffle(Content.ENFORCERS.keys())
	shop = {}
	_start_table()


func has_feature(id: String) -> bool:
	return id in unlocked


# --- Tables -----------------------------------------------------------------------------

## Payment due at the current night/table (also used by the shop to preview the next table).
func current_target() -> int:
	var target: int = int(round(Content.targets_for(night)[table_idx] * Wheels.get_def(wheel_id).get("target", 1.0)))
	if felt.has_rule("rent_control"):
		target = int(round(target * (1.0 - Content.RENT_CONTROL_CUT)))
	return target


## The Enforcer waiting at this night's boss table.
func night_enforcer() -> String:
	return enforcer_order[night % enforcer_order.size()]


func _start_table() -> void:
	var target: int = current_target()
	var boss := table_idx == 2
	var enforcer: String = night_enforcer() if boss else ""
	felt.clear_bets()
	felt.boss_rule = Content.ENFORCERS[enforcer].rule if boss else ""
	felt.frozen_id = -1
	if felt.boss_rule == "frozen":
		var best = null
		for c in felt.perm_chips():
			if best == null or c.value > best.value:
				best = c
		if best != null:
			felt.frozen_id = best.id
	felt.red_streak = 0
	felt.last_pocket = -99
	table = {"target": target, "take": 0.0, "spins_left": Content.SPINS, "spins_used": 0,
		"stack": stack_size, "boss": boss, "enforcer": enforcer}
	last_result = {}
	phase = Phase.TABLE
	if boss:
		message = "%s: %s" % [Content.ENFORCERS[enforcer].name, Content.ENFORCERS[enforcer].desc]
	else:
		message = "Night %d, %s table. Payment due: %d." % [night + 1, table_name(), target]
	changed.emit()


func table_name() -> String:
	return Content.TABLE_NAMES[table_idx]


## Enforcer "Big Sal": every 3rd spin is called and new bets can't be placed.
func is_called_spin() -> bool:
	return phase == Phase.TABLE and felt.boss_rule == "called" and table.spins_used % 3 == 2


func can_bet_on(key: String) -> bool:
	if not felt.board.has_bet(key):
		return false
	var b: Dictionary = felt.board.bet(key)
	if b.type == "sector" and not has_feature("call_bets"):
		return false
	if felt.boss_rule == "no_outside" and felt.board.is_outside(key):
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
		return can_bet_on(key) or (straight and felt.boss_rule != "no_outside")
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
		if c.kind == "perm" and item.kind == "perm":
			c.value += item.value
			changed.emit()
			return true
	felt.add_chip(item.kind, key, item.value)
	changed.emit()
	return true


func expected_value() -> Dictionary:
	return Resolver.expected_value(felt)


func spin(forced_pocket: int = -99) -> Dictionary:
	if phase != Phase.TABLE:
		return {}
	var pockets: Array = felt.board.pockets
	var pocket: int = forced_pocket if forced_pocket != -99 else pockets[rng.range_i(0, pockets.size() - 1)]
	var res := Resolver.resolve_spin(felt, pocket)
	felt = res.felt_after
	if res.zero_tax:
		table.take *= 1.0 - Content.ZERO_TAX
	table.take += res.take
	table.stack += res.stack
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
	var reward: int = Content.CLEAR_CASH[table_idx] + table.spins_left * Content.CASH_PER_SPIN_LEFT + comps
	cash += reward
	total_take += t
	felt.clear_bets()
	felt.frozen_id = -1
	var info := {"night": night, "table": table_idx, "take": t, "target": table.target,
		"reward": reward, "spins_left": table.spins_left, "comps": comps, "boss": table.boss,
		"enforcer": table.enforcer}
	if table.boss:
		nights_cleared += 1
		if night >= Content.NIGHTS - 1:
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


func _lose(why: String) -> void:
	total_take += table.take
	phase = Phase.GAME_OVER
	message = why
	run_ended.emit(false)


# --- Shop ---------------------------------------------------------------------------------

func _open_shop() -> void:
	phase = Phase.SHOP
	shop = {"stock": [], "reroll": Content.REROLL_BASE, "pending_upgrade": ""}
	_restock()


func _restock() -> void:
	var stock := []
	var chips := ["perm"]
	for k in Content.CHIPS:
		if k in unlocked:
			chips.append(k)
	for i in range(2):
		var k: String = rng.pick(chips)
		stock.append({"type": "chip", "id": k, "price": Content.CHIPS[k].price, "sold": false})
	var ups := []
	for k in Content.UPGRADES:
		if k in unlocked:
			ups.append(k)
	var u: String = rng.pick(ups)
	stock.append({"type": "upgrade", "id": u, "price": Content.UPGRADES[u].price, "sold": false})
	var rules := []
	for k in Content.HOUSE_RULES:
		if k in unlocked and not felt.has_rule(k):
			rules.append(k)
	if not rules.is_empty():
		var r: String = rng.pick(rules)
		stock.append({"type": "rule", "id": r, "price": Content.HOUSE_RULES[r].price, "sold": false})
	shop.stock = stock


func item_name(item: Dictionary) -> String:
	match item.type:
		"chip":
			return Content.CHIPS[item.id].name + " chip"
		"upgrade":
			return Content.UPGRADES[item.id].name
	return Content.HOUSE_RULES[item.id].name


func item_desc(item: Dictionary) -> String:
	match item.type:
		"chip":
			return Content.CHIPS[item.id].desc
		"upgrade":
			return Content.UPGRADES[item.id].desc
	return Content.HOUSE_RULES[item.id].desc


func buy(i: int) -> bool:
	if phase != Phase.SHOP or shop.pending_upgrade != "" or i < 0 or i >= shop.stock.size():
		return false
	var item: Dictionary = shop.stock[i]
	if item.sold or cash < item.price:
		return false
	if item.type == "rule" and felt.house_rules.size() >= Content.RELIC_SLOTS:
		return false
	cash -= item.price
	item.sold = true
	match item.type:
		"chip":
			inventory.append({"kind": item.id, "value": 1})
		"rule":
			felt.house_rules.append(item.id)
		"upgrade":
			shop.pending_upgrade = item.id
	changed.emit()
	return true


func upgrade_targets() -> Array:
	var up: String = shop.get("pending_upgrade", "")
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
	if phase != Phase.SHOP or c == null or c.is_bet():
		return false
	cash += int(Content.CHIPS[c.kind].price * Content.SELL_SHARE)
	felt.remove(chip_id)
	changed.emit()
	return true


## Pick a placed chip back up into the inventory to move it.
func pick_up(chip_id: int) -> bool:
	var c = felt.find(chip_id)
	if phase != Phase.SHOP or c == null or c.is_bet() or cash < Content.RELOCATE_PRICE:
		return false
	cash -= Content.RELOCATE_PRICE
	inventory.append({"kind": c.kind, "value": c.value})
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

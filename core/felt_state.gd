extends RefCounted
## Everything on the felt for one run: the board (wheel), chips, felt upgrades, House Rules,
## the current Enforcer twist and streak memory. The resolver reads a copy of this.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")

var board
var chips: Array = []
var square_upgrades: Dictionary = {}   ## pocket id -> upgrade id
var bet_upgrades: Dictionary = {}      ## outside bet key -> upgrade id
var house_rules: Array = []            ## relics bought in the shop
var wheel_rules: Array = []            ## rules built into the wheel (French: la_partage)
var boss_rule: String = ""             ## current Enforcer twist
var frozen_id: int = -1                ## chip frozen by the "frozen" Enforcer
var red_streak: int = 0
var last_pocket: int = -99
var next_id: int = 1


func _init(wheel_id: String = "european", shared_board = null) -> void:
	board = shared_board if shared_board != null else Board.new(wheel_id)
	wheel_rules = board.def.rules.duplicate()


func copy():
	var f = get_script().new(board.wheel_id, board)  # geometry is immutable, safe to share
	for c in chips:
		f.chips.append(c.copy())
	f.square_upgrades = square_upgrades.duplicate()
	f.bet_upgrades = bet_upgrades.duplicate()
	f.house_rules = house_rules.duplicate()
	f.wheel_rules = wheel_rules.duplicate()
	f.boss_rule = boss_rule
	f.frozen_id = frozen_id
	f.red_streak = red_streak
	f.last_pocket = last_pocket
	f.next_id = next_id
	return f


func has_rule(id: String) -> bool:
	return id in house_rules or id in wheel_rules


func add_chip(kind: String, bet: String, value: int):
	var c = Chip.new(next_id, kind, bet, value)
	next_id += 1
	chips.append(c)
	return c


func find(id: int):
	for c in chips:
		if c.id == id:
			return c
	return null


func remove(id: int) -> void:
	for i in range(chips.size()):
		if chips[i].id == id:
			chips.remove_at(i)
			return


func chips_on(key: String) -> Array:
	var out := []
	for c in chips:
		if c.bet == key:
			out.append(c)
	return out


func bet_chips() -> Array:
	return chips.filter(func(c): return c.is_bet())


func perm_chips() -> Array:
	return chips.filter(func(c): return not c.is_bet())


func bet_stakes() -> int:
	var t := 0
	for c in chips:
		if c.is_bet():
			t += c.value
	return t


func clear_bets() -> void:
	chips = perm_chips()


func value_on(key: String) -> int:
	var t := 0
	for c in chips_on(key):
		t += c.value
	return t

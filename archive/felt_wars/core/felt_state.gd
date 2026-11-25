extends RefCounted
## Everything on the felt: chips from both sides, felt upgrades, active House Rules,
## Pit Boss rules and the red streak. Scene-independent; the resolver reads a copy.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")

const PLAYER := Chip.Side.PLAYER
const HOUSE := Chip.Side.HOUSE
const NONE := -1

var chips: Array = []
var square_upgrades: Dictionary = {}   ## number -> upgrade id
var bet_upgrades: Dictionary = {}      ## outside bet key -> upgrade id ("hot")
var house_rules: Array = []            ## player's global relics
var pit_rules: Array = []              ## current Pit Boss twists
var red_streak: int = 0
var next_id: int = 1


func copy():
	var f = get_script().new()
	for c in chips:
		f.chips.append(c.copy())
	f.square_upgrades = square_upgrades.duplicate()
	f.bet_upgrades = bet_upgrades.duplicate()
	f.house_rules = house_rules.duplicate()
	f.pit_rules = pit_rules.duplicate()
	f.red_streak = red_streak
	f.next_id = next_id
	return f


func has_rule(id: String) -> bool:
	return id in house_rules


func has_pit(id: String) -> bool:
	return id in pit_rules


func add_chip(side: int, kind: String, bet: String, value: int):
	var c = Chip.new(next_id, side, kind, bet, value)
	next_id += 1
	chips.append(c)
	return c


## House chips merge into one stack per square to keep the felt readable.
func add_house_value(n: int, value: int):
	var key := Board.straight_key(n)
	for c in chips:
		if c.side == HOUSE and c.bet == key:
			c.value += value
			return c
	return add_chip(HOUSE, "house", key, value)


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


func chips_on(key: String, side: int = NONE) -> Array:
	var out := []
	for c in chips:
		if c.bet == key and (side == NONE or c.side == side):
			out.append(c)
	return out


func side_chips(side: int) -> Array:
	var out := []
	for c in chips:
		if c.side == side:
			out.append(c)
	return out


## Raw chip value a side has stacked on number n (straight bets only).
func raw_value(n: int, side: int) -> int:
	var total := 0
	for c in chips_on(Board.straight_key(n), side):
		total += c.value
	return total


## Value used for ownership, after Double Felt and Heavy Chips.
func weight(n: int, side: int) -> int:
	var v := raw_value(n, side)
	if square_upgrades.get(n, "") == "double_felt":
		v *= 2
	if side == HOUSE and has_pit("capture_double"):
		v *= 2
	return v


## Whoever has the most chip value on a square owns it. The House wins ties.
func owner(n: int) -> int:
	var p := weight(n, PLAYER)
	var h := weight(n, HOUSE)
	if p == 0 and h == 0:
		return NONE
	return PLAYER if p > h else HOUSE


func owned_squares(side: int) -> Array:
	var out := []
	for n in range(37):
		if owner(n) == side:
			out.append(n)
	return out


## A House square is flanked when the player owns at least 3 of its neighbours
## (or all of them, for squares with fewer than 3).
func is_flanked(n: int) -> bool:
	var nb := Board.neighbours(n)
	var mine := 0
	for m in nb:
		if owner(m) == PLAYER:
			mine += 1
	return mine >= mini(3, nb.size())


## A street (grid column of 3) fully owned by the player is walled: the House cannot place there.
func is_walled(n: int) -> bool:
	if n == 0:
		return false
	for m in Board.street_of(n):
		if owner(m) != PLAYER:
			return false
	return true


func clear_side(side: int) -> void:
	var keep := []
	for c in chips:
		if c.side != side:
			keep.append(c)
	chips = keep


func clear_temp() -> void:
	var keep := []
	for c in chips:
		if c.kind != "temp":
			keep.append(c)
	chips = keep


func temp_stakes() -> int:
	var t := 0
	for c in chips:
		if c.kind == "temp":
			t += c.value
	return t

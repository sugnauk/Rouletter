extends RefCounted
## Felt geometry for one wheel: pockets, the 3xN grid, every bet and adjacency.
## Payouts use one fair-minus-zeros formula: payout = numbers / numbers_covered - 1
## (36 numbers -> 35/17/11/8/2/1; 12 numbers -> 11/5/3/2/2/1).
## Grid: number n sits at grid column (n-1)/3 (a "street") and grid row (n-1)%3,
## row 0 being the 1,4,7.. row (drawn at the bottom).

const Wheels := preload("res://core/wheels.gd")

const OUTSIDE_TYPES := ["column", "dozen", "red", "black", "odd", "even", "low", "high", "sector"]

var wheel_id: String
var def: Dictionary
var numbers: int        ## count of non-zero numbers (36 or 12)
var cols: int           ## grid columns (12 or 4)
var zeros: Array        ## zero pocket ids: [0], [0,-1], [0,-1,-2]
var pockets: Array      ## every pocket id on the wheel
var order: Array        ## wheel order (for drawing and sector effects)
var red: Array
var bets: Dictionary = {}


func _init(id: String = "european") -> void:
	wheel_id = id
	def = Wheels.get_def(id)
	numbers = def.numbers
	cols = numbers / 3
	zeros = def.zeros.duplicate()
	order = def.order.duplicate()
	red = def.red.duplicate()
	pockets = zeros.duplicate()
	for n in range(1, numbers + 1):
		pockets.append(n)
	_build_bets()


func _build_bets() -> void:
	for p in pockets:
		_add(straight_key(p), "straight", [p])
	for n in range(1, numbers + 1):
		if n + 3 <= numbers:
			_add("SP%d_%d" % [n, n + 3], "split", [n, n + 3])
		if grid_row(n) < 2:
			_add("SP%d_%d" % [n, n + 1], "split", [n, n + 1])
	for z in zeros:
		for n in [1, 2, 3]:
			_add("SP%d_%d" % [z, n], "split", [z, n])
	for c in range(cols):
		var b := c * 3 + 1
		_add("ST%d" % b, "street", [b, b + 1, b + 2])
		if c < cols - 1:
			for r in range(2):
				_add("CO%d" % (b + r), "corner", [b + r, b + r + 1, b + r + 3, b + r + 4])
	for r in range(3):
		var nums := []
		for c in range(cols):
			nums.append(c * 3 + 1 + r)
		_add("COL%d" % (r + 1), "column", nums)
	var third := numbers / 3
	for d in range(3):
		var nums := []
		for n in range(d * third + 1, (d + 1) * third + 1):
			nums.append(n)
		_add("DOZ%d" % (d + 1), "dozen", nums)
	var groups := {"RED": [], "BLACK": [], "ODD": [], "EVEN": [], "LOW": [], "HIGH": []}
	for n in range(1, numbers + 1):
		groups["RED" if is_red(n) else "BLACK"].append(n)
		groups["ODD" if n % 2 == 1 else "EVEN"].append(n)
		groups["LOW" if n <= numbers / 2 else "HIGH"].append(n)
	for k in groups:
		_add(k, k.to_lower(), groups[k])
	var sec := Wheels.sectors(def)
	for k in sec:
		var nums := []
		for p in sec[k]:
			if p in pockets:
				nums.append(p)
		_add(k, "sector", nums)


func _add(key: String, type: String, nums: Array) -> void:
	bets[key] = {"key": key, "type": type, "numbers": nums, "payout": float(numbers) / nums.size() - 1.0}


func bet(key: String) -> Dictionary:
	return bets[key]


func has_bet(key: String) -> bool:
	return bets.has(key)


func all_bet_keys() -> Array:
	return bets.keys()


func is_outside(key: String) -> bool:
	return bets[key].type in OUTSIDE_TYPES


func is_even_money(key: String) -> bool:
	return bets[key].type in ["red", "black", "odd", "even", "low", "high"]


func is_red(n: int) -> bool:
	return n in red


func is_zero(p: int) -> bool:
	return p <= 0


func label(p: int) -> String:
	return Wheels.label(p)


func colour_name(p: int) -> String:
	if p <= 0:
		return "green"
	return "red" if is_red(p) else "black"


static func straight_key(p: int) -> String:
	return "S%d" % p


static func is_straight(key: String) -> bool:
	return key.begins_with("S") and not key.begins_with("SP") and not key.begins_with("ST")


static func straight_number(key: String) -> int:
	return int(key.substr(1))


static func grid_col(n: int) -> int:
	return (n - 1) / 3


static func grid_row(n: int) -> int:
	return (n - 1) % 3


func dozen_of(n: int) -> int:
	return -1 if n <= 0 else (n - 1) / (numbers / 3)


## Orthogonal grid neighbours. Every zero borders the first street (1, 2, 3).
func neighbours(n: int) -> Array:
	if n <= 0:
		return [1, 2, 3]
	var out := []
	if n - 3 >= 1:
		out.append(n - 3)
	if n + 3 <= numbers:
		out.append(n + 3)
	if grid_row(n) > 0:
		out.append(n - 1)
	if grid_row(n) < 2:
		out.append(n + 1)
	if grid_col(n) == 0:
		out.append_array(zeros)
	return out


## Distance between two pockets around the wheel.
func wheel_distance(a: int, b: int) -> int:
	var i := order.find(a)
	var j := order.find(b)
	var d := absi(i - j)
	return mini(d, order.size() - d)

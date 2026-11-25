extends RefCounted
## Static felt geometry for a European single-zero table.
## Pockets 0..36, the 3x12 grid, every bet definition and grid adjacency.
## Grid convention: number n (1..36) sits at grid column (n-1)/3 (0..11, a "street")
## and grid row (n-1)%3 (0 = the 1,4,7.. row, 2 = the 3,6,9.. row drawn on top).

const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

const PAYOUT := {
	"straight": 35, "split": 17, "street": 11, "corner": 8,
	"column": 2, "dozen": 2,
	"red": 1, "black": 1, "odd": 1, "even": 1, "low": 1, "high": 1,
}

## European wheel order, clockwise from 0 (used for drawing the wheel).
const WHEEL_ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]

const OUTSIDE_KEYS := ["COL1", "COL2", "COL3", "DOZ1", "DOZ2", "DOZ3",
	"LOW", "EVEN", "RED", "BLACK", "ODD", "HIGH"]

static var _bets: Dictionary = {}


static func _ensure() -> void:
	if not _bets.is_empty():
		return
	for n in range(37):
		_add("S%d" % n, "straight", [n])
	# Splits: horizontal (n, n+3) and vertical (n, n+1 within a street), plus zero splits.
	for n in range(1, 37):
		if n + 3 <= 36:
			_add("SP%d_%d" % [n, n + 3], "split", [n, n + 3])
		if (n - 1) % 3 != 2:
			_add("SP%d_%d" % [n, n + 1], "split", [n, n + 1])
	for n in [1, 2, 3]:
		_add("SP0_%d" % n, "split", [0, n])
	for c in range(12):
		var b := c * 3 + 1
		_add("ST%d" % b, "street", [b, b + 1, b + 2])
	for c in range(11):
		for r in range(2):
			var b := c * 3 + 1 + r
			_add("CO%d" % b, "corner", [b, b + 1, b + 3, b + 4])
	for r in range(3):
		var nums := []
		for c in range(12):
			nums.append(c * 3 + 1 + r)
		_add("COL%d" % (r + 1), "column", nums)
	for d in range(3):
		var nums := []
		for n in range(d * 12 + 1, d * 12 + 13):
			nums.append(n)
		_add("DOZ%d" % (d + 1), "dozen", nums)
	var red := []
	var black := []
	var odd := []
	var even := []
	var low := []
	var high := []
	for n in range(1, 37):
		if is_red(n):
			red.append(n)
		else:
			black.append(n)
		if n % 2 == 1:
			odd.append(n)
		else:
			even.append(n)
		if n <= 18:
			low.append(n)
		else:
			high.append(n)
	_add("RED", "red", red)
	_add("BLACK", "black", black)
	_add("ODD", "odd", odd)
	_add("EVEN", "even", even)
	_add("LOW", "low", low)
	_add("HIGH", "high", high)


static func _add(key: String, type: String, numbers: Array) -> void:
	_bets[key] = {"key": key, "type": type, "numbers": numbers, "payout": PAYOUT[type]}


static func bet(key: String) -> Dictionary:
	_ensure()
	return _bets[key]


static func has_bet(key: String) -> bool:
	_ensure()
	return _bets.has(key)


static func all_bet_keys() -> Array:
	_ensure()
	return _bets.keys()


static func is_red(n: int) -> bool:
	return n in RED


static func colour_name(n: int) -> String:
	if n == 0:
		return "green"
	return "red" if is_red(n) else "black"


static func straight_key(n: int) -> String:
	return "S%d" % n


static func is_straight(key: String) -> bool:
	return key.begins_with("S") and not key.begins_with("SP") and not key.begins_with("ST")


static func straight_number(key: String) -> int:
	return int(key.substr(1))


static func grid_col(n: int) -> int:
	return (n - 1) / 3


static func grid_row(n: int) -> int:
	return (n - 1) % 3


static func dozen_of(n: int) -> int:
	return -1 if n == 0 else (n - 1) / 12


## Orthogonal grid neighbours. 0 borders the first street (1, 2, 3).
static func neighbours(n: int) -> Array:
	if n == 0:
		return [1, 2, 3]
	var out := []
	var r := grid_row(n)
	if n - 3 >= 1:
		out.append(n - 3)
	if n + 3 <= 36:
		out.append(n + 3)
	if r > 0:
		out.append(n - 1)
	if r < 2:
		out.append(n + 1)
	if grid_col(n) == 0:
		out.append(0)
	return out


static func street_of(n: int) -> Array:
	if n == 0:
		return [0]
	var b := grid_col(n) * 3 + 1
	return [b, b + 1, b + 2]


## Breadth-first grid distance from 0 (used by the Zero Priest).
static func distance_from_zero(n: int) -> int:
	return 0 if n == 0 else grid_col(n) + 1

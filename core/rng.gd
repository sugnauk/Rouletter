extends RefCounted
## Seedable RNG wrapper so runs are reproducible. The wheel is always a fair 1/37.

var _rng := RandomNumberGenerator.new()
var seed_value: int = 0


func _init(seed_in: int = 0) -> void:
	reseed(seed_in)


func reseed(seed_in: int) -> void:
	seed_value = seed_in
	_rng.seed = seed_in
	_rng.state = 0
	_rng.seed = seed_in


## Save / restore the exact position in the random stream (run saves).
func get_state() -> Dictionary:
	return {"seed": seed_value, "state": _rng.state}


func set_state(d: Dictionary) -> void:
	seed_value = d.seed
	_rng.seed = d.seed
	_rng.state = d.state


## A fair European pocket, uniform over 0..36.
func pocket() -> int:
	return _rng.randi_range(0, 36)


func range_i(lo: int, hi: int) -> int:
	return _rng.randi_range(lo, hi)


func chance(p: float) -> bool:
	return _rng.randf() < p


func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]


## Pick one entry with probability proportional to its weight.
func pick_weighted(arr: Array, weights: Array):
	if arr.is_empty():
		return null
	var total := 0.0
	for w in weights:
		total += w
	var r := _rng.randf() * total
	for i in range(arr.size()):
		r -= weights[i]
		if r < 0.0:
			return arr[i]
	return arr[-1]


func shuffle(arr: Array) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out

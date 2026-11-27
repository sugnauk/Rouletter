extends RefCounted
## Chance of reaching a Take target, assuming the felt as it stands now is repeated for every
## remaining spin (betting chips re-placed the same way). Exact over the fair wheel, apart from
## stateful effects (growth, streaks), which it ignores. Shown in the HUD as an estimate.

const Resolver := preload("res://core/resolver.gd")


## Per-spin Take distribution: {take_bucket(int): probability}.
## Crooked pockets are weighted by width; on the Twin Ball wheel every pair of balls counts.
static func spin_distribution(felt) -> Dictionary:
	var dist := {}
	var pockets: Array = felt.board.pockets
	var res := {}
	for pocket in pockets:
		res[pocket] = Resolver.resolve_spin(felt, pocket)
	if not felt.board.def.get("twin", false):
		for pocket in pockets:
			var t := int(floor(res[pocket].take))
			dist[t] = dist.get(t, 0.0) + felt.pocket_chance(pocket)
		return dist
	for a in pockets:
		for b in pockets:
			var t := int(floor(Resolver.combine_twin(felt, res[a], res[b]).take))
			dist[t] = dist.get(t, 0.0) + felt.pocket_chance(a) * felt.pocket_chance(b)
	return dist


static func hit_chance(felt, need: float, spins: int) -> float:
	if need <= 0.0:
		return 1.0
	if spins <= 0:
		return 0.0
	var step := spin_distribution(felt)
	var target := int(ceil(need))
	# Cap sums at the target: everything at or above it counts as a hit.
	var cur := {0: 1.0}
	for i in range(spins):
		var nxt := {}
		for a in cur:
			if a >= target:
				nxt[a] = nxt.get(a, 0.0) + cur[a]
				continue
			for d in step:
				var s := mini(a + d, target)
				nxt[s] = nxt.get(s, 0.0) + cur[a] * step[d]
		cur = nxt
	return clampf(cur.get(target, 0.0), 0.0, 1.0)

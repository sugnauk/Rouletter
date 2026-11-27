extends RefCounted
## Chance of reaching a Take target, assuming the felt as it stands now is repeated for every
## remaining spin (betting chips re-placed the same way). Exact over the fair wheel, apart from
## stateful effects (growth, streaks), which it ignores. Shown in the HUD as an estimate.

const Resolver := preload("res://core/resolver.gd")
const Preview := preload("res://core/preview.gd")
const Content := preload("res://core/content.gd")


## Per-spin Take distribution: {take_bucket(int): probability}.
## Crooked pockets are weighted by width; on the Twin Ball wheel every pair of balls counts.
## Cached per felt (the HUD asks after every bet).
static func spin_distribution(felt) -> Dictionary:
	return Preview._cached("odds#" + Preview.signature(felt), func(): return _spin_distribution(felt))


static func _spin_distribution(felt) -> Dictionary:
	var dist := {}
	var pockets: Array = felt.board.pockets
	if not felt.board.def.get("twin", false):
		for pocket in pockets:
			var t := int(floor(Resolver.resolve_spin(felt, pocket).take))
			dist[t] = dist.get(t, 0.0) + felt.pocket_chance(pocket)
		return dist
	# Twin Ball: resolve each pocket once and group pockets that resolve the same way, then combine
	# every pair of groups with plain arithmetic (the rules of Resolver.combine_twin: a stake is
	# charged once; both balls in one pocket is x3, so same-pocket pairs are counted apart).
	var groups := {}   # outcome key -> {g, l, ls, q (chance), qq (sum of chance squared)}
	for p in pockets:
		var r := Resolver.resolve_spin(felt, p)
		var ls := Resolver._losses(r)
		var key := "%s|%d|%s" % [r.gross, r.lost, ls]
		if not groups.has(key):
			groups[key] = {"g": r.gross, "l": r.lost, "ls": ls, "q": 0.0, "qq": 0.0}
		var q: float = felt.pocket_chance(p)
		groups[key].q += q
		groups[key].qq += q * q
	for ga in groups.values():
		for gb in groups.values():
			var la: Dictionary = ga.ls
			var lb: Dictionary = gb.ls
			var refund := 0
			for k in la:
				var x: int = la[k]
				var y: int = lb.get(k, 0)
				refund += mini(x, y) if y > 0 else x
			for k in lb:
				if not la.has(k):
					refund += lb[k]
			var take: float = maxf(0.0, ga.g + gb.g - maxi(0, ga.l + gb.l - refund))
			var pair_q: float = ga.q * gb.q
			if is_same(ga, gb) and take > 0.0:   # the same pocket twice is a TWIN: x3
				var t3 := int(floor(take * Content.TWIN_MULT))
				dist[t3] = dist.get(t3, 0.0) + ga.qq
				pair_q -= ga.qq
			if pair_q > 1e-12:
				var t := int(floor(take))
				dist[t] = dist.get(t, 0.0) + pair_q
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

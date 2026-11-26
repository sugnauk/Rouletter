extends RefCounted
## Persistent meta-progression between runs: Markers, unlocks, story beats, stats, options.
## (The debt itself belongs to each run: see RunState.marker_total.)
## Plain data + JSON so tests can round-trip it to any path.

const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")

const DEFAULT_PATH := "user://profile.json"

var markers: int = 0
var unlocked: Array = []
var seen_beats: Array = []
var runs: int = 0
var wins: int = 0
var best_night: int = 0
var total_paid: int = 0      ## lifetime dollars paid on markers (a stat)
var best_take: int = 0       ## best single-run Take (a stat)
var best_spin: int = 0       ## best single spin ever (personal-best celebrations)
var feats: Array = []        ## Feats earned (core/feats.gd)
var seen_items: Array = []   ## Almanac: content ids that have appeared in the Cage
var used_items: Array = []   ## Almanac: content ids you have bought
var challenge_level: Dictionary = {}   ## challenge id -> levels beaten (0-3); level N+1 opens after N
var weekly_runs: Array = []      ## this week's weekly-challenge results: {id, nights, take, won, code}
var wheels_won: Array = []        ## wheels you've won a run on (the Grand Tour Feat)
var weekly_best: Dictionary = {}   ## this week's best weekly challenge run: {id, nights, won, take}
var best_grade: int = -1     ## highest marker grade won (-1: none yet)
var history: Array = []      ## the last runs, newest first: {wheel, acts, nights, take, best_spin, won}
const HISTORY_MAX := 10
var act2_runs: int = 0
var act2_wins: int = 0
## Player options (Options screen). Missing keys fall back to these defaults.
const DEFAULT_SETTINGS := {"crt": true, "cb_marks": false, "cards": true, "shake": true, "music": 0.6, "sfx": 1.0, "zoom_felt": false, "fast_spins": false}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var save_path: String = DEFAULT_PATH


func _init() -> void:
	unlocked = default_unlocks()


## Everything with unlock cost 0.
static func default_unlocks() -> Array:
	var out := []
	for table in [Wheels.WHEELS, Content.CHIPS, Content.UPGRADES, Content.HOUSE_RULES, Content.FEATURES, Content.VENDORS]:
		for id in table:
			if table[id].get("unlock", 0) == 0:
				out.append(id)
	return out


## Every unlockable entry with its cost and category, cheapest first.
static func catalogue() -> Array:
	var out := []
	var cats := {"wheel": Wheels.WHEELS, "chip": Content.CHIPS, "upgrade": Content.UPGRADES,
		"rule": Content.HOUSE_RULES, "feature": Content.FEATURES, "vendor": Content.VENDORS, "starter": Content.STARTERS}
	for cat in cats:
		var table: Dictionary = cats[cat]
		for id in table:
			var cost: int = table[id].get("unlock", 0)
			if cost > 0:
				out.append({"id": id, "category": cat, "cost": cost, "name": table[id].name, "desc": table[id].desc})
	out.sort_custom(func(a, b): return a.cost < b.cost)
	return out


## The Pawn Shop as a tree: lanes of unlocks, cheapest at the top. Each item needs the one
## above it in its lane. [{title, ids}], built from catalogue() (big categories split in two).
static func tree() -> Array:
	var by := {}
	for e in catalogue():
		var cat: String = e.category if e.category in ["wheel", "chip", "upgrade", "rule"] else "extra"
		by[cat] = by.get(cat, []) + [e.id]
	var lanes := []
	for cat in ["wheel", "chip", "upgrade", "rule", "extra"]:
		var ids: Array = by.get(cat, [])
		if ids.is_empty():
			continue
		var title: String = {"wheel": "WHEELS", "chip": "CHIPS", "upgrade": "FELT", "rule": "RULES", "extra": "EXTRAS"}[cat]
		if ids.size() > 6:
			var a: Array = []
			var b: Array = []
			for i in range(ids.size()):
				(a if i % 2 == 0 else b).append(ids[i])
			lanes.append({"title": title + " I", "ids": a})
			lanes.append({"title": title + " II", "ids": b})
		else:
			lanes.append({"title": title, "ids": ids})
	return lanes


## The unlock that has to be owned before `id` (the one above it in its lane), or "".
static func requires(id: String) -> String:
	for lane in tree():
		var i: int = lane.ids.find(id)
		if i > 0:
			return lane.ids[i - 1]
	return ""


func can_unlock(id: String) -> bool:
	var req := requires(id)
	return not is_unlocked(id) and (req == "" or is_unlocked(req))


func is_unlocked(id: String) -> bool:
	return id in unlocked


func buy_unlock(id: String) -> bool:
	if is_unlocked(id):
		return false
	if not can_unlock(id):
		return false
	for e in catalogue():
		if e.id == id and markers >= e.cost:
			markers -= e.cost
			unlocked.append(id)
			return true
	return false


## The cheapest thing still locked in the Pawn Shop (a goal to aim for), or {} if none.
func next_unlock() -> Dictionary:
	for e in catalogue():
		if can_unlock(e.id):
			return e
	return {}


## The highest marker grade you may pick: one above your best win.
func max_grade() -> int:
	return mini(best_grade + 1, Content.GRADES.size() - 1)


func add_history(entry: Dictionary) -> void:
	history.push_front(entry)
	while history.size() > HISTORY_MAX:
		history.pop_back()


## Start over: everything except the options goes back to a fresh profile.
func reset() -> void:
	var keep: Dictionary = settings.duplicate()
	from_dict({})
	settings = keep


func note_seen(id: String) -> void:
	if id not in seen_items:
		seen_items.append(id)


func note_used(id: String) -> void:
	note_seen(id)
	if id not in used_items:
		used_items.append(id)


## Act II opens once you have won an Act I run (paid a marker in full).
func act2_unlocked() -> bool:
	return wins > 0 or "free" in seen_beats


## Called once when a run ends. `paid` is how much of that run's marker was paid off.
func record_run(nights_cleared: int, total_take: float, won: bool, acts: int = 1, paid: int = 0, grade: int = 0) -> Dictionary:
	runs += 1
	if won:
		best_grade = maxi(best_grade, grade)
	if acts >= 2:
		act2_runs += 1
		if won:
			act2_wins += 1
	total_paid += paid
	best_take = maxi(best_take, int(total_take))
	var earned := nights_cleared * Content.MARKERS_PER_NIGHT + (Content.MARKERS_VICTORY if won else 0)
	markers += earned
	if won:
		wins += 1
	best_night = maxi(best_night, nights_cleared)
	return {"paid": paid, "markers": earned}


func to_dict() -> Dictionary:
	return {"markers": markers, "unlocked": unlocked, "seen_beats": seen_beats,
		"runs": runs, "wins": wins, "best_night": best_night,
		"total_paid": total_paid, "best_take": best_take, "best_spin": best_spin, "feats": feats, "seen_items": seen_items, "used_items": used_items, "history": history, "best_grade": best_grade, "act2_runs": act2_runs, "act2_wins": act2_wins, "weekly_best": weekly_best, "wheels_won": wheels_won, "challenge_level": challenge_level, "weekly_runs": weekly_runs, "settings": settings}


func from_dict(d: Dictionary) -> void:
	markers = int(d.get("markers", 0))
	unlocked = d.get("unlocked", default_unlocks())
	for id in default_unlocks():  # new free content added since the save
		if id not in unlocked:
			unlocked.append(id)
	seen_beats = d.get("seen_beats", [])
	weekly_best = d.get("weekly_best", {})
	wheels_won = d.get("wheels_won", [])
	challenge_level = d.get("challenge_level", {})
	weekly_runs = d.get("weekly_runs", [])
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_night = int(d.get("best_night", 0))
	total_paid = int(d.get("total_paid", 0))
	best_take = int(d.get("best_take", 0))
	best_spin = int(d.get("best_spin", 0))
	feats = d.get("feats", [])
	seen_items = d.get("seen_items", [])
	used_items = d.get("used_items", [])
	history = d.get("history", [])
	best_grade = int(d.get("best_grade", -1))
	act2_runs = int(d.get("act2_runs", 0))
	act2_wins = int(d.get("act2_wins", 0))
	settings = DEFAULT_SETTINGS.duplicate()
	var saved: Dictionary = d.get("settings", {})
	for k in saved:
		if settings.has(k):
			settings[k] = bool(saved[k]) if DEFAULT_SETTINGS[k] is bool else clampf(float(saved[k]), 0.0, 1.0)


func save(path: String = "") -> bool:
	if path == "":
		path = save_path
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "  "))
	return true


func load_from(path: String = "") -> bool:
	if path == "":
		path = save_path
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	from_dict(parsed)
	return true

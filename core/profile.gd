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
var act2_runs: int = 0
var act2_wins: int = 0
## Player options (Options screen). Missing keys fall back to these defaults.
const DEFAULT_SETTINGS := {"crt": true, "cb_marks": false, "cards": true, "shake": true}
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
		"rule": Content.HOUSE_RULES, "feature": Content.FEATURES, "vendor": Content.VENDORS}
	for cat in cats:
		var table: Dictionary = cats[cat]
		for id in table:
			var cost: int = table[id].get("unlock", 0)
			if cost > 0:
				out.append({"id": id, "category": cat, "cost": cost, "name": table[id].name, "desc": table[id].desc})
	out.sort_custom(func(a, b): return a.cost < b.cost)
	return out


func is_unlocked(id: String) -> bool:
	return id in unlocked


func buy_unlock(id: String) -> bool:
	if is_unlocked(id):
		return false
	for e in catalogue():
		if e.id == id and markers >= e.cost:
			markers -= e.cost
			unlocked.append(id)
			return true
	return false


## Act II opens once you have won an Act I run (paid a marker in full).
func act2_unlocked() -> bool:
	return wins > 0 or "free" in seen_beats


## Called once when a run ends. `paid` is how much of that run's marker was paid off.
func record_run(nights_cleared: int, total_take: float, won: bool, acts: int = 1, paid: int = 0) -> Dictionary:
	runs += 1
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
		"total_paid": total_paid, "best_take": best_take, "act2_runs": act2_runs, "act2_wins": act2_wins, "settings": settings}


func from_dict(d: Dictionary) -> void:
	markers = int(d.get("markers", 0))
	unlocked = d.get("unlocked", default_unlocks())
	for id in default_unlocks():  # new free content added since the save
		if id not in unlocked:
			unlocked.append(id)
	seen_beats = d.get("seen_beats", [])
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_night = int(d.get("best_night", 0))
	total_paid = int(d.get("total_paid", 0))
	best_take = int(d.get("best_take", 0))
	act2_runs = int(d.get("act2_runs", 0))
	act2_wins = int(d.get("act2_wins", 0))
	settings = DEFAULT_SETTINGS.duplicate()
	var saved: Dictionary = d.get("settings", {})
	for k in saved:
		if settings.has(k):
			settings[k] = bool(saved[k])


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

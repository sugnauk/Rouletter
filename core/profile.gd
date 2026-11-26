extends RefCounted
## Persistent meta-progression between runs: the debt, Markers, unlocks, story beats.
## Plain data + JSON so tests can round-trip it to any path.

const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")

const DEFAULT_PATH := "user://profile.json"

var debt: int = Content.DEBT_START
var markers: int = 0
var unlocked: Array = []
var seen_beats: Array = []
var runs: int = 0
var wins: int = 0
var best_night: int = 0
var debt2: int = Content.ACT2_DEBT      ## Act II marker (the Floor Above)
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


## Act II opens once Act I's marker is paid (or its epilogue has played).
func act2_unlocked() -> bool:
	return debt <= 0 or "free" in seen_beats


## Called once when a run ends. Take pays Act I's marker first, then Act II's.
func record_run(nights_cleared: int, total_take: float, won: bool, acts: int = 1) -> Dictionary:
	runs += 1
	if acts == 2:
		act2_runs += 1
		if won:
			act2_wins += 1
	var paid := int(total_take) * Content.DEBT_PER_TAKE
	var to_first := mini(paid, debt)
	debt -= to_first
	if paid > to_first and act2_unlocked():
		debt2 = maxi(0, debt2 - (paid - to_first))
	var earned := nights_cleared * Content.MARKERS_PER_NIGHT + (Content.MARKERS_VICTORY if won else 0)
	markers += earned
	if won:
		wins += 1
	best_night = maxi(best_night, nights_cleared)
	return {"paid": paid, "markers": earned}


func to_dict() -> Dictionary:
	return {"debt": debt, "markers": markers, "unlocked": unlocked, "seen_beats": seen_beats,
		"runs": runs, "wins": wins, "best_night": best_night,
		"debt2": debt2, "act2_runs": act2_runs, "act2_wins": act2_wins, "settings": settings}


func from_dict(d: Dictionary) -> void:
	debt = int(d.get("debt", Content.DEBT_START))
	markers = int(d.get("markers", 0))
	unlocked = d.get("unlocked", default_unlocks())
	for id in default_unlocks():  # new free content added since the save
		if id not in unlocked:
			unlocked.append(id)
	seen_beats = d.get("seen_beats", [])
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_night = int(d.get("best_night", 0))
	debt2 = int(d.get("debt2", Content.ACT2_DEBT))
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

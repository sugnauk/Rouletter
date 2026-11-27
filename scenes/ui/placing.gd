extends RefCounted
## Shared by the table and the Cage while you're placing a chip from the rack: mark every spot
## it may go (and where its twin already sits, so it would level up), and draw it as a ghost.

const P := preload("res://scenes/ui/palette.gd")


static func mark(felt_view, run, selected_item: int) -> void:
	if selected_item >= 0 and selected_item < run.inventory.size():
		var item: Dictionary = run.inventory[selected_item]
		mark_kind(felt_view, run, item.kind, item.get("flaw", ""))
	else:
		clear(felt_view)


## Light every spot a chip of `kind` may go (twins in green), dim the rest (see felt_view).
static func mark_kind(felt_view, run, kind: String, flaw: String = "") -> void:
	clear(felt_view)
	for k in run.felt.board.all_bet_keys():
		if not run.can_place_chip(kind, k):
			continue
		if run.felt.chips_on(k).any(func(c): return not c.is_bet() and c.kind == kind and c.flaw == flaw):
			felt_view.twins[k] = true
		else:
			felt_view.legal[k] = true
	felt_view.ghost = kind
	felt_view.ghost_col = P.chip_color(kind)
	felt_view.queue_redraw()


## Light a fixed set of spots (a felt upgrade's targets).
static func mark_keys(felt_view, keys: Array) -> void:
	clear(felt_view)
	for k in keys:
		felt_view.legal[k] = true
	felt_view.queue_redraw()


static func clear(felt_view) -> void:
	felt_view.legal = {}
	felt_view.twins = {}
	felt_view.ghost = ""
	felt_view.queue_redraw()


## The permanent chips on a felt spot (for the info card), biggest first.
static func perms_on(run, key: String) -> Array:
	var out: Array = run.felt.chips_on(key).filter(func(c): return not c.is_bet())
	out.sort_custom(func(a, b): return a.value > b.value)
	return out

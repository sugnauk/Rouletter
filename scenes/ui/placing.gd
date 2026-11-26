extends RefCounted
## Shared by the table and the Cage while you're placing a chip from the rack: mark every spot
## it may go (and where its twin already sits, so it would level up), and draw it as a ghost.

const P := preload("res://scenes/ui/palette.gd")


static func mark(felt_view, run, selected_item: int) -> void:
	felt_view.legal = {}
	felt_view.twins = {}
	felt_view.ghost = ""
	if selected_item >= 0 and selected_item < run.inventory.size():
		var item: Dictionary = run.inventory[selected_item]
		for k in run.felt.board.all_bet_keys():
			if not run.can_place_chip(item.kind, k):
				continue
			if run.felt.chips_on(k).any(func(c): return not c.is_bet() and c.kind == item.kind and c.flaw == item.get("flaw", "")):
				felt_view.twins[k] = true
			else:
				felt_view.legal[k] = true
		felt_view.ghost = item.kind
		felt_view.ghost_col = P.chip_color(item.kind)
	felt_view.queue_redraw()


## The permanent chips on a felt spot (for the info card), biggest first.
static func perms_on(run, key: String) -> Array:
	var out: Array = run.felt.chips_on(key).filter(func(c): return not c.is_bet())
	out.sort_custom(func(a, b): return a.value > b.value)
	return out

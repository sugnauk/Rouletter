extends RefCounted
## Feats: one-off achievements that pay Markers. Pure checks over run state and spin results,
## so tests can drive them without a scene. The profile records which have been earned.
##
## Events:
##   "spin"  ctx = {res, run}        after every resolved spin
##   "clear" ctx = {info, run}       when a table is paid
##   "end"   ctx = {won, run}        when a run ends

const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")

const FEATS := {
	"straight_up": {"name": "Straight Up", "desc": "Hit a straight-up number.", "reward": 1, "on": "spin"},
	"inside_job": {"name": "Inside Job", "desc": "Win a split, corner, street or line bet.", "reward": 1, "on": "spin"},
	"zero_hero": {"name": "Zero Hero", "desc": "Score Take on a spin that lands on a zero.", "reward": 1, "on": "spin"},
	"high_roller": {"name": "High Roller", "desc": "Have 20 or more chips riding on one spin.", "reward": 1, "on": "spin"},
	"big_night": {"name": "Big Night", "desc": "Score 100 or more Take in a single spin.", "reward": 2, "on": "spin"},
	"jackpot": {"name": "Jackpot", "desc": "Pay a whole table's payment with one spin.", "reward": 1, "on": "spin"},
	"triple_x": {"name": "Multiplied", "desc": "Score a spin with two or more multipliers.", "reward": 2, "on": "spin"},
	"last_gasp": {"name": "Last Gasp", "desc": "Clear a table on its very last spin.", "reward": 1, "on": "clear"},
	"clean_sweep": {"name": "Clean Sweep", "desc": "Clear a table with 4 or more spins to spare.", "reward": 1, "on": "clear"},
	"full_house": {"name": "Full House", "desc": "Own 5 House Rules at once.", "reward": 2, "on": "clear"},
	"stacked_felt": {"name": "Stacked Felt", "desc": "Have 8 permanent chips on the felt.", "reward": 1, "on": "clear"},
	"spare_change": {"name": "Spare Change", "desc": "Bank 50 spare Take in one run.", "reward": 1, "on": "clear"},
	"beat_accountant": {"name": "Balanced Books", "desc": "Beat The Accountant.", "reward": 1, "on": "clear", "enforcer": "accountant"},
	"beat_oro": {"name": "Off the Green", "desc": "Beat Madame Oro.", "reward": 1, "on": "clear", "enforcer": "oro"},
	"beat_vic": {"name": "Thawed", "desc": "Beat Vic \"The Rake\".", "reward": 1, "on": "clear", "enforcer": "vic"},
	"beat_sal": {"name": "Uncalled For", "desc": "Beat Big Sal.", "reward": 1, "on": "clear", "enforcer": "sal"},
	"paid_in_full": {"name": "Paid in Full", "desc": "Win a run: pay a whole marker.", "reward": 3, "on": "end"},
	"french_win": {"name": "Très Bien", "desc": "Win a run on the French wheel.", "reward": 1, "on": "end", "wheel": "french"},
	"euro_win": {"name": "Continental", "desc": "Win a run on the European wheel.", "reward": 1, "on": "end", "wheel": "european"},
	"graded": {"name": "Paper Climber", "desc": "Win a run on a Grade 3 marker or higher.", "reward": 2, "on": "end"},
	"vance_paper": {"name": "Vance's Own", "desc": "Win a run on the Grade 9 marker.", "reward": 5, "on": "end"},
	"hard_way": {"name": "The Hard Way", "desc": "Win a run on the American, Triple Zero or Cheater's wheel.", "reward": 2, "on": "end"},
}

const LINE_TYPES := ["split", "corner", "street", "line"]


## Feats newly earned by this event (not already in `earned`).
static func check(event: String, ctx: Dictionary, earned: Array) -> Array:
	var out := []
	for id in FEATS:
		var f: Dictionary = FEATS[id]
		if f.on != event or id in earned:
			continue
		if _met(id, f, ctx):
			out.append(id)
	return out


static func _met(id: String, f: Dictionary, ctx: Dictionary) -> bool:
	var run = ctx.run
	match id:
		"straight_up":
			return ctx.res.events.any(func(e): return e.kind == "win" and e.label == "straight")
		"inside_job":
			return ctx.res.events.any(func(e): return e.kind == "win" and e.label in LINE_TYPES)
		"zero_hero":
			return run.felt.board.is_zero(ctx.res.pocket) and ctx.res.take > 0.0
		"high_roller":
			return ctx.get("staked", 0) >= 20
		"big_night":
			return ctx.res.take >= 100.0
		"jackpot":
			return ctx.res.take > 0.0 and ctx.res.take >= ctx.get("target", 1 << 30)
		"triple_x":
			return ctx.res.take > 0.0 and ctx.res.events.filter(func(e): return e.kind == "mult").size() >= 2
		"last_gasp":
			return ctx.info.spins_left == 0
		"clean_sweep":
			return ctx.info.spins_left >= 4
		"full_house":
			return run.felt.house_rules.size() >= 5
		"stacked_felt":
			return run.felt.perm_chips().size() >= 8
		"spare_change":
			return run.overflow >= 50
		"paid_in_full":
			return ctx.won
		"graded":
			return ctx.won and run.grade >= 2
		"vance_paper":
			return ctx.won and run.grade >= 8
		"hard_way":
			return ctx.won and run.wheel_id in ["american", "triple_zero", "no_zero"]
	if f.has("enforcer"):
		return ctx.info.boss and ctx.info.enforcer == f.enforcer
	if f.has("wheel"):
		return ctx.won and run.wheel_id == f.wheel
	return false

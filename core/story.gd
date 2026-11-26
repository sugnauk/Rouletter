extends RefCounted
## Story data. Noir debt: you signed a marker to Mr. Vance, owner of the Gilded Ace.
## Every run is a night shift of payments; Take paid in chips down the debt.
## Lines are {speaker, text}. Every scene has an id (recorded in profile.seen_beats once seen)
## and a title for the Journal.
##
## The cast:
##   Mr. Vance       - owns the Gilded Ace and your marker
##   Dolores         - the cigarette girl; hears everything
##   Lucky Lou       - a rival gambler who has been "almost even" with Vance for twenty years
##   Abe             - the pawnbroker on Fifth Street (the Pawn Shop)
##   the Cashier, the Pit Boss - vendors in the Cage
##   the Enforcers   - Vance's people (lines in core/content.gd)

const INTRO := [
	{"speaker": "Narrator", "text": "1974. The Gilded Ace. Neon on wet asphalt, and a marker with your name on it."},
	{"speaker": "Mr. Vance", "text": "One million. You'll pay it the only way people like you can: at my tables."},
	{"speaker": "Mr. Vance", "text": "The wheels are honest. I insist on it. It's the felt you'll have to beat."},
	{"speaker": "Narrator", "text": "Each table, a payment comes due. Miss one and you don't leave the building."},
]

## Between runs, on the end screen. A beat plays once every condition holds:
##   debt <= `debt`, runs >= `after_runs`, best_night >= `best_night`, wins >= `wins`,
##   wins <= `max_wins`.
const BEATS := [
	{"id": "first_night", "title": "The Alley", "debt": 1000000, "after_runs": 1, "lines": [
		{"speaker": "Narrator", "text": "You wake up in the alley behind the Ace. Your pockets are lighter. The marker isn't."},
		{"speaker": "Mr. Vance", "text": "Back so soon? Good. The vig doesn't sleep either."}]},
	{"id": "first_enforcer", "title": "Lucky Lou", "best_night": 1, "lines": [
		{"speaker": "Lucky Lou", "text": "You walked away from one of Vance's people. Nobody walks away. They limp, at best."},
		{"speaker": "Lucky Lou", "text": "Name's Lou. Lucky Lou. Twenty years I've been almost even with that man."},
		{"speaker": "Lucky Lou", "text": "Almost. Remember the word. It's the most expensive one in the building."}]},
	{"id": "regular", "title": "A Regular", "after_runs": 3, "lines": [
		{"speaker": "Dolores", "text": "Cigarettes, cigars... you again? Third night running. You're practically furniture."},
		{"speaker": "Dolores", "text": "Word of advice, sugar. Vance doesn't mind losers. He minds people who stop coming back."}]},
	{"id": "nine_hundred", "title": "He Prints the Felt", "debt": 900000, "lines": [
		{"speaker": "Dolores", "text": "You're the one paying Vance in chips? Folks say he never rigs a wheel."},
		{"speaker": "Dolores", "text": "He doesn't need to. He prints the felt."}]},
	{"id": "first_win", "title": "A Full Night", "wins": 1, "lines": [
		{"speaker": "Narrator", "text": "Four nights, four payments. The sun comes up over the parking lot like an unpaid bill."},
		{"speaker": "Mr. Vance", "text": "A whole shift. I had money on you not making it past Tuesday."},
		{"speaker": "Mr. Vance", "text": "I lost. I want you to understand how rarely I say that."}]},
	{"id": "the_fixture", "title": "The Fixture", "after_runs": 6, "max_wins": 0, "lines": [
		{"speaker": "Big Sal", "text": "Six nights and you ain't finished one. Boss is starting to talk about you like a lamp."},
		{"speaker": "Big Sal", "text": "Part of the décor. Lights up, goes out. Gets plugged back in."},
		{"speaker": "Lucky Lou", "text": "Don't listen to him. Watch the felt, not the wheel. Build something that pays when you're wrong."}]},
	{"id": "three_quarters", "title": "Fifth Street", "debt": 750000, "lines": [
		{"speaker": "Abe", "text": "I've been saving the good stock for you. Don't tell the others. I tell all the others that."},
		{"speaker": "Mr. Vance", "text": "Three quarters. You're becoming expensive to keep around."}]},
	{"id": "half", "title": "Upstairs", "debt": 500000, "lines": [
		{"speaker": "Big Sal", "text": "Half paid. Vance is moving you upstairs. Nobody comes back from upstairs."},
		{"speaker": "Narrator", "text": "Above the casino floor, a private room. Its wheel has no numbers you recognise."}]},
	{"id": "lou_out", "title": "Almost Even", "debt": 400000, "lines": [
		{"speaker": "Dolores", "text": "Lou's gone. Paid off his marker last night, every cent. Walked out the front door."},
		{"speaker": "Dolores", "text": "Then he walked right back in. Said the street felt too quiet."},
		{"speaker": "Lucky Lou", "text": "Almost even was a good place, kid. You can see both doors from there."}]},
	{"id": "quarter", "title": "Patience", "debt": 250000, "lines": [
		{"speaker": "Mr. Vance", "text": "You know what the house edge really is? Patience. Mine is running out."}]},
	{"id": "free", "title": "Act I: Paid in Full", "debt": 0, "lines": [
		{"speaker": "Narrator", "text": "The last chip crosses the felt. The cashier counts twice. Then a third time, for Vance."},
		{"speaker": "Mr. Vance", "text": "Paid in full. Here's your marker back. Frame it. Most people only see theirs on a tombstone."},
		{"speaker": "Dolores", "text": "You're free, sugar. You know what free people do at four in the morning?"},
		{"speaker": "Dolores", "text": "They go home. ...You're not going home, are you."},
		{"speaker": "Mr. Vance", "text": "There's a room upstairs. Better wheels. Bigger markers. The kind of game a free man can afford."},
		{"speaker": "Narrator", "text": "END OF ACT I. The elevator to the Floor Above has one button, and it is already lit."}]},
	# --- Act II: the Floor Above ---
	{"id": "upstairs_first", "title": "The Floor Above", "act2_runs": 1, "lines": [
		{"speaker": "Narrator", "text": "Upstairs the carpet is thicker and the voices are quieter. Nobody here is playing for rent."},
		{"speaker": "Mr. Vance", "text": "A new marker, for a new floor. Five million. Don't look at me like that. You signed it on the way up."}]},
	{"id": "owner_beaten", "title": "Across the Table", "act2_wins": 1, "lines": [
		{"speaker": "Mr. Vance", "text": "Nobody has beaten me at my own table since 1959. I want you to know I remember his name."},
		{"speaker": "Mr. Vance", "text": "I'm going to remember yours too. That isn't a compliment."},
		{"speaker": "Dolores", "text": "He poured you a drink. He doesn't pour drinks. I've worked here eleven years."}]},
	{"id": "act2_half", "title": "Half the Floor", "debt2": 2500000, "lines": [
		{"speaker": "Lucky Lou", "text": "They let me up here once. I lasted four spins. You're making it look like a job."},
		{"speaker": "Lucky Lou", "text": "Careful. In this building, when it looks like a job, it usually is one."}]},
	{"id": "act2_free", "title": "Act II: The House", "debt2": 0, "lines": [
		{"speaker": "Narrator", "text": "The second marker burns in an ashtray on Vance's desk. He watches it the whole way down."},
		{"speaker": "Mr. Vance", "text": "You know what you are now? You're the house. Everyone who sits at that wheel is playing against you."},
		{"speaker": "Mr. Vance", "text": "The wheel is honest. I insisted on it. Now you get to find out why."},
		{"speaker": "Narrator", "text": "END OF ACT II. The neon outside flickers, and for a second it spells your name."}]},
]

## Before nights 2-8 of a run (5-8 are Act II only) (key = the night about to start, 1-based). Unseen
## variants play first; once all have been seen they rotate by run count.
const INTERLUDES := {
	5: [
		{"id": "n5_elevator", "title": "Night 5: The Elevator", "lines": [
			{"speaker": "Narrator", "text": "The elevator has velvet walls and one button. The operator doesn't look at you. He's paid not to."},
			{"speaker": "Dolores", "text": "Nobody sells cigarettes upstairs. They have people who light them for you."}]},
	],
	6: [
		{"id": "n6_lou", "title": "Night 6: Lou's Warning", "lines": [
			{"speaker": "Lucky Lou", "text": "The private rooms don't care about your stack. They care how long you last."},
			{"speaker": "Lucky Lou", "text": "Lasting is the only edge a player ever gets up here."}]},
	],
	7: [
		{"id": "n7_abe", "title": "Night 7: The Pawn Ticket", "lines": [
			{"speaker": "Abe", "text": "I came up here myself, can you believe it. Brought you your coin back. Felt wrong, selling it."},
			{"speaker": "Abe", "text": "Don't thank me. Win, and buy something expensive from me after."}]},
	],
	8: [
		{"id": "n8_vance", "title": "Night 8: The Owner's Table", "lines": [
			{"speaker": "Mr. Vance", "text": "Every night for twenty years, somebody sits across from me and thinks the wheel will save them."},
			{"speaker": "Mr. Vance", "text": "It won't. It's honest. Honest things don't save anybody. Shall we?"}]},
	],
	2: [
		{"id": "n2_dolores", "title": "Night 2: Smoke Break", "lines": [
			{"speaker": "Dolores", "text": "Smoke? On the house. Well. On Vance's house."},
			{"speaker": "Dolores", "text": "The High Roller table's watching you. Up there, watching is how they bet."}]},
		{"id": "n2_lou", "title": "Night 2: Lou's Wheel", "lines": [
			{"speaker": "Lucky Lou", "text": "You're at my wheel tonight. Don't worry, I don't own it. Nobody owns anything here but him."},
			{"speaker": "Lucky Lou", "text": "Tip: the zero isn't the enemy. The zero is the rent."}]},
	],
	3: [
		{"id": "n3_abe", "title": "Night 3: Collateral", "lines": [
			{"speaker": "Abe", "text": "Your watch, your ring, your lucky coin. I'll hold them. You hold your nerve."},
			{"speaker": "Abe", "text": "If you don't come back, I'll sell the coin. Luck goes for a good price this time of night."}]},
		{"id": "n3_vance", "title": "Night 3: A Warm Plate", "lines": [
			{"speaker": "Mr. Vance", "text": "Halfway through the shift and still breathing. I'll have the kitchen keep a plate warm."},
			{"speaker": "Mr. Vance", "text": "For you or for whoever replaces you. The kitchen doesn't ask."}]},
	],
	4: [
		{"id": "n4_sal", "title": "Night 4: The Last Shift", "lines": [
			{"speaker": "Big Sal", "text": "Last night of the shift. Vance sends his best. That's me. I'm his best."},
			{"speaker": "Big Sal", "text": "Nothing personal. I get paid either way. You only get paid one."}]},
		{"id": "n4_dolores", "title": "Night 4: The Back Door", "lines": [
			{"speaker": "Dolores", "text": "Whatever happens at that table... the back door's unlocked till four."},
			{"speaker": "Dolores", "text": "I didn't tell you that. I don't tell anybody anything. That's why everybody tells me."}]},
	],
}

## The first time a vendor's window opens in the Cage.
const VENDOR_INTROS := {
	"cashier": {"id": "meet_cashier", "title": "The Cashier", "lines": [
		{"speaker": "Cashier", "text": "Chips, felt work, the odd favour. Cash on the counter. I don't do credit, I don't do sad stories."},
		{"speaker": "Cashier", "text": "Anything you buy goes on the felt before you leave my window. House policy."}]},
	"pit_boss": {"id": "meet_pit_boss", "title": "The Pit Boss", "lines": [
		{"speaker": "Pit Boss", "text": "I sell House Rules. I don't take dollars. I take chips, off your next stack."},
		{"speaker": "Pit Boss", "text": "Every rule you own, the next one costs more. That's how I keep the floor honest."}]},
	"loan_shark": {"id": "meet_loan_shark", "title": "The Loan Shark", "lines": [
		{"speaker": "Loan Shark", "text": "Short? Everybody's short at four in the morning. I've got cash, no paperwork."},
		{"speaker": "Loan Shark", "text": "You don't pay me back. You pay Vance a little extra at the next table. He passes it along. Clean."}]},
	"fence": {"id": "meet_fence", "title": "The Fence", "lines": [
		{"speaker": "Fence", "text": "Half price. Don't ask where they're from. Some are cracked, some are hot, some won't come off the felt."},
		{"speaker": "Fence", "text": "If the house finds a hot one, it was never mine. I was never here. Neither were you."}]},
}


static func _holds(b: Dictionary, profile) -> bool:
	if profile.debt > b.get("debt", 1 << 40):
		return false
	if profile.runs < b.get("after_runs", 1):
		return false
	if profile.best_night < b.get("best_night", 0):
		return false
	if profile.wins < b.get("wins", 0):
		return false
	if b.has("max_wins") and profile.wins > b.max_wins:
		return false
	if profile.debt2 > b.get("debt2", 1 << 40):
		return false
	if profile.act2_wins < b.get("act2_wins", 0):
		return false
	if profile.act2_runs < b.get("act2_runs", 0):
		return false
	return true


static func beats_due(profile) -> Array:
	var out := []
	for b in BEATS:
		if b.id in profile.seen_beats:
			continue
		if _holds(b, profile):
			out.append(b)
	return out


## The interlude before `night` (1-based); unseen first, then rotating by run count.
static func interlude(night: int, profile) -> Dictionary:
	var options: Array = INTERLUDES.get(night, [])
	if options.is_empty():
		return {}
	for o in options:
		if o.id not in profile.seen_beats:
			return o
	return options[profile.runs % options.size()]


## Every scene in Journal order: intro, beats, vendor intros, interludes.
static func all_scenes() -> Array:
	var out := [{"id": "intro", "title": "The Marker", "lines": INTRO}]
	out.append_array(BEATS)
	for v in VENDOR_INTROS:
		out.append(VENDOR_INTROS[v])
	var nights: Array = INTERLUDES.keys()
	nights.sort()
	for n in nights:
		out.append_array(INTERLUDES[n])
	return out

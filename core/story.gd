extends RefCounted
## Story data. Noir debt: you signed a marker to Mr. Vance, owner of the Gilded Ace.
## Every run is a night shift of payments; Take paid in chips down the debt.
## Lines are {speaker, text}. Beats unlock as the debt shrinks.

const INTRO := [
	{"speaker": "Narrator", "text": "1974. The Gilded Ace. Neon on wet asphalt, and a marker with your name on it."},
	{"speaker": "Mr. Vance", "text": "One million. You'll pay it the only way people like you can: at my tables."},
	{"speaker": "Mr. Vance", "text": "The wheels are honest. I insist on it. It's the felt you'll have to beat."},
	{"speaker": "Narrator", "text": "Each table, a payment comes due. Miss one and you don't leave the building."},
]

## Shown between runs once the debt drops to `debt` or below.
const BEATS := [
	{"id": "first_night", "debt": 1000000, "after_runs": 1, "lines": [
		{"speaker": "Narrator", "text": "You wake up in the alley behind the Ace. Your pockets are lighter. The marker isn't."},
		{"speaker": "Mr. Vance", "text": "Back so soon? Good. The vig doesn't sleep either."}]},
	{"id": "nine_hundred", "debt": 900000, "lines": [
		{"speaker": "Cigarette Girl", "text": "You're the one paying Vance in chips? Folks say he never rigs a wheel."},
		{"speaker": "Cigarette Girl", "text": "He doesn't need to. He prints the felt."}]},
	{"id": "three_quarters", "debt": 750000, "lines": [
		{"speaker": "Narrator", "text": "A pawnbroker on Fifth starts saving you the good stock. Word travels."},
		{"speaker": "Mr. Vance", "text": "Three quarters. You're becoming expensive to keep around."}]},
	{"id": "half", "debt": 500000, "lines": [
		{"speaker": "Big Sal", "text": "Half paid. Vance is moving you upstairs. Nobody comes back from upstairs."},
		{"speaker": "Narrator", "text": "Above the casino floor, a private room. Its wheel has no numbers you recognise."}]},
	{"id": "quarter", "debt": 250000, "lines": [
		{"speaker": "Mr. Vance", "text": "You know what the house edge really is? Patience. Mine is running out."}]},
	{"id": "free", "debt": 0, "lines": [
		{"speaker": "Mr. Vance", "text": "Paid in full. Here's your marker back."},
		{"speaker": "Mr. Vance", "text": "...And here's tomorrow's. Same time?"}]},
]


static func beats_due(profile) -> Array:
	var out := []
	for b in BEATS:
		if b.id in profile.seen_beats:
			continue
		if profile.debt <= b.debt and profile.runs >= b.get("after_runs", 0):
			out.append(b)
	return out

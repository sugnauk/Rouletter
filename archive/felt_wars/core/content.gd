extends RefCounted
## All game content and balance numbers in one place.
## Originality guard: every entry carries a `note` saying why it is roulette-specific.
## Before adding an item, check it is not a reskin of a Balatro joker, enhancement or seal.

# --- Balance -----------------------------------------------------------------
const START_BANKROLL := 150
const PERM_PRICE := 12           ## coins per point of permanent chip value
const BANK_BASE := 200           ## table float at tier 0
const BANK_STEP := 250           ## extra float per tier
const HOUSE_START_BASE := 2      ## House squares seeded at tier 0 (plus 0 itself)
const HOUSE_START_STEP := 3      ## extra House squares per tier
const BUDGET_BASE := 1           ## House chip value placed per spin at tier 0
const BUDGET_STEP := 1           ## extra House budget per tier
const BOSS_BANK := 2000
const BOSS_HOUSE_START := 12
const BOSS_BUDGET := 5
const TEMP_SIZES := [1, 5, 25]   ## classic one-spin bets
const PERM_SIZES := [1, 5, 25]   ## permanent chip tiers
const SHIFT_SPINS := 14          ## spins before the dealer closes the table
const SHIFT_PENALTY := 0.25      ## bankroll share lost if the shift ends unbroken
const MINT_INCOME := 2
const LINK_SHARE := 0.25
const RED_STREAK_STEP := 0.10
const RENT_CONTROL_CUT := 0.10
const GILDED_PAYOUT := 40
const LOAN_SHARK_CASH := 100
const LOAN_SHARK_BANK_BONUS := 50

# --- Chips -------------------------------------------------------------------
## `straight_only`: may only sit on a single number. `zero_only`: only on 0.
const CHIPS := {
	"temp": {"name": "Bet", "desc": "A normal one-spin bet. Lost on a miss.", "straight_only": false,
		"note": "The plain roulette wager; the -1/37 baseline everything is measured against."},
	"perm": {"name": "Permanent", "desc": "Never cleared. Pays normal odds whenever it hits.", "straight_only": false,
		"note": "The core idea: a bet that stays on the felt, turning the house edge into territory."},
	"magnet": {"name": "Magnet", "desc": "If the ball lands one grid square away, slides onto the winner.", "straight_only": true,
		"note": "Exploits the physical 3x12 layout that only a roulette felt has."},
	"compounding": {"name": "Compounding", "desc": "+1 value every spin it survives.", "straight_only": true,
		"note": "Mirrors the gambler's 'let it ride' on a bet that is never collected."},
	"croupier": {"name": "Croupier", "desc": "On a hit, rakes 1 from every House chip that missed.", "straight_only": true,
		"note": "The croupier's rake sweeping losing chips off the layout."},
	"wildcard_zero": {"name": "Wildcard Zero", "desc": "Sits on 0. When 0 hits, outside bets push and the House collects nothing.", "straight_only": true, "zero_only": true,
		"note": "Attacks the single green pocket, the literal source of the house edge."},
	"mint": {"name": "Mint", "desc": "+2 coins every spin, hit or miss, drawn from the bank.", "straight_only": true,
		"note": "A comp from the pit: casino-funded income for staying at the table."},
	"respin": {"name": "Respin", "desc": "When its number hits, the dealer owes you one extra spin.", "straight_only": true,
		"note": "Spins are the table's clock; this buys time on the shift."},
	"ledger": {"name": "Ledger", "desc": "On a hit, +1 permanent value to your chips on grid-adjacent squares.", "straight_only": true,
		"note": "Growth spreads along felt neighbours, the same geometry splits and corners use."},
	"collector": {"name": "Collector", "desc": "On a hit, +1 coin per value of your other chips in its dozen or column.", "straight_only": true,
		"note": "Pays off roulette's own groupings (dozens/columns) when you crowd them."},
}

## Chips that can be won as spoils (the House's stock you seize).
const SPOIL_CHIPS := ["magnet", "compounding", "croupier", "wildcard_zero", "mint", "respin", "ledger", "collector"]

# --- Felt upgrades -------------------------------------------------------------
## `target`: "square" (a number) or "outside" (a column/dozen bet).
const UPGRADES := {
	"gilded": {"name": "Gilded Number", "desc": "Straight bets on this number pay 40:1 (for whoever owns it).", "target": "square",
		"note": "Rewrites a printed payout on the felt itself; the House profits too if it takes the square."},
	"hot": {"name": "Hot Column/Dozen", "desc": "+1x payout on this column or dozen bet.", "target": "outside",
		"note": "Turns a 2:1 outside box into 3:1."},
	"link": {"name": "Neighbour Link", "desc": "When this number hits, its owner's chips on adjacent squares pay 25%.", "target": "square",
		"note": "A 'neighbours' call bet made physical on the layout."},
	"double_felt": {"name": "Double Felt", "desc": "Chips here count double when deciding who owns the square.", "target": "square",
		"note": "Thick felt you can stack higher on: a pure territory upgrade."},
}

# --- House Rules (global relics) ----------------------------------------------
const HOUSE_RULES := {
	"la_partage": {"name": "La Partage", "desc": "When 0 hits, lost bets return half and the House's collection is halved.",
		"note": "A real French-table rule."},
	"red_streak": {"name": "Red Streak", "desc": "Each consecutive red adds +10% to your payouts.",
		"note": "Plays on the gambler's belief in streaks; the odds stay fair."},
	"rent_control": {"name": "Rent Control", "desc": "House collections are 10% smaller.",
		"note": "A cap on what the House takes from you when it holds the felt."},
	"thirteen": {"name": "Thirteen", "desc": "13 is cursed and pays nobody, but its neighbours pay you 2x.",
		"note": "Superstition around a specific number on a specific layout."},
}

# --- Dealers (House AI personalities) -----------------------------------------
const DEALERS := {
	"shuffler": {"name": "The Shuffler", "desc": "Moves one of its chips every spin and contests your thinnest squares."},
	"banker": {"name": "The Banker", "desc": "Fortifies a single dozen and never lets go of it."},
	"zero_priest": {"name": "The Zero Priest", "desc": "Grows outward from 0, one square at a time."},
}

# --- Pit Boss rules ------------------------------------------------------------
const PIT_RULES := {
	"decay": {"name": "Decay", "desc": "Your highest-value chip loses 1 every spin."},
	"capture_double": {"name": "Heavy Chips", "desc": "House chips count double when deciding who owns a square."},
}

# --- Events ----------------------------------------------------------------------
const EVENTS := {
	"loan_shark": {"name": "The Loan Shark", "desc": "A man in a nice suit offers %d coins, no questions. Word gets around: every later bank holds %d more." % [LOAN_SHARK_CASH, LOAN_SHARK_BANK_BONUS],
		"options": ["Take the money", "Walk away"]},
	"crooked_croupier": {"name": "A Crooked Croupier", "desc": "For 40 coins he'll 'adjust' your biggest chip: +3 value.",
		"options": ["Pay 40", "Walk away"]},
	"back_room": {"name": "Back-Room Game", "desc": "A fair coin flip for 40 coins.",
		"options": ["Flip for 40", "Walk away"]},
}


static func table_def(tier: int, dealer: String, boss: bool = false) -> Dictionary:
	if boss:
		return {"dealer": dealer, "bank": BOSS_BANK, "house_start": BOSS_HOUSE_START, "budget": BOSS_BUDGET, "spins": SHIFT_SPINS + 4, "boss": true}
	return {"dealer": dealer, "bank": BANK_BASE + BANK_STEP * tier, "house_start": HOUSE_START_BASE + HOUSE_START_STEP * tier,
		"budget": BUDGET_BASE + BUDGET_STEP * tier,
		"spins": SHIFT_SPINS, "boss": false}

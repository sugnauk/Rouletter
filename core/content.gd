extends RefCounted
## All content and balance numbers.
## Originality guard: every entry carries a `note` on why it is roulette-specific.
## Before adding an item, check it is not a reskin of a Balatro joker, enhancement or seal.
## `unlock`: Marker cost in the Pawn Shop (0 = available from the first run).

# --- Run structure ------------------------------------------------------------------
const NIGHTS := 4
const TABLE_NAMES := ["Floor", "High Roller", "Enforcer"]
const TABLE_NAMES_ACT2 := ["Private Room", "Velvet Room", "Enforcer"]
const ACT2_NIGHTS := 8                  ## Act II runs go on upstairs for nights 5-8
## Take target of each night's first table (nights 5-8 are Act II only).
const NIGHT_BASE := [8, 20, 45, 80, 120, 170, 230, 300]
const TABLE_MULT := [1.0, 1.4, 1.8]      ## Floor / High Roller / Enforcer
const SPINS := 6
const START_STACK := 25                 ## betting chips handed out at each table
const START_CASH := 4
const CLEAR_CASH := [3, 4, 6]            ## base cash for clearing each table type
const CASH_PER_SPIN_LEFT := 1
const COMPS_PER := 5                     ## +$1 per $5 held when a table clears...
const COMPS_MAX := 5                     ## ...up to $5
const RELIC_SLOTS := 5
const REROLL_BASE := 2
const STACK_UPGRADE := 5                 ## +betting chips per stack upgrade
const STACK_UPGRADE_PRICE := 5
const RELOCATE_PRICE := 2
const SELL_SHARE := 0.5

# --- Vendors (windows in the Cage) ---------------------------------------------------------
## Each vendor sells different things and takes a different currency:
##   "cash"  - dollars, as usual
##   "stack" - betting chips docked from your stack at the next table
const VENDORS := {
	"cashier": {"name": "Cashier", "currency": "cash", "unlock": 0,
		"blurb": "Chips and felt work. Cash only, fair prices.", "desc": "Chips and felt work for cash.",
		"note": "The casino cage: the one window that deals in money."},
	"pit_boss": {"name": "Pit Boss", "currency": "stack", "unlock": 0,
		"blurb": "Sells House Rules for chips off your next stack. Every rule you own raises his price.", "desc": "House Rules, paid in chips off your next stack.",
		"note": "The pit boss sets table rules and is paid in chips, not cash."},
	"loan_shark": {"name": "Loan Shark", "currency": "loan", "unlock": 0,
		"blurb": "Cash now. You pay him back by making the next payment bigger.", "desc": "Loans: cash now, a bigger payment at the next table.",
		"note": "Casino markers are loans; this one is collected at the table."},
	"dealer": {"name": "Dealer", "currency": "take", "unlock": 0,
		"blurb": "Trades favours for spare Take: whatever you scored past the payment.", "desc": "Favours and vouchers, paid in spare Take.",
		"note": "Croupiers trade in tokes and favours; here the currency is your surplus."},
	"fence": {"name": "Fence", "currency": "cash", "unlock": 2,
		"blurb": "Chips at half price. They fell off a truck, and every one has a flaw.", "desc": "A Cage window selling chips at half price. Every one is cracked, hot or sticky.",
		"note": "Stolen or doctored chips: cheap, but never quite right."},
}
## Loans the Loan Shark offers: cash now, the next table's payment grows by `pct`.
## The Dealer is paid in spare Take: what you scored past each payment. Prices scale with the
## night (x this night's first target / Night 1's).
const FAVOURS := {
	"extra_spin": {"name": "Extra Spin", "icon": "respin", "price": 4,
		"desc": "+1 spin at the next table."},
	"fat_stack": {"name": "Fat Stack", "icon": "stack", "price": 3,
		"desc": "+8 betting chips at the next table."},
	"head_start": {"name": "Head Start", "icon": "momentum", "price": 6,
		"desc": "The next table starts with 20% of its payment already on the meter."},
}
const VOUCHERS := {
	"comp_card": {"name": "Comp Card", "icon": "cash", "price": 10,
		"desc": "For the rest of the run: +$2 every time you clear a table."},
	"vip_rack": {"name": "VIP Rack", "icon": "call_bets", "price": 12,
		"desc": "For the rest of the run: +1 House Rule slot."},
	"patience": {"name": "Patience", "icon": "spin", "price": 16,
		"desc": "For the rest of the run: +1 spin at every table."},
	"house_credit": {"name": "House Credit", "icon": "loan", "price": 12,
		"desc": "For the rest of the run: cash prices in the Cage are $1 cheaper (never below $1)."},
}
const FAT_STACK := 8
const HEAD_START := 0.2
const COMP_CARD_CASH := 2
const ENDLESS_GROWTH := 1.3               ## endless mode: each night past 8 asks this much more
const LOANS := [{"cash": 5, "pct": 0.15}, {"cash": 10, "pct": 0.35}]
## Flaws on the Fence's chips (`short` is the badge on the token).
const FLAWS := {
	"cracked": {"name": "Cracked", "short": "CRK", "desc": "Scores half."},
	"hot": {"name": "Hot", "short": "HOT", "desc": "Confiscated the first time a zero hits."},
	"sticky": {"name": "Sticky", "short": "STK", "desc": "Can't be moved or sold once placed."},
}
const FENCE_SHARE := 0.5
const ALWAYS_VENDOR := "cashier"
const VENDORS_PER_VISIT := 2              ## windows open at each Cage visit: the Cashier plus one who rotates
const PIT_BOSS_STEP := 2                  ## +chips per House Rule already owned
const MIN_STACK := 10                     ## the Pit Boss never leaves you fewer betting chips than this

# --- Effect numbers -------------------------------------------------------------------
const LINK_SHARE := 0.25
const RED_STREAK_STEP := 0.10
const RENT_CONTROL_CUT := 0.10
const WILDCARD_BONUS := 6.0
const HOT_HAND_MULT := 3.0
const SIGNATURE_RANGE := 3
const SIGNATURE_BONUS := 0.5
const ZERO_TAX := 0.10
const BRIDGE_PER_NUMBER := 1.0            ## Bridge: +Take per number its bet covers
const KINGMAKER_MULT := 1.5               ## Kingmaker: the spin's Take x1.5 when it hits
const MOMENTUM_STEP := 0.25               ## Momentum: +25% per scoring spin in a row

# --- Meta ------------------------------------------------------------------------------
## Every run is one marker owed to Mr. Vance; each table cleared pays its share (weighted by
## that table's payment). Clearing the last night pays it in full.
const MARKER_ACT1 := 1000000
const MARKER_ACT2 := 5000000             ## Act II (and endless) runs carry the Floor Above's marker
const MARKERS_PER_NIGHT := 1
const MARKERS_VICTORY := 3

# --- Chips (permanent; bought in the shop, placed at a table) -------------------------
const CHIPS := {
	"perm": {"name": "Permanent", "desc": "Stays on the felt for the whole run. Pays its odds into your Take whenever it hits.",
		"price": 4, "unlock": 0, "any_bet": true,
		"note": "The core idea: a bet that is never collected."},
	"magnet": {"name": "Magnet", "desc": "If the ball lands one grid square away, it slides onto the winner.",
		"price": 6, "unlock": 0,
		"note": "Uses the physical 3xN felt layout only a roulette table has."},
	"compounding": {"name": "Compounding", "desc": "+1 value every spin.",
		"price": 6, "unlock": 0,
		"note": "'Let it ride' on a bet nobody ever collects."},
	"croupier": {"name": "Croupier", "desc": "When it hits, +1 Take for each betting chip that lost this spin.",
		"price": 5, "unlock": 0,
		"note": "The rake sweeping the losers off the layout, paid to you."},
	"wildcard_zero": {"name": "Wildcard Zero", "desc": "Sits on a zero. When any zero hits: outside bets push and +6 Take.",
		"price": 6, "unlock": 0, "zero_only": true,
		"note": "Targets the green pockets, the literal source of the house edge."},
	"mint": {"name": "Mint", "desc": "+$1 every spin, hit or miss.",
		"price": 5, "unlock": 0,
		"note": "A comp from the pit for staying at the table."},
	"respin": {"name": "Respin", "desc": "When it hits, +1 spin at this table.",
		"price": 6, "unlock": 0,
		"note": "Buys time against the payment clock."},
	"ledger": {"name": "Ledger", "desc": "When it hits, +1 value to your permanent chips on adjacent squares.",
		"price": 6, "unlock": 2,
		"note": "Growth spreads along felt neighbours, the same geometry splits and corners use."},
	"collector": {"name": "Collector", "desc": "When it hits, +1 Take per value of your other chips in its dozen or column.",
		"price": 6, "unlock": 2,
		"note": "Pays off roulette's own groupings when you crowd them."},
	"bridge": {"name": "Bridge", "desc": "Sits on a split, corner, street or line. When it hits, +1 Take per number it covers.",
		"price": 5, "unlock": 0, "line_only": true,
		"note": "Lives on the felt's lines, the inside bets only a roulette layout has."},
	"mirror": {"name": "Mirror", "desc": "Also scores when its mirror number hits (the one the same distance from the far end: 1 and 36, 2 and 35...).",
		"price": 6, "unlock": 0,
		"note": "Uses the numbering of the layout itself: every number has a twin at the other end."},
	"porch_light": {"name": "Porch Light", "desc": "When a wheel neighbour of its number hits, scores half.",
		"price": 6, "unlock": 0,
		"note": "Rewards the wheel's physical order, not the felt's: the 'neighbours' gamblers chase."},
	"kingmaker": {"name": "Kingmaker", "desc": "When it hits, the whole spin's Take is x1.5 (+0.5 per extra level).",
		"price": 7, "unlock": 0,
		"note": "A crowned number: one pocket that makes the whole spin."},
}
const SPECIAL_ON_STRAIGHT := ["magnet", "compounding", "croupier", "wildcard_zero", "mint", "respin", "ledger", "collector", "kingmaker", "mirror", "porch_light"]

## Rarity: how often something shows up in the Cage (common unless listed) and the frame it gets.
const RARITY := {
	"compounding": "rare", "wildcard_zero": "rare", "respin": "rare", "ledger": "rare", "collector": "rare",
	"mirror": "rare", "kingmaker": "legendary",
	"link": "rare", "double_felt": "rare", "pinned": "rare",
	"rent_control": "rare", "dealer_signature": "rare", "satin_gloves": "rare",
	"hot_hand": "legendary", "momentum": "legendary", "sevens": "rare",
}
const RARITY_WEIGHT := {"common": 6, "rare": 3, "legendary": 1}
const PORCH_SHARE := 0.5
const KING_STEP := 0.5                   ## Kingmaker: +0.5x per level past the first


static func rarity_of(id: String) -> String:
	return RARITY.get(id, "common")

# --- Felt upgrades -------------------------------------------------------------------
## target: "number" (any pocket) or "outside" (column/dozen)
const UPGRADES := {
	"gilded": {"name": "Gilded Number", "desc": "Straight bets here pay +1/7 more (35:1 becomes 40:1).", "target": "number",
		"price": 6, "unlock": 0, "note": "Rewrites a printed payout on the felt."},
	"hot": {"name": "Hot Column/Dozen", "desc": "+1x payout on this column or dozen.", "target": "outside",
		"price": 6, "unlock": 0, "note": "Turns a 2:1 outside box into 3:1."},
	"link": {"name": "Neighbour Link", "desc": "When this number hits, your chips on adjacent squares pay 25% of a straight.", "target": "number",
		"price": 6, "unlock": 0, "note": "A 'neighbours' call bet made physical on the layout."},
	"double_felt": {"name": "Double Felt", "desc": "Chips on this number score double.", "target": "number",
		"price": 7, "unlock": 0, "note": "Thick felt for a favourite number."},
	"pinned": {"name": "Pinned Pocket", "desc": "When this number hits, call bets (Voisins/Tiers/Orphelins) score double.", "target": "number",
		"price": 6, "unlock": 2, "note": "Ties the felt to the wheel: a pocket that anchors its sector."},
	"cornerstone": {"name": "Cornerstone", "desc": "When this number hits, your split, corner, street and line bets on it score double.", "target": "number",
		"price": 6, "unlock": 0, "note": "Rewards building inside bets around one square of the grid."},
}

# --- House Rules (relics) ---------------------------------------------------------------
const HOUSE_RULES := {
	"la_partage": {"name": "La Partage", "desc": "On a zero, losing even-money bets return half to your stack.",
		"price": 6, "unlock": 0, "note": "A real French-table rule."},
	"red_streak": {"name": "Red Streak", "desc": "Each consecutive red adds +10% to that spin's Take.",
		"price": 7, "unlock": 0, "note": "Plays on the gambler's belief in streaks; the odds stay fair."},
	"rent_control": {"name": "Rent Control", "desc": "Every payment due is 10% smaller.",
		"price": 8, "unlock": 0, "note": "Haggling with the Owner over the vig."},
	"thirteen": {"name": "Thirteen", "desc": "13 is cursed and pays nothing; its grid neighbours score double.",
		"price": 6, "unlock": 0, "note": "Superstition around a specific number on the layout."},
	"en_prison": {"name": "En Prison", "desc": "On a zero, losing even-money bets stay on the felt for the next spin.",
		"price": 6, "unlock": 2, "note": "A real French-table rule: the bet is 'imprisoned'."},
	"hot_hand": {"name": "Hot Hand", "desc": "If the ball repeats the last number, that spin's Take is tripled.",
		"price": 8, "unlock": 3, "note": "Every roulette player has seen a number hit twice."},
	"dealer_signature": {"name": "Dealer's Signature", "desc": "Hits within 3 wheel pockets of the last ball score +50%.",
		"price": 7, "unlock": 3, "note": "The myth that a croupier's throw lands in the same sector."},
	"split_decision": {"name": "Split Decision", "desc": "Split, street, corner and line bets pay +1x.",
		"price": 6, "unlock": 0, "note": "Rewrites the printed odds of the inside bets."},
	"sevens": {"name": "Lucky Sevens", "desc": "Straight-up hits on 7, 17 and 27 score double.",
		"price": 6, "unlock": 0, "note": "The oldest superstition on the floor, printed onto the felt."},
	"satin_gloves": {"name": "Satin Gloves", "desc": "Even-money bets (red/black, odd/even, high/low) pay 1.5 to 1.",
		"price": 7, "unlock": 0, "note": "The high-limit room's courtesy: better odds on the 'safe' bets."},
	"momentum": {"name": "Momentum", "desc": "Each scoring spin in a row adds +25% to the next one's Take. A blank spin resets it.",
		"price": 8, "unlock": 2, "note": "The gambler's 'hot table', paid out as a growing multiplier."},
}

# --- Unlockable table features --------------------------------------------------------------
const FEATURES := {
	"call_bets": {"name": "Call Bets", "desc": "Adds Voisins, Tiers and Orphelins to the felt: bets on arcs of the wheel.",
		"unlock": 2, "note": "Real French call bets; finally makes wheel order matter."},
}

# --- Enforcers (boss tables) -----------------------------------------------------------------
const ENFORCERS := {
	"accountant": {"name": "The Accountant", "rule": "no_outside",
		"desc": "Outside bets are off the books: they can't be placed and don't pay.",
		"intro": "Mr. Vance doesn't like round numbers. Inside bets only tonight.",
		"defeat": "...The ledger balances. For now."},
	"oro": {"name": "Madame Oro", "rule": "zero_tax",
		"desc": "Every zero costs you 10% of the Take you've built.",
		"intro": "Green is my favourite colour, darling. Every time it comes up, I take a cut.",
		"defeat": "Lucky. Luck doesn't last in this building."},
	"vic": {"name": "Vic \"The Rake\"", "rule": "frozen",
		"desc": "Your biggest permanent chip is frozen and pays nothing this table.",
		"intro": "Nice stack. Be a shame if it couldn't move.",
		"defeat": "Vance is gonna hear about this."},
	"sal": {"name": "Big Sal", "rule": "called",
		"desc": "Every 3rd spin is called: you can't place new bets on it.",
		"intro": "I call the spins at my table. You just watch.",
		"defeat": "Huh. Didn't call that one."},
	# Act II: the Floor Above (nights 5-7), then the Owner on night 8.
	"inspector": {"name": "The Inspector", "rule": "no_inside", "act": 2,
		"desc": "Inside bets are under review: no splits, streets, corners or lines, and those chips don't pay.",
		"intro": "Gaming commission. Routine check. Keep your chips in the middle of the squares, please.",
		"defeat": "Everything appears to be... in order. How irritating."},
	"velvet": {"name": "Velvet", "rule": "drain", "act": 2,
		"desc": "The room has a minimum: every spin costs 2 chips from your stack.",
		"intro": "Upstairs, darling, we don't count chips. We just watch them leave.",
		"defeat": "You kept some. How quaint."},
	"kline": {"name": "Mr. Kline", "rule": "short", "act": 2,
		"desc": "A short table: only 4 spins to make the payment.",
		"intro": "I'm a busy man. Four spins. Make them count or make them your last.",
		"defeat": "...Fine. Next."},
	"owner": {"name": "Mr. Vance", "rule": "owner", "act": 2, "final": true,
		"desc": "The Owner's table: every zero costs 10% of your Take, and every 3rd spin is called.",
		"intro": "My wheel. My felt. My rules. Sit down. You've earned the chair, if not the room.",
		"defeat": "...Well played. I'll have the marker drawn up in your favour. Don't spend it all downstairs."},
}
## The Owner's table combines these Enforcer rules.
const OWNER_RULES := ["zero_tax", "called"]
const DRAIN_PER_SPIN := 2
const SHORT_SPINS := 4


static func targets_for(night: int) -> Array:
	var base: float = NIGHT_BASE[mini(night, NIGHT_BASE.size() - 1)]
	if night >= NIGHT_BASE.size():  # endless mode keeps climbing
		base *= pow(ENDLESS_GROWTH, night - NIGHT_BASE.size() + 1)
	var out := []
	for m in TABLE_MULT:
		out.append(int(round(base * m)))
	return out

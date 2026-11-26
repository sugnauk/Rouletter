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
const NIGHT_BASE := [9, 32, 105, 240, 330, 450, 600, 780]
const TABLE_MULT := [1.0, 1.4, 1.95]      ## Floor / High Roller / Enforcer
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
const CONVERT_PRICE := 3                ## Cashier trade-in: swap a placed chip for a related one
const EARLY_CLEAR_SPINS := 3            ## clear with this many balls left to pick a bonus
## Build directions for the opening pick (one chip or rule from each of three of these).
const DIRECTIONS := {"numbers": "Numbers", "outside": "Outside bets", "even": "Even money",
	"inside": "Inside bets", "zero": "Zeros", "multiplier": "Multipliers", "cash": "Cash"}
const SELL_SHARE := 0.5

# --- Vendors (windows in the Cage) ---------------------------------------------------------
## Each vendor sells different things and takes a different currency:
##   "cash"  - dollars, as usual
##   "stack" - betting chips docked from your stack at the next table
const VENDORS := {
	"cashier": {"job": "deepen your build", "name": "Cashier", "currency": "cash", "unlock": 0,
		"blurb": "Chips and felt work. Cash only, fair prices. Trades in a placed chip for a related one ($3).", "desc": "Chips and felt work for cash.",
		"note": "The casino cage: the one window that deals in money."},
	"pit_boss": {"job": "the rules", "name": "Pit Boss", "currency": "stack", "unlock": 0,
		"blurb": "Sells House Rules for chips off your next stack. Every rule you own raises his price.", "desc": "House Rules, paid in chips off your next stack.",
		"note": "The pit boss sets table rules and is paid in chips, not cash."},
	"loan_shark": {"job": "patch the next table", "name": "Loan Shark", "currency": "loan", "unlock": 0,
		"blurb": "Cash now. You pay him back by making the next payment bigger.", "desc": "Loans: cash now, a bigger payment at the next table.",
		"note": "Casino markers are loans; this one is collected at the table."},
	"dealer": {"job": "invest in the run", "name": "Dealer", "currency": "take", "unlock": 0,
		"blurb": "Trades favours for spare Take: whatever you scored past the payment.", "desc": "Favours and vouchers, paid in spare Take.",
		"note": "Croupiers trade in tokes and favours; here the currency is your surplus."},
	"fence": {"job": "cheap gambles", "name": "Fence", "currency": "cash", "unlock": 2,
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
## Marker grades: the difficulty ladder. Winning at a grade opens the next. Each grade keeps
## every twist of the grades below it.
const GRADES := [
	{"name": "House Marker", "desc": "The standard marker."},
	{"name": "Short Stack", "desc": "You start every table with 5 fewer betting chips."},
	{"name": "Tight Cage", "desc": "Everything sold for cash in the Cage costs $1 more."},
	{"name": "Heavy Payments", "desc": "Every payment is 10% bigger."},
	{"name": "Cracked Luck", "desc": "From night 2, each night one of your permanent chips cracks (scores half)."},
	{"name": "Fast Tables", "desc": "High Roller and Enforcer tables have one spin fewer."},
	{"name": "Mean Enforcers", "desc": "Enforcer tables ask 10% more."},
	{"name": "One Window", "desc": "Only the Cashier works the Cage."},
	{"name": "Vance's Own Marker", "desc": "Every payment is a further 10% bigger. Mr. Vance's personal paper."},
]
const MARKER_GRADE_STEP := 0.25          ## each grade adds 25% to the marker's face value

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
	"compounding": {"name": "Compounding", "desc": "+1 value every spin (per chip stacked).",
		"price": 6, "unlock": 0,
		"note": "'Let it ride' on a bet nobody ever collects."},
	"croupier": {"name": "Croupier", "desc": "When it hits, +1 Take for each betting chip that lost this spin.",
		"price": 5, "unlock": 0,
		"note": "The rake sweeping the losers off the layout, paid to you."},
	"wildcard_zero": {"name": "Wildcard Zero", "desc": "Sits on a zero. When any zero hits: outside bets push and +6 Take (per chip stacked).",
		"price": 6, "unlock": 0, "zero_only": true,
		"note": "Targets the green pockets, the literal source of the house edge."},
	"mint": {"name": "Mint", "desc": "+$1 every spin, hit or miss.",
		"price": 5, "unlock": 0,
		"note": "A comp from the pit for staying at the table."},
	"respin": {"name": "Respin", "desc": "When it hits, +1 spin at this table (per chip stacked).",
		"price": 6, "unlock": 0,
		"note": "Buys time against the payment clock."},
	"ledger": {"name": "Ledger", "desc": "When it hits, +1 value to your permanent chips on adjacent squares (per chip stacked).",
		"price": 6, "unlock": 2,
		"note": "Growth spreads along felt neighbours, the same geometry splits and corners use."},
	"collector": {"name": "Collector", "desc": "When it hits, +1 Take per value of your other chips in its dozen or column (per chip stacked).",
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
	"black_cat": {"name": "Black Cat", "desc": "Whenever any black number hits, +2 Take (per level).",
		"price": 5, "unlock": 0,
		"note": "Superstition turned upside down: the black numbers bring the luck."},
	"penny": {"name": "Lucky Penny", "desc": "When it hits, +$2 cash (per level).",
		"price": 4, "unlock": 0,
		"note": "A coin that pays the gambler, not the house."},
	"snowball": {"name": "Snowball", "desc": "When it hits, it grows 2 levels (per chip stacked).",
		"price": 6, "unlock": 0,
		"note": "'Let it ride', but only when it wins."},
	"street_light": {"name": "Street Light", "desc": "Whenever another number in its street (its row of three) hits, +3 Take (per level).",
		"price": 5, "unlock": 0,
		"note": "Lights up the three-number street a straight bet sits in."},
	"red_herring": {"name": "Red Herring", "desc": "Whenever any red number hits, +2 Take (per level).",
		"price": 5, "unlock": 0,
		"note": "The Black Cat's cousin, for the other colour."},
	"jar": {"name": "Jackpot Jar", "desc": "Grows a level every spin it misses. When it hits it pays, then empties back to one level per chip stacked.",
		"price": 6, "unlock": 0,
		"note": "Saving up for the one big night."},
	"hedge": {"name": "Hedge", "desc": "Sits on an even-money box (red, black, odd, even, high, low). Every spin it misses, +1 Take (per level).",
		"price": 5, "unlock": 0, "even_only": true,
		"note": "Pays you a little for being wrong: a hedge, built into the felt."},
	"wheel_spoke": {"name": "Wheel Spoke", "desc": "When the ball lands 1 or 2 pockets from its number on the wheel, +4 Take (per level).",
		"price": 6, "unlock": 2,
		"note": "Plays the wheel's order, the way a 'neighbours' bet does."},
	"echo": {"name": "Echo", "desc": "When it hits, every other permanent chip you own gains a level (per chip stacked).",
		"price": 9, "unlock": 3,
		"note": "One hit that ripples across the whole felt."},
	"ace": {"name": "Ace of Spades", "desc": "Sits on a black number only. When it hits, the spin's Take x2. Each chip stacked on it multiplies again; other levels add +0.5.",
		"price": 9, "unlock": 3, "black_only": true,
		"note": "The death card of the deck, dealt onto roulette's black squares."},
	"tip_jar": {"name": "Tip Jar", "desc": "+$1 for every betting chip that loses (up to $5 a spin, per level).",
		"price": 5, "unlock": 0,
		"note": "The croupier's tip box, emptied into your pocket."},
	"green_thumb": {"name": "Green Thumb", "desc": "Sits on a zero. Grows a level every time any zero hits (per chip stacked).",
		"price": 5, "unlock": 0, "zero_only": true,
		"note": "Grows on the green, the one colour the house owns."},
	"signpost": {"name": "Signpost", "desc": "Sits on a split, corner, street or line. When it hits, +$2 cash (per level).",
		"price": 5, "unlock": 0, "line_only": true,
		"note": "Marks a crossroads on the felt's lines, and charges a toll."},
	"sentinel": {"name": "Sentinel", "desc": "Sits on a zero. Whenever a zero hits, +8 Take (per level).",
		"price": 5, "unlock": 0, "zero_only": true,
		"note": "Guards the green pockets, where the house edge lives."},
	"crown": {"name": "Column Crown", "desc": "Sits on a column bet. When its column hits, the spin's Take x1.25. Each chip stacked on it multiplies again; other levels add +0.25.",
		"price": 7, "unlock": 2, "column_only": true,
		"note": "Turns one of the long 2:1 boxes into a multiplier."},
	"odd_fellow": {"name": "Odd Fellow", "desc": "Whenever an odd number hits, +2 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "odd", "take": 2.0},
		"note": "Plays the parity boxes from a single square."},
	"even_keel": {"name": "Even Keel", "desc": "Whenever an even number hits, +2 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "even", "take": 2.0},
		"note": "Steady as she goes, on every even ball."},
	"low_roller": {"name": "Low Roller", "desc": "Whenever a number from the low half hits (1-18 on a full wheel), +2 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "low", "take": 2.0},
		"note": "The cheap seats, paid out."},
	"penthouse": {"name": "Penthouse", "desc": "Whenever a number from the high half hits (19-36 on a full wheel), +2 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "high", "take": 2.0},
		"note": "Top floor, top half."},
	"dozen_watch": {"name": "Dozen Watch", "desc": "Whenever another number in its dozen hits, +2 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "dozen", "take": 2.0},
		"note": "Keeps an eye on its twelve neighbours."},
	"pillar": {"name": "Pillar", "desc": "Whenever another number in its column hits, +2 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "column", "take": 2.0},
		"note": "Holds up one of the felt's long columns."},
	"night_owl": {"name": "Night Owl", "desc": "+1 Take every spin, hit or miss (per level).",
		"price": 7, "unlock": 0, "trigger": {"on": "every", "take": 1.0},
		"note": "Always awake at the table."},
	"piggy_bank": {"name": "Piggy Bank", "desc": "+$1 every spin it misses (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "miss", "cash": 1},
		"note": "Saves a coin every time you lose."},
	"clover": {"name": "Four-Leaf Clover", "desc": "When the ball lands within 3 pockets of its number on the wheel, +2 Take (per level).",
		"price": 6, "unlock": 0, "trigger": {"on": "wheel", "arg": 3, "take": 2.0},
		"note": "Luck spread wide around one pocket of the wheel."},
	"doorbell": {"name": "Doorbell", "desc": "When a grid neighbour of its number hits, +3 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "grid", "take": 3.0},
		"note": "Rings when the ball lands next door on the felt."},
	"prime_time": {"name": "Prime Time", "desc": "Whenever a prime number hits (2, 3, 5, 7, 11...), +3 Take (per level).",
		"price": 6, "unlock": 2, "trigger": {"on": "set", "arg": [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31], "take": 3.0},
		"note": "Mathematics on the felt."},
	"square_deal": {"name": "Square Deal", "desc": "Whenever a perfect square hits (1, 4, 9, 16, 25, 36), +5 Take (per level).",
		"price": 6, "unlock": 2, "trigger": {"on": "set", "arg": [1, 4, 9, 16, 25, 36], "take": 5.0},
		"note": "A fair deal, squared."},
	"teen_idol": {"name": "Teen Idol", "desc": "Whenever 13 to 19 hits, +3 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "set", "arg": [13, 14, 15, 16, 17, 18, 19], "take": 3.0},
		"note": "Seven teenage numbers in a row on the felt."},
	"fibonacci": {"name": "Fibonacci", "desc": "Whenever 1, 2, 3, 5, 8, 13, 21 or 34 hits, +4 Take (per level).",
		"price": 6, "unlock": 2, "trigger": {"on": "set", "arg": [1, 2, 3, 5, 8, 13, 21, 34], "take": 4.0},
		"note": "The sequence every system-better swears by."},
	"nickel": {"name": "Nickel", "desc": "Whenever a number ending in 5 or 0 hits, +3 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "set", "arg": [5, 10, 15, 20, 25, 30, 35], "take": 3.0},
		"note": "Pays on the round-ish numbers."},
	"seventh_heaven": {"name": "Seventh Heaven", "desc": "Whenever a number containing a 7 hits, +4 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "set", "arg": [7, 17, 27], "take": 4.0},
		"note": "For the gambler's favourite digit."},
	"last_digit": {"name": "Last Digit", "desc": "Whenever a number ending in the same digit as its own hits, +4 Take (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "digit", "take": 4.0},
		"note": "Matches the last digit, a classic 'finals' bet."},
	"far_side": {"name": "Far Side", "desc": "When the ball lands directly across the wheel from its number (the farthest pockets), +10 Take (per level).",
		"price": 6, "unlock": 2, "trigger": {"on": "opposite", "take": 10.0},
		"note": "Bets on the pocket opposite on the wheel, the farthest one."},
	"seedling": {"name": "Seedling", "desc": "Grows a level every spin it misses, up to level 5 (per chip stacked).",
		"price": 5, "unlock": 0, "trigger": {"on": "miss", "grow": 1, "cap": 5},
		"note": "Plant it early; it pays later."},
	"golden_goose": {"name": "Golden Goose", "desc": "When it hits, +$5 cash (per level).",
		"price": 7, "unlock": 0, "trigger": {"on": "hit", "cash": 5},
		"note": "Lays a golden egg each time."},
	"heart_of_gold": {"name": "Heart of Gold", "desc": "When it hits, +10 Take (per level) on top of its payout.",
		"price": 7, "unlock": 0, "trigger": {"on": "hit", "take": 10.0},
		"note": "A generous chip with a big bonus."},
	"spare_key": {"name": "Spare Key", "desc": "Whenever a zero hits, +$4 cash (per level).",
		"price": 5, "unlock": 0, "trigger": {"on": "zero", "cash": 4},
		"note": "For the night the green comes up."},
	"conductor": {"name": "Conductor", "desc": "When it hits, every multiplier chip you own (Kingmaker, Ace, Crown) fires too, wherever it sits.",
		"price": 9, "unlock": 0, "note": "Strikes up the whole band at once."},
	"relay": {"name": "Relay", "desc": "When it hits, every other permanent chip on a number scores half its straight-up pay too.",
		"price": 8, "unlock": 0, "note": "Passes the win down the line."},
	"fuse": {"name": "Fuse", "desc": "Each spin, +2 Take for every level your other chips gained that spin (per level of Fuse).",
		"price": 7, "unlock": 0, "note": "Growth chips light it; it turns growing into scoring."},
	"kingmaker": {"name": "Kingmaker", "desc": "When it hits, the whole spin's Take is x1.5. Each chip stacked on it multiplies again; other levels add +0.5.",
		"price": 7, "unlock": 0,
		"note": "A crowned number: one pocket that makes the whole spin."},
}
const SPECIAL_ON_STRAIGHT := ["magnet", "compounding", "croupier", "wildcard_zero", "mint", "respin", "ledger", "collector", "kingmaker", "mirror", "porch_light"]

## Rarity: how often something shows up in the Cage (common unless listed) and the frame it gets.
const RARITY := {
	"sals_whistle": "legendary", "oros_coin": "legendary", "accountants_book": "legendary", "velvet_rope": "legendary", "klines_watch": "legendary",
	"conductor": "legendary", "relay": "rare", "fuse": "rare", "crowd_pleaser": "rare", "purist": "rare",
	"compounding": "rare", "wildcard_zero": "rare", "respin": "rare", "ledger": "rare", "collector": "rare",
	"night_owl": "rare", "far_side": "rare", "heart_of_gold": "rare", "golden_goose": "rare", "square_deal": "rare",
	"zero_tolerance": "rare", "double_down": "rare", "patron": "rare", "late_bloomer": "rare", "veterans": "legendary",
	"jar": "rare", "wheel_spoke": "rare", "echo": "legendary", "ace": "legendary", "green_thumb": "rare",
	"diamond": "rare", "magnetized": "rare", "twin_square": "rare", "spoke": "rare", "repeat_box": "rare", "lucky_colour": "rare",
	"mirror": "rare", "kingmaker": "legendary", "snowball": "rare", "crown": "legendary", "sentinel": "rare",
	"sweet_spot": "rare", "silk": "rare", "last_call": "rare", "insurance": "rare", "high_society": "rare",
	"link": "rare", "double_felt": "rare", "pinned": "rare",
	"rent_control": "rare", "dealer_signature": "rare", "satin_gloves": "rare",
	"hot_hand": "legendary", "momentum": "legendary", "sevens": "rare",
}
const RARITY_WEIGHT := {"common": 6, "rare": 3, "legendary": 1}
const PORCH_SHARE := 0.5
const BLACK_CAT_BONUS := 2.0
const RAINY_DAY_CASH := 2
const CROWD_STEP := 0.05
const SKIM_CUT := 0.15
const OROS_COIN_TAKE := 10.0
const VELVET_ROPE_CHIPS := 2
const HIGH_STAKES_CHIPS := 15
const RELAY_SHARE := 0.5
const FUSE_BONUS := 2.0
## Refine: a second act for a levelled-up number chip (one path per chip, at the Cashier).
const REFINE_PRICE := 6
const REFINE_LEVEL := 2
const STEADY_BONUS := 1.0
const REFINES := {
	"focused": {"name": "Focused", "desc": "When its own number hits, it scores double."},
	"steady": {"name": "Steady", "desc": "Every spin its number misses, +1 Take per level."},
}
const INSIDE_TRACK_CAP := 5
const PENNY_CASH := 2
const SENTINEL_BONUS := 8.0
const CROWN_MULT := 1.25
const LAMP_CASH := 3
const STREET_LIGHT_BONUS := 3.0
const RED_HERRING_BONUS := 2.0
const HEDGE_BONUS := 1.0
const SPOKE_CHIP_BONUS := 4.0
const TIP_JAR_CAP := 5
const SIGNPOST_CASH := 2
const EVEN_KEYS := ["RED", "BLACK", "ODD", "EVEN", "LOW", "HIGH"]
const COMPED_CASH := 3
const KING_STEP := 0.5                   ## Kingmaker: +0.5x per level past the first


## Build families, for "works with your ..." hints in the Cage.
const TAGS := {
	"perm": ["numbers"], "magnet": ["numbers"], "mirror": ["numbers"], "kingmaker": ["numbers", "multiplier"],
	"gilded": ["numbers"], "double_felt": ["numbers"], "link": ["numbers", "neighbours"], "thirteen": ["numbers"],
	"sevens": ["numbers"], "ledger": ["numbers", "neighbours"], "collector": ["numbers"], "compounding": ["numbers"],
	"bridge": ["inside"], "cornerstone": ["inside"], "split_decision": ["inside"],
	"satin_gloves": ["even"], "la_partage": ["even", "zero"], "en_prison": ["even", "zero"], "red_streak": ["even", "multiplier"],
	"hot": ["outside"], "porch_light": ["neighbours", "wheel"], "dealer_signature": ["wheel", "multiplier"],
	"odd_fellow": ["numbers"], "even_keel": ["numbers"], "low_roller": ["numbers"], "penthouse": ["numbers"],
	"dozen_watch": ["numbers"], "pillar": ["numbers", "outside"], "night_owl": ["numbers"], "piggy_bank": ["cash"],
	"clover": ["wheel", "neighbours"], "doorbell": ["neighbours"], "prime_time": ["numbers"], "square_deal": ["numbers"],
	"teen_idol": ["numbers"], "fibonacci": ["numbers"], "nickel": ["numbers"], "seventh_heaven": ["numbers"],
	"last_digit": ["numbers"], "far_side": ["wheel"], "seedling": ["numbers"], "golden_goose": ["cash"],
	"heart_of_gold": ["numbers"], "spare_key": ["zero", "cash"],
	"zero_tolerance": ["zero", "even"], "bankroll": ["easy"], "compound_interest": ["cash"], "double_down": ["multiplier"],
	"corner_office": ["inside"], "big_spender": ["cash"], "patron": ["spins"], "late_bloomer": ["multiplier", "spins"],
	"veterans": ["numbers", "multiplier"],
	"pinned": ["wheel"], "wildcard_zero": ["zero"], "momentum": ["multiplier"], "hot_hand": ["multiplier"],
	"croupier": ["numbers"], "mint": ["cash"], "respin": ["spins"], "rent_control": ["easy"],
	"black_cat": ["numbers"], "penny": ["cash", "numbers"], "snowball": ["numbers"], "sentinel": ["zero"],
	"crown": ["outside", "multiplier"], "lamp": ["cash", "numbers"], "silk": ["outside"], "sweet_spot": ["numbers", "inside"],
	"last_call": ["multiplier"], "comped": ["cash"], "insurance": ["even", "outside"], "high_society": ["outside"],
	"black_tie": ["numbers"],
	"street_light": ["numbers"], "red_herring": ["numbers"], "jar": ["numbers"], "hedge": ["even"],
	"wheel_spoke": ["wheel", "neighbours"], "echo": ["numbers", "multiplier"], "ace": ["numbers", "multiplier"],
	"tip_jar": ["cash"], "green_thumb": ["zero"], "signpost": ["inside", "cash"],
	"diamond": ["numbers"], "magnetized": ["numbers", "neighbours"], "twin_square": ["numbers"], "spoke": ["wheel", "neighbours"],
	"sals_whistle": ["multiplier"], "oros_coin": ["zero"], "accountants_book": ["outside", "cash"],
	"velvet_rope": ["spins"], "klines_watch": ["spins"],
	"crowd_pleaser": ["multiplier", "numbers"], "purist": ["multiplier", "numbers"], "high_stakes": ["multiplier"],
	"conductor": ["multiplier"], "relay": ["numbers"], "fuse": ["numbers", "multiplier"],
	"outside_connection": ["outside", "numbers"], "inside_track": ["inside", "numbers"],
	"colour_coded": ["even", "numbers"], "rainy_day": ["cash", "even"],
	"gold_trim": ["outside", "cash"], "fat_box": ["outside"], "repeat_box": ["outside", "multiplier"], "lucky_colour": ["even"],
}
const TAG_NAMES := {"numbers": "single numbers", "inside": "inside bets", "even": "even-money bets", "outside": "outside bets",
	"neighbours": "neighbouring numbers", "wheel": "the wheel's order", "zero": "zeros", "multiplier": "multipliers"}
## How each Enforcer rule meets your purchases: tags that help or are useless against it.
const COUNTERS := {
	"no_outside": {"good": ["numbers", "inside"], "bad": ["outside", "even"]},
	"zero_tax": {"good": ["zero"], "bad": []},
	"frozen": {"good": ["numbers", "inside"], "bad": []},
	"called": {"good": ["numbers", "inside", "multiplier"], "bad": []},
	"no_inside": {"good": ["numbers", "outside", "even"], "bad": ["inside"]},
	"drain": {"good": ["multiplier"], "bad": []},
	"short": {"good": ["spins", "multiplier"], "bad": []},
	"no_rules": {"good": ["numbers", "inside"], "bad": ["even", "multiplier"]},
	"skim": {"good": ["multiplier", "numbers"], "bad": []},
	"cold_red": {"good": ["even", "outside"], "bad": []},
	"crowd": {"good": ["outside", "inside", "even"], "bad": []},
	"tempo": {"good": ["even", "outside"], "bad": []},
	"clock": {"good": ["multiplier", "numbers"], "bad": ["spins"]},
	"no_repeat": {"good": ["wheel", "neighbours", "numbers"], "bad": []},
}

## Table conditions: a twist on ordinary tables from night 2 on, each with visible counterplay.
const CONDITIONS := {
	"regions": {"name": "Spread Out", "desc": "Spins where your bets cover all three dozens score +25%."},
	"scarce": {"name": "Tight Felt", "desc": "At most 6 bet spots at once."},
	"early": {"name": "Early Bird", "desc": "Clear by the 3rd ball: +$2."},
	"short_stack": {"name": "Thin Stack", "desc": "4 fewer betting chips, but +$2 when you clear."},
}
const REGIONS_MULT := 1.25
const SCARCE_SPOTS := 6
const CROWD_PILE := 5
const TEMPO_CUT := 0.1
const CLOCK_STEP := 0.05
## Side objectives: one optional job per table, paid on the clear.
const OBJECTIVES := {
	"outside_only": {"name": "Clean Hands", "desc": "Clear using only outside bets.", "cash": 2},
	"straight": {"name": "Bullseye", "desc": "Win a straight-up bet.", "cash": 2},
	"three_hits": {"name": "Hat Trick", "desc": "Score on 3 different spins.", "cash": 2},
	"few": {"name": "Light Touch", "desc": "Never bet on more than 3 spots in a spin.", "cash": 2},
}
## Route choice before the High Roller table each night.
const ROUTES := {
	"back_room": {"name": "The Back Room", "desc": "4 balls, payment x0.8. +$1 when you clear.", "spins": 4, "target": 0.8, "cash": 1},
	"long_table": {"name": "The Long Table", "desc": "8 balls, payment x1.2, Tight Felt (6 spots). +$2 when you clear.", "spins": 8, "target": 1.2, "cash": 2, "condition": "scarce"},
}
## Between-table events: someone in the Cage offers a choice.
const EVENTS := {
	"dolores_tip": {"who": "Dolores", "text": "Psst. The Enforcer's table is next. I can get you an extra ball, or slip you a couple of bucks.",
		"options": [["An extra ball", "+1 ball at the next table."], ["$2", "+$2 now."]]},
	"lou_bet": {"who": "Lucky Lou", "text": "Side bet, pal: $3 says you can't clear the next one with 2 balls to spare. You do, I pay $9.",
		"options": [["Take the bet", "Pay $3. Clear the next table with 2+ balls left: +$9."], ["Pass", "Keep your money."]]},
	"fence_hot": {"who": "Fence", "text": "Free chip. Don't ask where it's been. Don't let it near a zero, either.",
		"options": [["Take it", "A random chip, free, but HOT: lost the first time a zero hits."], ["Pass", "Leave it."]]},
}
const EVENT_CHANCE := 0.6
const CASHIER_CHIPS := 3                ## chips on the Cashier's counter each visit
const PERM_CHANCE := 0.15               ## chance a shop chip slot is a plain Permanent

## Named challenges: handcrafted runs with their own Feat (Act I, base marker).
const CHALLENGES := {
	"no_outside": {"name": "No Outside Bets", "wheel": "european",
		"desc": "The outside boxes are closed all run. Numbers, splits and streets only."},
	"fence_run": {"name": "The Fence's Run", "wheel": "european",
		"desc": "Only the Fence works the Cage. You start with a Magnet, a Permanent and +$10."},
	"gauntlet": {"name": "Enforcer Gauntlet", "wheel": "french",
		"desc": "Every table is an Enforcer table."},
	"shoestring": {"name": "Shoestring", "wheel": "european",
		"desc": "A 12-chip stack, and no Pit Boss or Loan Shark to lean on."},
}
const SHOESTRING_STACK := 12
const FENCE_RUN_CASH := 10
## Alternative starting kits, bought at the Pawn Shop and picked on the wheel screen.
const STARTERS := {
	"banker_kit": {"name": "Banker's Kit", "unlock": 4, "kit": [], "cash": 8,
		"desc": "Start with no chips, but +$8."},
	"collector_kit": {"name": "Collector's Kit", "unlock": 5, "random": 3, "cash": 0,
		"desc": "Start with three random common chips instead of the wheel's kit."},
	"high_roller_kit": {"name": "High Roller's Kit", "unlock": 6, "kit": [{"kind": "kingmaker", "value": 1}], "cash": 0,
		"desc": "Start with a Kingmaker instead of the wheel's kit."},
}
const LOU_STAKE := 3
const LOU_PAYOUT := 9


## The Almanac's categories: [title, source table name, ids]. Every item appears exactly once.
const ALMANAC := [
	["SCORING CHIPS", "CHIPS", ["perm", "magnet", "mirror", "porch_light", "black_cat", "red_herring", "street_light", "wheel_spoke", "hedge", "croupier", "collector", "ledger"]],
	["GROWTH CHIPS", "CHIPS", ["compounding", "snowball", "jar", "seedling", "echo"]],
	["MODIFIER CHIPS", "CHIPS", ["kingmaker", "ace", "crown", "bridge"]],
	["CHAIN CHIPS", "CHIPS", ["conductor", "relay", "fuse"]],
	["ZERO CHIPS", "CHIPS", ["wildcard_zero", "sentinel", "green_thumb"]],
	["PATTERN CHIPS", "CHIPS", ["odd_fellow", "even_keel", "low_roller", "penthouse", "prime_time", "square_deal", "teen_idol", "fibonacci", "nickel", "seventh_heaven", "last_digit"]],
	["WATCH CHIPS", "CHIPS", ["dozen_watch", "pillar", "doorbell", "clover", "far_side", "night_owl", "heart_of_gold"]],
	["CASH & TIME CHIPS", "CHIPS", ["mint", "penny", "tip_jar", "signpost", "piggy_bank", "golden_goose", "spare_key", "respin"]],
	["NUMBER UPGRADES", "UPGRADES", ["gilded", "double_felt", "diamond", "magnetized", "twin_square", "link", "spoke", "sweet_spot", "lamp", "cornerstone", "pinned"]],
	["OUTSIDE UPGRADES", "UPGRADES", ["hot", "silk", "gold_trim", "fat_box", "repeat_box", "lucky_colour"]],
	["PAYOUT RULES", "HOUSE_RULES", ["split_decision", "corner_office", "sevens", "satin_gloves", "high_society", "black_tie", "thirteen", "veterans"]],
	["MULTIPLIER RULES", "HOUSE_RULES", ["red_streak", "hot_hand", "dealer_signature", "momentum", "last_call", "double_down", "late_bloomer"]],
	["SAFETY RULES", "HOUSE_RULES", ["la_partage", "en_prison", "insurance", "zero_tolerance", "rent_control", "patron", "bankroll"]],
	["MONEY RULES", "HOUSE_RULES", ["comped", "compound_interest", "big_spender"]],
	["BRIDGE RULES", "HOUSE_RULES", ["outside_connection", "inside_track", "colour_coded", "rainy_day"]],
	["SCALING RULES", "HOUSE_RULES", ["crowd_pleaser", "purist", "high_stakes"]],
	["TROPHIES", "HOUSE_RULES", ["sals_whistle", "oros_coin", "accountants_book", "velvet_rope", "klines_watch"]],
	["DEALER FAVOURS", "FAVOURS", ["extra_spin", "fat_stack", "head_start"]],
	["DEALER VOUCHERS", "VOUCHERS", ["comp_card", "vip_rack", "patience", "house_credit"]],
]


static func almanac_table(name: String) -> Dictionary:
	match name:
		"CHIPS":
			return CHIPS
		"UPGRADES":
			return UPGRADES
		"HOUSE_RULES":
			return HOUSE_RULES
		"FAVOURS":
			return FAVOURS
	return VOUCHERS


static func tags_of(id: String) -> Array:
	return TAGS.get(id, [])


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
	"diamond": {"name": "Diamond Square", "desc": "When this number hits, your permanent chips on it gain a level.", "target": "number",
		"price": 7, "unlock": 0, "note": "A square that polishes whatever sits on it."},
	"magnetized": {"name": "Magnetized Square", "desc": "Your chips on this number also score half when a grid neighbour hits.", "target": "number",
		"price": 6, "unlock": 0, "note": "A Magnet built into the felt itself."},
	"twin_square": {"name": "Twin Square", "desc": "Your chips on this number also score when its mirror number hits (1 and 36, 2 and 35...).", "target": "number",
		"price": 6, "unlock": 0, "note": "Stitches a square to its twin at the far end of the layout."},
	"spoke": {"name": "Spoke Square", "desc": "When this number hits, your chips on its two wheel neighbours score half.", "target": "number",
		"price": 6, "unlock": 2, "note": "Ties a square of the felt to its neighbours on the wheel."},
	"gold_trim": {"name": "Gold Trim", "desc": "This column or dozen pays +0.5x and +$1 cash when it hits.", "target": "outside",
		"price": 6, "unlock": 0, "note": "Gilt edging for one of the long boxes."},
	"fat_box": {"name": "Fat Box", "desc": "Winning chips on this column or dozen score +2 Take each.", "target": "outside",
		"price": 5, "unlock": 0, "note": "A bigger box pays bigger, chip by chip."},
	"repeat_box": {"name": "Repeat Box", "desc": "Bets on this column or dozen score double if the last ball also landed in it.", "target": "outside",
		"price": 7, "unlock": 2, "note": "Rewards the streaks gamblers swear by."},
	"lucky_colour": {"name": "Lucky Colour", "desc": "This even-money box (red, black, odd, even, high or low) pays 2 to 1.", "target": "even",
		"price": 7, "unlock": 0, "note": "One 'safe' box that pays like a column."},
	"lamp": {"name": "Lucky Lamp", "desc": "When this number hits, +$3 cash.", "target": "number",
		"price": 5, "unlock": 0, "note": "A lamp over one square of the felt that pays the player."},
	"silk": {"name": "Silk Box", "desc": "Losing bets on this column or dozen go back to your stack instead of costing Take.", "target": "outside",
		"price": 6, "unlock": 0, "note": "A safety net woven into one outside box."},
	"sweet_spot": {"name": "Sweet Spot", "desc": "When this number hits, every bet covering it scores x1.5.", "target": "number",
		"price": 7, "unlock": 2, "note": "One square where every kind of bet pays better."},
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
	"last_call": {"name": "Last Call", "desc": "The last spin at every table scores double.",
		"price": 7, "unlock": 0, "note": "The bar's closing: everyone bets bigger on the final ball."},
	"comped": {"name": "Comped Drinks", "desc": "+$3 every time you clear a table.",
		"price": 5, "unlock": 0, "note": "The house keeps its regulars happy."},
	"insurance": {"name": "Insurance", "desc": "Your biggest losing bet each spin doesn't count against your Take.",
		"price": 7, "unlock": 0, "note": "Named for the real side bet that protects a hand."},
	"high_society": {"name": "High Society", "desc": "Column and dozen bets pay +1x.",
		"price": 7, "unlock": 2, "note": "The high-limit room's better odds on the long boxes."},
	"black_tie": {"name": "Black Tie", "desc": "Straight-up hits on black numbers score x1.5.",
		"price": 6, "unlock": 0, "note": "A dress code for the felt: black is formal, and it pays."},
	"zero_tolerance": {"name": "Zero Tolerance", "desc": "When a zero hits, your losing bets go back to your stack instead of costing Take.",
		"price": 7, "unlock": 2, "note": "A house that forgives the green pocket."},
	"bankroll": {"name": "Bankroll", "desc": "+1 betting chip back to your stack every spin.",
		"price": 6, "unlock": 0, "note": "The house tops up your rack."},
	"compound_interest": {"name": "Compound Interest", "desc": "When you clear a table, +$1 for every $10 you're holding.",
		"price": 6, "unlock": 0, "note": "Your cash earns interest in the Cage."},
	"double_down": {"name": "Double Down", "desc": "The first spin at every table scores double.",
		"price": 7, "unlock": 0, "note": "Come out swinging."},
	"corner_office": {"name": "Corner Office", "desc": "Corner bets pay +2x.",
		"price": 6, "unlock": 0, "note": "The best seat on the felt is a corner."},
	"big_spender": {"name": "Big Spender", "desc": "Any spin that scores 50 or more Take pays +$3.",
		"price": 5, "unlock": 0, "note": "Big nights get comped."},
	"patron": {"name": "Patron", "desc": "Enforcer tables give you one extra spin.",
		"price": 8, "unlock": 2, "note": "Someone upstairs likes you."},
	"late_bloomer": {"name": "Late Bloomer", "desc": "From the 4th spin of a table on, every spin's Take x1.5.",
		"price": 7, "unlock": 2, "note": "The longer you sit, the better it gets."},
	"veterans": {"name": "Old Timers", "desc": "Permanent chips at level 3 or higher score x1.5.",
		"price": 8, "unlock": 2, "note": "Respect for the chips that have been around."},
	"momentum": {"name": "Momentum", "desc": "Each scoring spin in a row adds +25% to the next one's Take. A blank spin resets it.",
		"price": 8, "unlock": 2, "note": "The gambler's 'hot table', paid out as a growing multiplier."},
	# Bridges: one way of betting feeds another.
	"outside_connection": {"name": "Outside Connection", "desc": "When a dozen or column bet wins, +1 Take per level of every permanent chip on a number inside it.",
		"price": 6, "unlock": 0, "note": "Bridges outside bets and number chips."},
	"inside_track": {"name": "Inside Track", "desc": "When a split, street, corner or line bet wins, the permanent chip on the winning number gains a level (up to 5).",
		"price": 7, "unlock": 0, "note": "Bridges inside bets and number chips."},
	"colour_coded": {"name": "Colour Coded", "desc": "When red or black wins, +1 Take per level of every permanent chip on a number of that colour.",
		"price": 6, "unlock": 0, "note": "Bridges even-money bets and number chips."},
	# Trophies: only from an Enforcer's stash, never sold in the Cage.
	"sals_whistle": {"name": "Sal's Whistle", "desc": "Every 3rd spin at a table scores x1.5.", "price": 0, "unlock": 0, "trophy": true,
		"note": "Big Sal called his spins; now you call yours."},
	"oros_coin": {"name": "Oro's Coin", "desc": "Whenever a zero hits, +10 Take.", "price": 0, "unlock": 0, "trophy": true,
		"note": "Madame Oro's lucky green coin."},
	"accountants_book": {"name": "Accountant's Book", "desc": "+$1 for every spin an outside bet wins.", "price": 0, "unlock": 0, "trophy": true,
		"note": "Balanced books, in your favour for once."},
	"velvet_rope": {"name": "Velvet Rope", "desc": "+2 betting chips to your stack every spin.", "price": 0, "unlock": 0, "trophy": true,
		"note": "The VIP line moves fast."},
	"klines_watch": {"name": "Kline's Watch", "desc": "+1 spin at every table.", "price": 0, "unlock": 0, "trophy": true,
		"note": "He was always early. Now you are too."},
	# Scaling rules: they grow with the build.
	"crowd_pleaser": {"name": "Crowd Pleaser", "desc": "Every scoring spin x(1 + 0.05 per level of permanent chips on your felt).",
		"price": 9, "unlock": 0, "note": "The more you've built, the louder the room gets."},
	"purist": {"name": "Purist", "desc": "x2 on a spin where every winning bet was a straight-up.",
		"price": 8, "unlock": 0, "note": "No hedging, no splits: just numbers."},
	"high_stakes": {"name": "High Stakes", "desc": "x1.5 on spins with 15 or more betting chips riding.",
		"price": 7, "unlock": 0, "note": "Push the pile in and the house pays attention."},
	"rainy_day": {"name": "Rainy Day Fund", "desc": "A spin that scores no Take pays +$2.",
		"price": 5, "unlock": 0, "note": "Bridges a cautious layout and a cash build: even bad spins pay."},
}

# --- Unlockable table features --------------------------------------------------------------
const FEATURES := {
	"call_bets": {"name": "Call Bets", "desc": "Adds Voisins, Tiers and Orphelins to the felt: bets on arcs of the wheel.",
		"unlock": 2, "note": "Real French call bets; finally makes wheel order matter."},
}

# --- Enforcers (boss tables) -----------------------------------------------------------------
const ENFORCERS := {
	"accountant": {"name": "The Accountant", "rule": "no_outside", "trophy": "accountants_book",
		"desc": "Outside bets are off the books: they can't be placed and don't pay.",
		"intro": "Mr. Vance doesn't like round numbers. Inside bets only tonight.",
		"defeat": "...The ledger balances. For now."},
	"oro": {"name": "Madame Oro", "rule": "zero_tax", "trophy": "oros_coin",
		"desc": "Every zero costs you 10% of the Take you've built.",
		"intro": "Green is my favourite colour, darling. Every time it comes up, I take a cut.",
		"defeat": "Lucky. Luck doesn't last in this building."},
	"vic": {"name": "Vic \"The Rake\"", "rule": "frozen", "trophy": "sals_whistle",
		"desc": "Your biggest permanent chip is frozen and pays nothing this table.",
		"intro": "Nice stack. Be a shame if it couldn't move.",
		"defeat": "Vance is gonna hear about this."},
	"sal": {"name": "Big Sal", "rule": "called", "trophy": "sals_whistle",
		"desc": "Every 3rd spin is called: you can't place new bets on it.",
		"intro": "I call the spins at my table. You just watch.",
		"defeat": "Huh. Didn't call that one."},
	"duchess": {"name": "The Duchess", "rule": "crowd", "trophy": "oros_coin",
		"desc": "Piles are vulgar: any bet of 5 or more chips on one spot pays half.",
		"intro": "Darling, nobody needs that many chips in one place. Spread them out or pay for it.",
		"defeat": "How very... democratic of you."},
	"tempo": {"name": "Miss Tempo", "rule": "tempo", "trophy": "sals_whistle",
		"desc": "Keep the beat: every spin that scores nothing costs 10% of the Take you've built.",
		"intro": "One, two, one, two. Miss a beat and the band stops playing for you.",
		"defeat": "You kept time. Barely."},
	"timekeeper": {"name": "The Timekeeper", "rule": "clock", "trophy": "klines_watch",
		"desc": "The clock is running: the payment grows by 5% every spin.",
		"intro": "Every tick costs you. I'd hurry.",
		"defeat": "...Time's up. For me, apparently."},
	"ilsa": {"name": "Countess Ilsa", "rule": "no_repeat", "trophy": "velvet_rope",
		"desc": "No encores: you can't bet on a spot you bet on last spin.",
		"intro": "The same bet twice? How dreadfully dull. I won't allow it.",
		"defeat": "At least you were never boring."},
	# Act II: the Floor Above (nights 5-7), then the Owner on night 8.
	"inspector": {"name": "The Inspector", "rule": "no_inside", "trophy": "accountants_book", "act": 2,
		"desc": "Inside bets are under review: no splits, streets, corners or lines, and those chips don't pay.",
		"intro": "Gaming commission. Routine check. Keep your chips in the middle of the squares, please.",
		"defeat": "Everything appears to be... in order. How irritating."},
	"velvet": {"name": "Velvet", "rule": "drain", "trophy": "velvet_rope", "act": 2,
		"desc": "The room has a minimum: every spin costs 2 chips from your stack.",
		"intro": "Upstairs, darling, we don't count chips. We just watch them leave.",
		"defeat": "You kept some. How quaint."},
	"kline": {"name": "Mr. Kline", "rule": "short", "trophy": "klines_watch", "act": 2,
		"desc": "A short table: only 4 spins to make the payment.",
		"intro": "I'm a busy man. Four spins. Make them count or make them your last.",
		"defeat": "...Fine. Next."},
	"auditor": {"name": "The Auditor", "rule": "no_rules", "act": 2, "trophy": "accountants_book",
		"desc": "Your House Rules are suspended at this table. Only the wheel's own rules apply.",
		"intro": "I'll be reviewing those little arrangements of yours. Until then, they don't exist.",
		"defeat": "Everything checks out. Somehow."},
	"montague": {"name": "Silk Montague", "rule": "skim", "act": 2, "trophy": "oros_coin",
		"desc": "The house skims 15% off every spin's Take.",
		"intro": "A little off the top, dear. It's how the lights stay on.",
		"defeat": "You'd make a fine skimmer yourself."},
	"winter": {"name": "Mr. Winter", "rule": "cold_red", "act": 2, "trophy": "velvet_rope",
		"desc": "A cold table: permanent chips on red numbers score half.",
		"intro": "Red's a warm colour. I don't care for warm.",
		"defeat": "...Thawed. How irritating."},
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

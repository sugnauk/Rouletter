# Changelog

The version is shown bottom-right on the title screen (`core/version.gd`). Every update bumps
the last number; a bigger change of direction bumps the middle one.

## 0.0.30
- Where the money came from: every dollar in a run is logged by source (starting cash, base pay, balls left, comps, side jobs, chips like Mint, Dealer favours, loans and more).
  - The end screen has a MONEY tab beside YOUR BUILD.
  - The pause menu shows your top three sources so far.
- The Pawn Shop is now a tree: seven lanes (Wheels, Chips I/II, Felt, Rules I/II, Extras), cheapest at the top. Each unlock needs the one above it in its lane. The lines light up as you climb.
- Challenge ladder: win a challenge to open its next level. Level II runs on a Grade 3 marker, Level III on Grade 5. Pick the level on the wheel screen. Winning any challenge at Level III earns the Hard Way Round Feat.
- Weekly sharing: finishing a weekly run copies a share code (like RLT-W2917-N3-T1234-L-1A2B) to your clipboard and shows it on the end screen.
  - Paste a friend's code into the CODE box in Weekly mode to compare.
  - Your best weekly runs this week are listed there too.
  - An online leaderboard would need a server; codes work today without one.

## 0.0.29
- Three new Act II Enforcers. Each Act II run now meets three of the six before the Owner:
  - The Auditor: your House Rules are suspended (the wheel's own still apply).
  - Silk Montague: skims 15% off every spin.
  - Mr. Winter: permanent chips on red numbers score half.
- Enforcer rewards: beat an Enforcer and raid their stash. Take their trophy or one of two rare chips. Trophies are House Rules sold nowhere else:
  - Sal's Whistle: every 3rd spin x1.5.
  - Oro's Coin: +10 Take on zeros.
  - Accountant's Book: +$1 when an outside bet wins.
  - Velvet Rope: +2 stack chips every spin.
  - Kline's Watch: +1 spin at every table.
- Marker grades get rule twists in place of two plain number changes:
  - Grade 5 is now Cracked Luck: from night 2, one of your chips cracks each night.
  - Grade 8 is now One Window: only the Cashier works the Cage.
- Balance: Enforcer tables ask a little more (x1.95 of the night's base, was x1.8) to offset the trophies.

## 0.0.28
- Builds can explode now:
  - Three scaling House Rules:
    - Crowd Pleaser: every scoring spin x(1 + 0.05 per level of permanent chips on your felt).
    - Purist: x2 when every winning bet was a straight-up.
    - High Stakes: x1.5 with 15+ chips riding.
  - Three chain chips, where one chip sets off others:
    - Conductor: when it hits, every multiplier chip you own fires too, wherever it sits.
    - Relay: when it hits, your other number chips score half their straight-up pay.
    - Fuse: +2 Take for every level your other chips grow that spin.
  - New Almanac categories: Scaling Rules and Chain Chips, all with pixel icons.
- Run summary: the end screen shows your build.
  - The felt you finished with.
  - Your top three chips by Take scored.
  - Your best spin broken down by chip and multiplier.
  - The run's seed.
- Save image saves the summary as a PNG to share: a download on the web, your user folder on desktop.

## 0.0.27
- Gentler first runs. Until you've cleared a night, the extra systems arrive one night at a time:
  - night 1 is just roulette, your kit and the free chip;
  - side jobs start on night 2;
  - table conditions and the route pick start on night 3;
  - Cage events start on night 4.
  Veterans get everything from the start.
- Dolores explains each system the first time it shows up: the free chip, side jobs, table conditions, the route pick, Cage events, and Refine/Trade.
- Touch screens: hold a bet for a menu with Take back, -1 chip, Pin/Unpin and Clear inside. These match right-click, Shift, Alt and Ctrl with a mouse.
- Faster previews: the hover previews and the gold "could clear" rings are cached until the felt changes, so they don't re-run dozens of spin calculations on every hover (helps phones and the web build).

## 0.0.26
- A free special chip at every table: before the first spin, pick one of three, each from a different build direction. It's never a plain Permanent. Hover to see what it does; picking it puts it in your rack to place. This replaces the one-off pick after the first table.
- More to buy: the Cashier now stocks 3 chips. Plain Permanents are much rarer in the Cage (about 1 slot in 7, for levelling), so the counter is mostly special chips.
- The Cage's tokens shrink a little when a busy counter needs the room.
- Balance: payments from night 2 on are higher to match the extra chips. Night bases went from 8 / 21 / 52 / 96 to 9 / 32 / 105 / 240, and Act II scales the same way. Balance bot wins: French 35%, European 28%, Mini 40%.

## 0.0.25
- Stacking a chip on its twin is never worse than owning the two apart. Each chip in a stack keeps its full effect:
  - Multipliers multiply per stacked chip: two Kingmakers stacked are x1.5 x1.5 = x2.25 (was x2.0). The same goes for Ace of Spades and Column Crown. Levels gained other ways (Echo, Ledger, growth) still add +0.5 / +0.25 each.
  - Respin gives a spin per stacked chip. Echo and Ledger give a level per stacked chip. Wildcard Zero and Collector pay per stacked chip.
  - Growth chips (Compounding, Snowball, Green Thumb, Seedling) grow once per stacked chip. Seedling's cap is 5 per chip. Jackpot Jar empties back to one level per chip.
  - Selling a stack refunds every chip in it. Moving or trading a stack keeps it whole.
- Hovering a square shows how many chips are stacked there. Dolores' tip and the item descriptions explain stacking.

## 0.0.24
- Balance: Mini wheel payments x1.05 -> x1.2. With its Bridge starter it was winning far more often than the other wheels (balance bot: 62% -> 45%).

## 0.0.23
- Art pass: the 31 items that showed two-letter tiles now have real pixel icons (a die, a sailboat, an owl, a piggy bank, a clover, a pocket watch and more). So do the four bridge rules.
- New Feats:
  - Small Wonder: win on the Mini wheel.
  - Dawn Patrol: win on the Sunrise wheel.
  - Grand Tour: win a run on every wheel.
- Design doc updated with everything from 0.0.15 on.

## 0.0.22
- Run modes on the wheel screen (the MODE button):
  - Weekly challenge: the same wheel, seed and Grade 2 marker for everyone this week, worked out from the date (no server needed). Your best weekly run is remembered. Winning it earns the Weekly Winner Feat.
  - Four named challenges, each with its own Feat:
    - No Outside Bets: the boxes are closed all run.
    - The Fence's Run: only the Fence works the Cage. You start with a Magnet, a Permanent and +$10.
    - Enforcer Gauntlet: every table is an Enforcer.
    - Shoestring: a 12-chip stack, and no Pit Boss or Loan Shark.
- Seeds: every run has one, shown in the pause menu and the run history. Type a seed (a number or any word) on the wheel screen to replay or share a run.
- Starting kits: buy alternative kits at the Pawn Shop and pick one with the KIT button.
  - Banker's Kit: no chips, +$8.
  - Collector's Kit: three random common chips.
  - High Roller's Kit: a Kingmaker.
- Continue Run now shows the saved run: wheel, night, where you are, marker left, mode or grade, your key chips, cash and seed.
- The pause menu lists your marker grade's modifiers.
- The "Short Stack" table condition is now "Thin Stack", so it isn't confused with the Grade 2 marker.

## 0.0.21
- Four new Act I Enforcers. Each run now meets four of the eight, so no two runs face the same lineup:
  - The Duchess: any bet of 5+ chips on one spot pays half. Spread out.
  - Miss Tempo: every spin that scores nothing costs 10% of the Take you've built.
  - The Timekeeper: the payment grows 5% every spin.
  - Countess Ilsa: no encores. You can't bet on a spot you bet on last spin.
- Table conditions: from night 2, ordinary tables can roll a twist.
  - Spread Out: spins covering all three dozens score +25%.
  - Tight Felt: 6 bet spots at most.
  - Early Bird: clear by the 3rd ball for +$2.
  - Thin Stack: 4 fewer chips, but +$2 when you clear.
- Side jobs: every table has an optional objective that pays on the clear: Clean Hands, Bullseye, Hat Trick or Light Touch. Progress shows in the table's side panel.
- Pick your table: before each night's High Roller, choose one:
  - The Back Room: 4 balls, payment x0.8.
  - The Long Table: 8 balls, payment x1.2, Tight Felt.
  - The usual table.
- Between tables: before the Enforcer, someone in the Cage may have an offer. Dolores' tip, Lucky Lou's side bet, or a free (hot) chip from the Fence.
- The Cage now previews the next table: its Enforcer, route, condition and side job. Hover it for the details.
- The clear tally lists every condition, route, side job and side bet that paid.

## 0.0.20
- Every wheel now starts you on a different plan, named on the select screen:
  - French: Safety Net. A Permanent x2 and a Hedge.
  - European: Numbers. A Magnet and a Permanent.
  - American: Zero Chips. A Sentinel, and +$4.
  - Mini: Inside Bets. A Bridge.
  - Triple Zero: Zero Economy. Wildcard Zero and a Spare Key.
  - Sunrise: Multipliers. A Kingmaker, with Momentum built in.
  - Cheater's: Even Money. Starts with Satin Gloves.
- On the house: after your first table, pick one free chip or House Rule from three different build directions (or pass).
- Paid with 3+ balls to spare? Instead of the balls-left cash being paid automatically, pick a bonus: that cash, a free Dealer favour, or a free reroll.
- Hold an item through a reroll: right-click (or long-press) it in the Cage. It's marked HOLD and stays when you reroll.
- New Cashier services:
  - TRADE $3: swap a placed chip for a related one. It keeps its square and level.
  - REFINE $6: give a number chip at level 2+ a second act. Focused scores double on its own number. Steady pays +1 Take per level on every miss. A small diamond on the chip marks its path.
- Four bridge House Rules, each linking two ways of betting:
  - Outside Connection: winning dozens and columns pay +1 per level of your number chips inside them.
  - Inside Track: winning inside bets level up the chip on the winning number.
  - Colour Coded: red or black wins pay +1 per level of your number chips of that colour.
  - Rainy Day Fund: a spin that scores nothing pays +$2.
- Each Cage window now says what it's for: the Cashier deepens your build, the Pit Boss sells rules, the Loan Shark patches the next table, the Fence sells cheap gambles, and the Dealer invests in the run.

## 0.0.19
- See your build on the felt:
  - Hover a square to light every bet and chip that would score if it hits, with the Take it would add.
  - Holding a chip from your rack, hover the felt to see every pocket it would pay on from there.
  - Hovering a chip in your rack lights the pockets it pays on, for chips that don't care where they sit.
- The payment is the star of the HUD: "TAKE 3 / 8   NEED 5". Before you spin, any bet that would pay the rest of the table on one hit gets a pulsing gold ring.
- Quicker layout edits:
  - Shift-click takes back one chip of your bet size.
  - Ctrl-click a dozen, column, red/black or other outside box to clear every bet inside it.
  - Alt-click pins a bet (a small red pin), so Clear leaves it on the felt.
- The Cage reads your build. Hovering an item shows what it adds to your felt and last layout, e.g. "With your last layout: +1.4 Take a spin". A trigger chip lights the pockets it pays on, and a placed chip names your best bet to put it on.

## 0.0.18
- Feats that tell a story, announced the moment they happen:
  - Paid in the Nick of Time: pay an Enforcer with your last ball.
  - One and Done: clear a table on its first spin.
  - The Comeback: clear on the last ball from under half the payment.
  - Seasoned: a chip reaches level 5.
  - Inside Man: win a run without ever betting on an outside box.

## 0.0.17
- No more black borders: the game now scales smoothly to any window or phone screen instead of in whole steps, with pixel snapping to keep the art crisp.
- New wheel select screen: one wheel at a time, shown big, with < and > buttons (or the arrow keys) to browse. Dots show where you are, locked wheels say what they cost, and the panel lists pockets, zeros, house edge, payments, starting cash, kit and built-in rules. Enter deals you in.
- Title screen: the lifetime "paid to Vance" stat is gone (each run's marker is its own).

## 0.0.16
- Distinct sounds for each felt action:
  - placing a bet, and stacking a chip on its twin (with a "LEVEL UP!" pop)
  - taking a bet back, Undo, and clearing the felt
- Chips now fly visibly between your stack and the felt when you bet, take back, undo or clear.
- The music follows the table. A tension layer (a heartbeat and a ticking clock, in time with the band) fades in on the last two balls and when the payment is within reach. It drops away when the table is paid.

## 0.0.15
- Spins now play out in three beats:
  - The pocket is revealed and lights up.
  - Each winning bet and triggered chip lights up in turn.
  - The Take counts into the payment.
- Exceptional spins get their own beat and a new musical sting: a final-ball clear ("ON THE LAST BALL!", a dealer line and a gold log entry), a one-spin jackpot, a personal-best spin, or a 5+ hit combo. Ordinary spins stay brisk.
- Spin receipt: a one-line summary under the score (bets, chips, multipliers, losses, cash = total). Click the panel for the full calculation.
- Missed a payment? The end screen now says how far short you were and lists the layout you had down.
- Fast spins (Options and the pause menu): a short wheel spin and a brisk count, remembered between runs.
- Code: the count moved to `scenes/screens/table_count.gd`.

## 0.0.14
- **50 chips.** 22 new ones, sorted in the Almanac as Pattern, Watch, Growth and Cash chips:
  - Pattern: Odd Fellow, Even Keel, Low Roller, Penthouse, Prime Time, Square Deal, Teen Idol, Fibonacci, Nickel, Seventh Heaven, Last Digit.
  - Watch: Dozen Watch, Pillar, Doorbell, Four-Leaf Clover, Far Side, Night Owl, Heart of Gold.
  - Growth: Seedling.
  - Cash: Piggy Bank, Golden Goose, Spare Key.
- **25 House Rules.** 9 new ones:
  - Zero Tolerance: bets come back on a zero.
  - Bankroll: +1 chip a spin.
  - Compound Interest: $1 per $10 held at each clear.
  - Double Down: first spin x2.
  - Corner Office: corners pay 10:1.
  - Big Spender: +$3 on 50+ spins.
  - Patron: +1 spin at Enforcer tables.
  - Late Bloomer: x1.5 from spin 4.
  - Old Timers: level 3+ chips x1.5.
- New Almanac category: Money rules.

## 0.0.13
- 10 new chips (28 total):
  - Street Light: +3 when another number in its street hits.
  - Red Herring: +2 on any red.
  - Jackpot Jar: grows every miss, pays big, then empties.
  - Hedge: sits on an even-money box, +1 every spin it misses.
  - Wheel Spoke: +4 when the ball lands 1-2 pockets away on the wheel.
  - Echo (legendary): when it hits, every other chip levels up.
  - Ace of Spades (legendary): black numbers only, x2 spin.
  - Tip Jar: $1 per losing betting chip.
  - Green Thumb: a zero chip that grows on every zero.
  - Signpost: a line chip that pays $2.
- 8 new felt upgrades (17 total):
  - Diamond Square: levels its chips when it hits.
  - Magnetized Square: its chips score half on grid neighbours.
  - Twin Square: its chips also pay on the mirror number.
  - Spoke Square: wheel neighbours' chips score half when it hits.
  - Gold Trim: +0.5x and +$1.
  - Fat Box: +2 per winning chip.
  - Repeat Box: x2 if the last ball landed there too.
  - Lucky Colour: a new kind of upgrade for the even-money boxes, pays 2:1.
- Icons, rarities, Almanac categories, Cage hints and on-felt markers for all of them.

## 0.0.12
- Fix: the macOS build (universal, for Apple Silicon too) now exports; Windows and Linux already did.

## 0.0.11
- Almanac sorted into categories (Scoring, Growth, Modifier, Zero and Cash & Time chips; Number and Outside upgrades; Payout, Multiplier and Safety rules; Dealer favours and vouchers), each with "found / total", "bought" and a progress bar.
- Unseen entries show their rarity, and locked ones say how many Markers they cost at the Pawn Shop.

## 0.0.10
- Desktop builds: Windows, Linux and macOS exports. Every version bump that reaches `main` publishes a GitHub Release with all three zips and these notes (`.github/workflows/desktop.yml`).

## 0.0.9
- 13 new things to buy:
  - Chips: Black Cat (+Take on any black hit), Lucky Penny (+$2 when it hits), Snowball (grows 2 levels per hit), Sentinel (zero chip: +8 on any zero), Column Crown (sits on a column: x1.25 spin when it hits).
  - Felt upgrades: Lucky Lamp (+$3 when its number hits), Silk Box (losing bets on that column/dozen go back to your stack), Sweet Spot (every bet covering that number x1.5).
  - House Rules: Last Call (final spin of each table doubles), Comped Drinks (+$3 per clear), Insurance (your biggest losing bet each spin is forgiven), High Society (columns and dozens pay +1x), Black Tie (black straight-ups x1.5).
- All of them have icons, rarity, Almanac entries and Cage synergy hints.

## 0.0.8
- Marker grades: a 9-step difficulty ladder. Win a run to open the next grade on the wheel screen. Each grade keeps the ones below it and adds a twist: Short Stack, Tight Cage, Heavy Payments, No Tips, Fast Tables, Mean Enforcers, Pricey Rerolls, Vance's Own Marker. Bigger grades carry a bigger marker.
- Two new Feats: win on Grade 3+, and win on Grade 9.

## 0.0.7
- Pause menu (Esc, or the MENU button at the table and in the Cage): Resume, Options, Abandon run (two clicks; counts as a loss), Quit to title (your run is kept for Continue).
- Options: Reset progress (two clicks; keeps your options), and a Credits screen.
- Run history: your last 10 runs on a new HISTORY tab of the Feats screen.

## 0.0.6
- Balance: nights 2-4 ask a little more (8 / 21 / 52 / 96, Act II raised to match); Mini wheel payments x1.05 (was 1.15), Cheater's x1.25 (was 1.35).
- The balance bot now places Bridges on corners, skips zero chips on zero-less wheels, buys Dealer perks and only pays the Pit Boss when its stack can take it.

## 0.0.5
- Cage hints: hovering an item says which of your chips, rules and upgrades it works with ("Works with your Porch Light"), and whether it's good or useless against the Enforcer at the next table.
- Bigger description panel in the Cage.

## 0.0.4
- Tap-to-zoom felt: on touch screens (or with the new Options toggle) the first tap zooms the felt to nearly full screen so splits and corners are easy to hit; tap outside to close. Spinning closes it too.
- Fix: win sparkles and floating text now land on the right square on widescreen windows.

## 0.0.3
- Music: a synthesised lounge band (walking bass, brushes, comped chords, vibraphone) and a darker, faster version at Enforcer tables.
- Music and sound volume controls in Options.

## 0.0.2
- New players meet the Cage one window at a time: only the Cashier on night 1, the Pit Boss from night 2, the Loan Shark and Dealer after your first Enforcer.
- One-time tips from Dolores the first time you see a flawed chip, a rare item, spare Take, or buy a chip you can level up.

## 0.0.1
First numbered build. Everything up to now:
- **Table:** split, street, corner and line bets on the felt's lines; bets repeat each spin; Undo, Clear and 1/2/3 chip keys; touch tap-to-bet and hold-to-take-back.
- **The Cage:** vendor windows: Cashier, Pit Boss (paid in stack chips), Loan Shark, Fence (flawed chips), Dealer (favours and vouchers paid in spare Take).
- **Chips and rules:** rarity tiers, levelling by stacking twins, Bridge, Kingmaker, Mirror, Porch Light, Cornerstone, Split Decision, Momentum, Lucky Sevens, Satin Gloves.
- **Run:** each run is one $1,000,000 marker paid off table by table; run saves with Continue.
- **Story:** the cast (Vance, Dolores, Lou, Abe, Sal, the vendors), interludes between nights, Journal, Act I epilogue; Act II on the Floor Above with new Enforcers and the Owner.
- **Progression:** Feats paying Markers, the Almanac, run summary, next-unlock goals; Sunrise and Cheater's wheels.
- **Presentation:** title card, themed loading cards and boot splash, pixel portraits, jackpot/big-win juice, reward tally, new sounds, Options (CRT, colour-blind marks, cards, shake), fullscreen without black bars.

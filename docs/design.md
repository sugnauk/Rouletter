# Rouletter: Design (score-run build)

A roulette roguelite. **The wheel is always fair, and the felt is what you build.** Runs are structured like Balatro: hit a score within a limited number of spins, shop between tables, and face boss tables. Felt Wars (the territory war against the dealer) was dropped after its playtest, and its code is kept in `archive/felt_wars/`.

## Story (light noir)
All scenes live in `core/story.gd` with an id and a Journal title; `profile.seen_beats` records what you've seen.
1974, the Gilded Ace casino. **Each run is one marker**: you start it owing Mr. Vance $1,000,000 ($5,000,000 in Act II). Every table is a payment due; clearing it pays that table's share of the marker (weighted by its payment), missing one ends the run, and clearing the last night pays the marker in full. The HUD shows what's left; the title screen shows only lifetime stats and Markers. Story beats unlock as you progress (runs, nights reached, wins). Enforcers are Vance's people. Data lives in `core/story.gd` and the Enforcers in `core/content.gd`.

## Run loop
- **4 Nights × 3 tables:** Floor, then High Roller, then Enforcer. Clearing Night 4 wins the run.
- **Act II, the Floor Above** (opens after your first Act I win): pick ACT II on the wheel screen and the run carries on upstairs for nights 5-8 (Private Room, Velvet Room, Enforcer), against three new Enforcers and finally the Owner, Mr. Vance, at his own table. Act II runs carry a $5M marker.
- **Table:** reach the **Take** target within **6 spins**. Each table hands you a **betting stack** (25 chips, which you can upgrade).
  - Winning bets score `value × payout` and the stake returns to your stack.
  - Losing bets are gone, and **their value comes off that spin's Take** (floored at 0). A spin scores what it paid minus what it cost, so hedging (red + black, or covering the board) scores nothing.
  - After each spin the UI plays "the count": wins and bonuses pop in turn with rising coin sounds, then multipliers stamp, then losses tick off, and the total slams into the Take meter.
  - **Permanent chips** from the shop sit on the felt and score every time they hit.
  - **Bets:** every square and outside box, plus inside bets on the felt's lines: splits (edges), corners (where four squares meet), streets and six-lines (the edge against the dozens strip) and zero splits. Hovering a line highlights the numbers it covers.
  - **Layout repeats:** after each spin the bets you spun with go back on the felt, as far as the stack allows. **Clear** (`C`) takes every bet back, **Undo** (`Z`) takes back the last bet, `1`/`2`/`3` pick the chip size. On touch screens a tap bets and a hold takes the bet back, and line zones are wider.
  - Chips in the rack must be placed before you can spin or leave the Cage.
- **Score vs cash:** Take is the score. Cash ($) is separate and buys things at the shop. You earn it on a clear (base + $1 per unused spin + comps of $1 per $5 held, max $5) and from Mint chips.
- **Lose** if the spins run out below the target, or you're bust (no stack and nothing on the felt).
- **The Cage (shop):** a row of **vendor windows**, each selling different things for a different currency. The Cashier is always open; the others rotate.
  - **Cashier** (cash): 2 chips and 1 felt upgrade. Reroll, a bigger stack, move a chip ($2) and sell a chip are cash services too.
  - **Pit Boss** (stack chips): 2 House Rules (5 relic slots). His price is taken off your betting stack at the next table, rises by 2 per rule you own, and never leaves you under 10 chips.
  - **Loan Shark** (pay later): $5 or $10 now; the next table's payment grows by 15% or 35%.
  - **Fence** (cash, unlocked with Markers): chips at half price, each with a flaw: Cracked (scores half), Hot (confiscated the first time a zero hits) or Sticky (can't be moved or sold).
  - Each visit the Cashier works with **one other vendor** drawn from the unlocked pool; rerolls refresh their stock, not the staff. Vendors live in `VENDORS` in `core/content.gd`.
- **HUD:** shows Take per spin and the **pay-off chance**. The chance is an exact convolution over the remaining spins, assuming you bet the same way each time.

## Wheels = starting gamblers
Payout formula: `numbers / numbers covered − 1`, so every plain bet loses exactly `zeros / pockets`.

| Wheel | Pockets | Edge | Identity | Unlock |
|---|---|---|---|---|
| French | 37 | 2.7% (1.35% even-money) | La Partage built in, starts with a Permanent x2, payments ×0.9 | free |
| European | 37 | 2.7% | Starts with a Magnet | free |
| American | 38 | 5.3% | 00 is a second zero square; +$4 | 3 Markers |
| Mini | 13 (3×4 felt) | 7.7% | Small payouts, frequent hits, payments ×1.05 | 4 Markers |
| Triple Zero | 39 | 7.7% | Starts with a Wildcard Zero; zero chips trigger 3× as often | 6 Markers |
| Sunrise | 37 | 2.7% | Momentum built in, starts with a Kingmaker; payments ×1.15 | 5 Markers |
| Cheater's | 36 | 0% | No zero at all; payments ×1.25 | 8 Markers |

## Content
Every entry has an originality `note` in `core/content.gd`.
- **Chips:** Permanent, Magnet, Compounding, Croupier, Wildcard Zero, Mint, Respin, Bridge (line bets only), Kingmaker, Mirror, Porch Light, Ledger*, Collector*.
- **Rarity:** common / rare / legendary (`RARITY` in `core/content.gd`) sets how often things appear in the Cage (6:3:1) and their token frame (cyan, shimmering gold).
- **Levels:** place a chip on its twin (same kind, same flaw) and it levels up (+1 value). Value scales payouts, Mint cash, Croupier rake, Bridge bonus and Kingmaker (x1.5, +0.5 per level).
- **Felt upgrades:** Gilded, Hot, Neighbour Link, Double Felt, Cornerstone, Pinned Pocket*.
- **House Rules:** La Partage, Red Streak, Rent Control, Thirteen, Split Decision, Lucky Sevens, Satin Gloves, En Prison*, Hot Hand*, Dealer's Signature*, Momentum*.
- **Vendors:** Cashier, Pit Boss, Loan Shark, Fence*.
- **Feature:** Call Bets* (Voisins, Tiers and Orphelins on the felt).
- **Enforcers:**
  - The Accountant: no outside bets.
  - Madame Oro: each zero costs 10% of your Take.
  - Vic "The Rake": your biggest chip is frozen.
  - Big Sal: every 3rd spin is called, so no new bets on it.
  - Act II: The Inspector (no inside bets), Velvet (each spin costs 2 stack chips), Mr. Kline (4 spins only), and the Owner (zero tax + called spins).

\* Unlocked with Markers at the **Pawn Shop**. You earn 1 Marker per night cleared, plus 3 for a win.

**Resolution order** (shown in the in-game log): base, then felt upgrades, then chip effects, then House Rules / Enforcer. Exception: Magnets slide as the ball drops, before payout.

## Presentation
640×360 base resolution, integer-scaled with nearest filtering and no font anti-aliasing. Everything is drawn procedurally (`scenes/ui/*`): the felt, chip stacks, wheels, the ball's skid and drop, payout floaters, the Take tally, screen shake, and noir portraits. An optional CRT shader toggles with **F2**.
- **Title card** (`scenes/screens/card_screen.gd`): the Gilded Ace's neon sign stutters on, "Mr. Vance presents ROULETTER". Click or any key skips.
- **Loading cards** (`scenes/ui/transition.gd`): `main.go(screen, title, subtitle)` fades to a themed card (night and table, the Enforcer, the Cage) with a rotating tip, swaps the screen, and fades back. Click/Space skips. Smoke runs skip all cards.
- **Boot splash** `assets/splash.png` is rendered from the title card's last frame (`godot --path . --resolution 640x360 -- splash profile=user://smoke_profile.json`). The web export restyles Godot's loader through `html/head_include` (dark wall, gold pixel progress bar, Silkscreen font copied next to `index.html` by CI). Fonts: **Silkscreen** (body, 8px) and **Press Start 2P** (titles, 16/24px), both SIL Open Font License from google/fonts, with their licences in `fonts/`. Keep font sizes at multiples of 8 so they stay pixel-exact. Audio cues are stubbed in `scenes/ui/sfx.gd`; drop a file at `audio/<cue>.wav` and it plays.

## Code map
- **`core/`**, scene-independent:
  - `wheels.gd` and `board.gd`: per-wheel geometry
  - `felt_state.gd` and `resolver.gd`: pure spin resolution and EV
  - `odds.gd`: pay-off chance
  - `run_table.gd`: the run's state, saves (versioned, with `migrate()`), tables and spins
  - `run_state.gd`: extends it with the Cage (vendors, stock, prices, services, stash, choices); callers use `RunState` as one object
  - `preview.gd`: cached "what if" previews for the felt and the Cage
  - `profile.gd`, `story.gd` and `content.gd`
  - `game.gd`: the autoload
- **`scenes/main.gd`:** the screen router.
- **`scenes/screens/*`:** title, select, table, shop, end and pawn screens. The table screen's helpers:
  - `table_count.gd`: the three-beat count;
  - `table_overlays.gd`: the free-chip panel, the touch bet menu, quick edits and first-time tips.
- **`scenes/ui/*`:** felt, wheel, dialogue, palette and sfx.

```
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/sim.gd -- runs=300 [all]
godot --path . --windowed -- smoke=<dir> profile=user://smoke_profile.json   # screenshots of every screen
```

## Balance snapshot (sim bot, 400 runs per wheel, starting pool, v0.0.6)
Full-run win rate: French 14%, European 18%, American 7%, Mini 17%, Triple Zero 4%, Sunrise 4%, Cheater's ~0%. Per-table clear rates are mostly 75-95%. The bot spreads chips over fresh numbers, buys cash items, Dealer perks and (when its stack can afford it) Pit Boss rules, and never borrows; a human should do noticeably better. Night bases are 9 / 32 / 105 / 240 (Act II 330 / 450 / 600 / 780) since v0.0.26's free chip at every table. Tune the constants at the top of `core/content.gd`, plus `target` in `core/wheels.gd`.

## Roadmap ("The Floor Above")
1. Done: vendor Cage (Cashier, Pit Boss), title card and loading cards, Undo and touch controls, branch CI.
2. Done: story cast (Rosa, Lucky Lou, Abe, Big Sal, the vendors), milestone beats (first Enforcer, third run, first win, six runs without a win), interludes before nights 2-4, vendor introductions, a Journal screen that replays every scene, and the Act I epilogue when the marker is paid.
3. Done: Loan Shark, Fence and flaws; inside-bet content (Bridge chip, Cornerstone upgrade, Split Decision rule); multipliers (Kingmaker chip x1.5, Momentum rule +25% per scoring spin in a row).
4. Done: Act II (nights 5-8 upstairs, the Owner), three new Enforcers, Sunrise and Cheater's wheels, Act II story beats and interludes, `tools/sim.gd -- act=2`.
5. Vouchers, Dealer favours, run saves, endless mode, onboarding and accessibility.

CI: `.github/workflows/test-branch.yml` runs the tests and the smoke screenshots on every non-main push and PR (screenshots are the run's artifact); `deploy-web.yml` publishes `main` to Pages.

## Marker grades (difficulty)
`Content.GRADES` (9 grades). Winning at grade N opens N+1 (`profile.best_grade`); grades are cumulative: 2 Short Stack (-5 chips), 3 Tight Cage (+$1 cash prices), 4 Heavy Payments (+10%), 5 No Tips (no cash for spare spins), 6 Fast Tables (-1 spin at High Roller/Enforcer), 7 Mean Enforcers (+10% at boss tables), 8 Pricey Rerolls (start at $4), 9 Vance's Own (+10% more). The marker's face value grows 25% per grade. Sim (European, bot): ~18% / 11% (G3) / 6% (G4) / ~0% from G5; humans should go much further. `tools/sim.gd -- grade=N`.

## Polish pass (after the roadmap)
- **Per-run marker** (see Story): HUD marker bar, loading cards, end-screen "paid / left".
- **Juice:** chips fly from winning squares into the Take meter, a combo counter, NICE / BIG WIN / JACKPOT tiers (flash, slow-mo, coin rain, fanfare), PAID glow on the meter, near-miss shudder with "SO CLOSE", a table-clear reward tally, SOLD! pops, cash that counts up with coin ticks, a breathing SPIN button.
- **Progression:** 20 Feats paying Markers (`core/feats.gd`, toasts, Feats screen), the Almanac (everything seen or bought), run summary (best spin, Enforcers beaten, Feats), the next Pawn Shop unlock shown on the title and end screens.
- **Content:** rarity tiers and weighted stock, chip levelling, Mirror / Porch Light chips, Lucky Sevens / Satin Gloves rules.
- **Art:** pixel portraits for every character (`scenes/ui/portraits.gd`) in dialogue, Enforcer cards and the boss panel; chip shine and legendary halos; rarity frames.

## Feel and replay (v0.0.15-0.0.23)
- **Spin feel:** a three-beat count (`scenes/screens/table_count.gd`): reveal, then the build lights up, then the Take counts in. Win tiers with their own timing and stings, a spin receipt, distinct sounds for each felt action, a tension music layer, Fast spins, and story-shaped Feats.
- **Readable builds** (`core/preview.gd`, Resolver dry-runs):
  - Hover a square for what scores if it hits, and the pockets a chip pays on.
  - Gold rings mark bets that would clear the table.
  - Quick edits: Shift (-1 size), Ctrl (clear an area), Alt (pin).
  - Loadout-aware Cage hints ("With your last layout: +1.4 Take a spin").
- **Run identity:**
  - Each wheel has a named starter plan (`style`/`kit`/`house` in `core/wheels.gd`).
  - A free pick-1-of-3 from different build directions after the first table.
  - Clearing with 3+ balls left offers a bonus pick (the balls-left cash, a favour, or a reroll).
  - Hold one item through a reroll.
  - Cashier services: Trade ($3, a related chip) and Refine ($6: Focused or Steady, `Chip.mod`).
  - Four bridge House Rules.
- **Table variety:**
  - Act I has 8 Enforcers, 4 per run (adds Duchess, Miss Tempo, Timekeeper, Countess Ilsa).
  - Table conditions (`CONDITIONS`), side jobs (`OBJECTIVES`), a route pick before the High Roller (`ROUTES`), and between-table events (`EVENTS`).
  - The next table is rolled when the Cage opens, so the Cage can preview it.
- **Long-term:**
  - Seeds (`run_seed`; `RunState.parse_seed`).
  - A weekly challenge derived from the date (`RunState.weekly_preset`).
  - Named challenges (`CHALLENGES`, with Feats).
  - Starter kits sold at the Pawn Shop (`STARTERS`).
  - Continue-run details on the title screen, and per-wheel Feats including the Grand Tour.
- **Art:** pixel sprites (`Art.SPRITES`, 12x12 character grids) replaced the lettered tiles.
- **Balance (bot, 300 runs, full pool, v0.0.21):** French 35%, European 35%, American 21%, Mini 45% (payments raised to x1.2 in v0.0.24, from 62%), Triple Zero 21%, Sunrise 13%, Cheater's 4%.

- **Free chips (v0.0.26):** every table opens with a free pick of one special chip from three (`RunState.table_offer`). The Cashier stocks 3 chips, and Permanents show up in about 15% of shop slots (`PERM_CHANCE`). Bot wins: French 35%, European 28%, American 23%, Mini 40%, Triple Zero 21%, Sunrise 29%, Cheater's 4%.

## Depth pass (v0.0.27-0.0.32)
- **Onboarding:** new players get one system per night (`RunState.ONBOARD_NIGHT`), each explained once by Rosa (`Story.TIPS`).
- **Touch:** a long press opens the bet menu. Previews are cached by felt signature.
- **Builds:**
  - Scaling rules (Crowd Pleaser, Purist, High Stakes).
  - Chain chips (Conductor, Relay, Fuse).
  - An end-screen build summary (`contrib`, `best_spin_info`) with Save image.
- **Bosses:**
  - Act II has 6 Enforcers, 3 per run.
  - Beating one opens their stash: a trophy rule (`ENFORCERS[*].trophy`) or a rare chip.
  - Grades 5 and 8 are now rule twists (Cracked Luck, One Window).
- **Meta:**
  - The money log (`cash_log`).
  - The Pawn Shop tree (`Profile.tree()` / `requires()`).
  - Challenge levels (`profile.challenge_level`).
  - Weekly share codes (`RunState.share_code`). An online leaderboard needs a server.
- **Presentation:** Enforcer stings (`Sfx` cue `enforcer:<name>`), animated Enforcer cards, the victory theme, and felt/rail colours per wheel (`felt` / `rail` in `wheels.gd`).

## Known gaps and next steps
- Late-game scaling is mostly additive. It needs more multiplicative synergies (Balatro-style) so builds can explode.
- Run saves (resuming mid-run), an endless mode, more Enforcers and a Floor 2 / Owner arc.

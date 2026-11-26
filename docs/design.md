# Rouletter: Design (score-run build)

A roulette roguelite. **The wheel is always fair, and the felt is what you build.** Runs are structured like Balatro: hit a score within a limited number of spins, shop between tables, and face boss tables. Felt Wars (the territory war against the dealer) was dropped after its playtest, and its code is kept in `archive/felt_wars/`.

## Story (light noir)
All scenes live in `core/story.gd` with an id and a Journal title; `profile.seen_beats` records what you've seen.
1974, the Gilded Ace casino. You owe its owner, Mr. Vance, a **$1,000,000 marker**. Each run is a night of payments: every table's Take target is a payment due, and missing one ends the run. The Take you bank pays down the debt ($100 per point), and the debt carries across runs. Story beats unlock as it shrinks. Enforcers are Vance's people. Data lives in `core/story.gd` and the Enforcers in `core/content.gd`.

## Run loop
- **4 Nights × 3 tables:** Floor, then High Roller, then Enforcer. Clearing Night 4 wins the run.
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
  - Vendors live in `VENDORS` in `core/content.gd`; Loan Shark, Fence and Dealer are planned.
- **HUD:** shows Take per spin and the **pay-off chance**. The chance is an exact convolution over the remaining spins, assuming you bet the same way each time.

## Wheels = starting gamblers
Payout formula: `numbers / numbers covered − 1`, so every plain bet loses exactly `zeros / pockets`.

| Wheel | Pockets | Edge | Identity | Unlock |
|---|---|---|---|---|
| French | 37 | 2.7% (1.35% even-money) | La Partage built in, starts with a Permanent x2, payments ×0.9 | free |
| European | 37 | 2.7% | Starts with a Magnet | free |
| American | 38 | 5.3% | 00 is a second zero square; +$4 | 3 Markers |
| Mini | 13 (3×4 felt) | 7.7% | Small payouts, frequent hits, payments ×1.3 | 4 Markers |
| Triple Zero | 39 | 7.7% | Starts with a Wildcard Zero; zero chips trigger 3× as often | 6 Markers |

## Content
Every entry has an originality `note` in `core/content.gd`.
- **Chips:** Permanent, Magnet, Compounding, Croupier, Wildcard Zero, Mint, Respin, Ledger*, Collector*.
- **Felt upgrades:** Gilded, Hot, Neighbour Link, Double Felt, Pinned Pocket*.
- **House Rules:** La Partage, Red Streak, Rent Control, Thirteen, En Prison*, Hot Hand*, Dealer's Signature*.
- **Feature:** Call Bets* (Voisins, Tiers and Orphelins on the felt).
- **Enforcers:**
  - The Accountant: no outside bets.
  - Madame Oro: each zero costs 10% of your Take.
  - Vic "The Rake": your biggest chip is frozen.
  - Big Sal: every 3rd spin is called, so no new bets on it.

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
  - `run_state.gd`: the run loop and shop
  - `profile.gd`, `story.gd` and `content.gd`
  - `game.gd`: the autoload
- **`scenes/main.gd`:** the screen router.
- **`scenes/screens/*`:** title, select, table, shop, end and pawn screens.
- **`scenes/ui/*`:** felt, wheel, dialogue, palette and sfx.

```
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/sim.gd -- runs=300 [all]
godot --path . --windowed -- smoke=<dir> profile=user://smoke_profile.json   # screenshots of every screen
```

## Balance snapshot (greedy bot, 300 runs per wheel, starting pool)
Full-run win rate: French 11%, European 13%, American 8%, Mini 11%, Triple Zero 5%. Per-table clear rates are mostly 70–95%. The bot is naive (it doesn't plan placements or pick shop items well), so a human should do noticeably better. Tune the constants at the top of `core/content.gd`, plus `target` in `core/wheels.gd`.

## Roadmap ("The Floor Above")
1. Done: vendor Cage (Cashier, Pit Boss), title card and loading cards, Undo and touch controls, branch CI.
2. Done: story cast (Dolores, Lucky Lou, Abe, Big Sal, the vendors), milestone beats (first Enforcer, third run, first win, six runs without a win), interludes before nights 2-4, vendor introductions, a Journal screen that replays every scene, and the Act I epilogue when the marker is paid.
3. Loan Shark (borrow against the next target), Fence (cheap items with flaws), inside-bet content, multipliers.
4. Act 2: nights 5-8 upstairs, the Owner, new Enforcers and wheels.
5. Vouchers, Dealer favours, run saves, endless mode, onboarding and accessibility.

CI: `.github/workflows/test-branch.yml` runs the tests and the smoke screenshots on every non-main push and PR (screenshots are the run's artifact); `deploy-web.yml` publishes `main` to Pages.

## Known gaps and next steps
- Late-game scaling is mostly additive. It needs more multiplicative synergies (Balatro-style) so builds can explode.
- Run saves (resuming mid-run), an endless mode, more Enforcers and a Floor 2 / Owner arc.

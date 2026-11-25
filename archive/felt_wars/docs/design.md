# Rouletter: Felt Wars against the House

A roguelite built on a **fair** European roulette wheel (uniform 1/37). All progression comes from changing the payout board. This prototype builds **Plan 2: Felt Wars**, reusing Plan 1's board, chips and resolver.

## Pillars
- **Honest RNG, dishonest math.** Every spin is a true 1/37. Odds are known, so the HUD shows the exact **EV per spin**, worked out over all 37 pockets.
- **The felt is the deck-builder.** Where a chip sits (its neighbours, street, dozen, column) matters.
- **The house edge is territory you can see.** The House holds squares with its own chips. Whoever holds the square the ball lands on gets paid.

## Rules as implemented
**Ownership.** On each number, whoever has more straight-up chip value owns it, and the House wins ties. *Double Felt* doubles both sides' weight on that square. The Pit Boss rule *Heavy Chips* doubles the House's weight.

**When the ball lands on pocket P:**
| Who holds P | Result |
|---|---|
| You | Each of your chips covering P pays normal odds (35:1, 2:1, ...) from the **table bank**. House chips on P are captured, and you get their value. |
| The House | The House collects 35x its stack from **your bankroll**, into the bank. Every chip of yours covering P (straight or outside) is **seized**. |
| Nobody | Your covering chips pay normally. |

- **Permanent chips** stay on the felt and are never lost on a miss. They cost `PERM_PRICE` (12) coins per point of value.
- **Bets** (temp chips) are plain one-spin roulette bets. They are lost on a miss, and they are exactly -1/37 EV on an empty board.
- **Flanking:** a House square where you own at least 3 neighbours (or all of them, if it has fewer) loses 1 value each spin.
- **Walls:** the House can't place chips on a street (column of 3) that you fully own.
- **Win a table** by breaking its bank. **Lose the run** at 0 bankroll. **Shift over:** if the spins run out first, you lose 25% of your bankroll and get no spoils (against the Pit Boss, you lose the run).
- Your chips and felt upgrades **carry between tables**. The House's chips leave when the table ends.

**Resolution order** (shown in the in-game log): base payouts/collections/captures, then felt upgrades, then chip effects, then House Rules, then House pressure (flanking, Pit Boss). Exception: Magnets slide as the ball drops, before payout.

## Content
| Chips | Effect |
|---|---|
| Permanent (x1/x5/x25) | Never cleared. |
| Magnet | Slides onto the winner if it's one grid square away. |
| Compounding | +1 value per spin it survives. |
| Croupier | On a hit, rakes 1 from every House chip that missed. |
| Wildcard Zero | Sits on 0. When 0 hits, outside bets push and the House collects nothing. |
| Mint | +2 coins per spin from the bank. |
| Respin | A hit gives +1 spin on the shift. |
| Ledger | A hit gives +1 value to your adjacent chips. |
| Collector | A hit pays +1 per value of your other chips in its dozen or column. |

**Felt upgrades:** Gilded (40:1, which also pays the House if it holds the square), Hot column/dozen (+1x), Neighbour Link (adjacent chips of the owner pay 25%), Double Felt.
**House Rules:** La Partage, Red Streak, Rent Control (House collections -10%; it was "quota -10%" in Plan 1), Thirteen.
**Dealers:** the Shuffler (moves a stack each spin and retakes thin squares), the Banker (holds one dozen), the Zero Priest (spreads out from 0).
**Pit Boss rules:** Decay (your biggest chip -1 per spin), Heavy Chips.
**Events:** Loan Shark, Crooked Croupier, Back-Room coin flip.
**Floor:** 2 tables, then event/Banker, then table/event, then the Pit Boss. Every node connects to every node in the next layer.

Every content entry in `core/content.gd` has a `note` explaining why it is roulette-specific (the originality guard).

## Code map
- `core/board.gd`: geometry, every bet type, adjacency, wheel order.
- `core/felt_state.gd`: chips, upgrades, rules, ownership, flanking, walls.
- `core/resolver.gd`: pure `resolve_spin(felt, pocket)` and `expected_value(felt)`.
- `core/house_ai.gd`: dealer personalities.
- `core/run_state.gd`: the run state machine (map, table, spoils, events). The `Game` autoload (`core/game.gd`) holds one instance.
- `core/content.gd`: all content and balance constants.
- `scenes/main.gd` + `scenes/wheel.gd`: the prototype UI, built in code.
- `tests/run_tests.gd`, `tools/sim.gd`, `tools/ui_smoke.gd`.

```
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/sim.gd -- runs=300
godot --path . --script res://tools/ui_smoke.gd -- <screenshot dir>
```

## Balance snapshot (greedy bot, 200 seeds)
Table 1: 76%, Table 2: 57%, Table 3: 62%, Pit Boss: 44%. About 27% of runs are won. Tune the constants at the top of `core/content.gd`.

## Deviations from the plan
- Content is in `core/content.gd` dictionaries instead of `data/*.tres` Resources. That's quicker to iterate on, and it can move to Resources once the content settles.
- One `scenes/main.tscn` with the UI built in code, instead of separate `table.tscn`/`shop.tscn` (Plan 2 has no shop).
- The resolver supports splits, streets and corners, but the UI only exposes straight and outside bets for now.
- Scripts use `preload` constants instead of `class_name`, so headless `--script` runs work without an editor-generated class cache.

## Open questions after first playtest
European only, or American as a hard mode? Upkeep on permanent chips? Meta-progression? Theme? Also: should capturing a House square cost more than out-stacking it? Is the 25% shift penalty too soft?

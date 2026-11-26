# Balance report (bot, v0.0.38)

From `godot --headless --path . --script res://tools/sim.gd -- runs=300 all report`: 300 runs per wheel, the full unlock pool, Act I, base marker. The bot is simple and greedy, so read this as where to look in playtests, not as verdicts.

## Win rates

| Wheel | Win |
|---|---|
| French | 40% |
| European | 37% |
| Mini | 44% |
| Triple Zero | 31% |
| Sunrise | 30% |
| American | 22% |
| Cheater's | 6% |

## Where runs end

About **a third of lost runs end on the very first table** (Night 1, Floor). Most of the rest end on night 1's High Roller or the night-4 Enforcer.

| Table | Lost runs |
|---|---|
| N1 Floor | 438 |
| N1 High Roller | 225 |
| N4 Enforcer | 161 |
| N1 Enforcer | 149 |
| N2 Floor | 108 |

**Watch in playtests:** does the first table feel like a fair start, or a coin flip?
- The bot spreads a thin stack over two numbers there, and people may do better.
- If players lose on table 1 too, lower night 1's payment (`NIGHT_BASE[0]` in `core/content.gd`, currently 9). Or let the first spin of a run never cost Take.

## Enforcers (cleared / reached)

| Enforcer | Cleared |
|---|---|
| The Timekeeper | 84% |
| The Accountant | 86% |
| Vic "The Rake" | 88% |
| The Duchess | 90% |
| Miss Tempo | 91% |
| Madame Oro | 92% |
| Countess Ilsa | 93% |
| Big Sal | 93% |

The Timekeeper (the payment grows each spin) and the Accountant (no outside bets) are the toughest for the bot.

**Watch:** whether people find Ilsa and Sal too easy, and whether Timekeeper's growing payment feels fair or just mean.

## Table conditions
Tables with a condition (from night 2) are cleared about 94% of the time. Tables without one are cleared about 82%, but those include all of night 1, so this mostly measures build strength, not the conditions.

**Watch:** do players notice the conditions and play around them?

## Items
How often the bot bought each item when it was on the counter:
- **Chips:** bought 65-87% of the time. The bot buys chips first, so this says little about chips beyond "affordable".
- **Felt upgrades:** 37-45%.
- **House Rules:** 14-46%. Rules come from the Pit Boss, paid in chips off your next stack, and the bot rarely spares the chips.
- **Rarely taken even when offered:** Rent Control 14%, Patron 15%, Purist 15%, Hot Hand 15%, Crowd Pleaser 17% and Last Call 19%.

**Watch:** do people buy House Rules at all? Is the stack price a fair trade? Do the scaling rules (Crowd Pleaser, Purist) ever win a run?

## Re-running
```
godot --headless --path . --script res://tools/sim.gd -- runs=300 all report
```
Use `act=2` for Act II, and `grade=N` for a harder marker.

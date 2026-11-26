# Changelog

The version is shown bottom-right on the title screen (`core/version.gd`). Every update bumps
the last number; a bigger change of direction bumps the middle one.

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

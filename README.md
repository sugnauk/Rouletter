# Rouletter

A roulette roguelite. **The wheel is always fair, and the felt is what you build.**

1974, the Gilded Ace. Every run you owe the owner, Mr. Vance, a $1,000,000 marker. Each night you face three tables, and each table has a payment due: reach its Take target before the balls run out, and that table's share of the marker is paid. Between tables you visit the Cage, where the Cashier, the Pit Boss, the Loan Shark, the Fence and the Dealer each sell different things for a different kind of money. Bend the payouts, never the wheel.

The version is shown bottom-right on the title screen; see [CHANGELOG.md](CHANGELOG.md) for what changed.

**Play in your browser:** https://sugnauk.github.io/Rouletter/

## Controls
- **Click** a square (or a split, corner, street or line on the felt's edges): bet from your stack. **Right-click**: take it back. **Shift-click**: take back one chip. **Ctrl-click** an outside box: clear the bets inside it. **Alt-click**: pin a bet so Clear keeps it. Hover a square to see what scores if it hits.
- **Z / Backspace**: undo the last bet. **C**: clear all bets. **1 / 2 / 3**: chip size 1, 5 or 10.
- **Space**: spin. Your layout goes back down after every spin. **L**: toggle the spin log.
- **Touch:** tap the felt to zoom it, tap to bet, hold to take a bet back, tap outside to close.
- **F2**: CRT filter. **F11** / **Alt+Enter**: fullscreen. Volume and accessibility settings are under Options.

## Running locally
Open `project.godot` in Godot 4.7 and press F5.

```
godot --headless --path . --script res://tests/run_tests.gd   # rules tests
godot --headless --path . --script res://tools/sim.gd          # balance sim
```

Every push to `main` builds the web version and publishes it to GitHub Pages (`.github/workflows/deploy-web.yml`). Every push to another branch runs the tests and takes screenshots of every screen (`.github/workflows/test-branch.yml`; the PNGs are the run's "screenshots" artifact). The design notes are in [docs/design.md](docs/design.md).

## Playtesting

Send testers [docs/playtest.md](docs/playtest.md). Every run's end screen has a **Copy report** button that copies the run as text (tables, bets, free picks, Cage buys, money and top chips) for them to paste back. The balance bot's view is in [docs/balance_report.md](docs/balance_report.md).

Fonts: Silkscreen and Press Start 2P, both under the SIL Open Font License (see `fonts/`).

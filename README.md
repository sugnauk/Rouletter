# Rouletter

A roulette roguelite. **The wheel is always fair, and the felt is what you build.**

You owe Mr. Vance, owner of the Gilded Ace, a $1,000,000 marker. Each night you face three tables, and each table has a payment due: reach its Take target before the balls run out. Between tables, spend your cash at the Cage on permanent chips, felt upgrades and House Rules. Bend the payouts, never the wheel.

**Play in your browser:** https://sugnauk.github.io/Rouletter/

## Controls
- **Click** a square: place a bet from your stack. **Right-click**: take it back.
- **Space**: spin. **L**: toggle the spin log.
- **F2**: CRT filter. **F11** / **Alt+Enter**: fullscreen.

## Running locally
Open `project.godot` in Godot 4.7 and press F5.

```
godot --headless --path . --script res://tests/run_tests.gd   # rules tests
godot --headless --path . --script res://tools/sim.gd          # balance sim
```

Every push to `main` builds the web version and publishes it to GitHub Pages (`.github/workflows/deploy-web.yml`). The design notes are in [docs/design.md](docs/design.md).

Fonts: Silkscreen and Press Start 2P, both under the SIL Open Font License (see `fonts/`).

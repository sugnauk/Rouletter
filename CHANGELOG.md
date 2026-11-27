# Changelog

The version is shown bottom-right on the title screen (`core/version.gd`). Every update bumps
the last number; a bigger change of direction bumps the middle one.

## 0.0.52
- **Every item on the felt has its own face.** Each chip kind shows a small picture of its own (a snowflake for Snowball, a U magnet, a key, a ticket...) on a dark inlay, in its own colour.
  - Item chips have gold edge spots; bet chips keep cream ones, so a Snowball no longer looks like a 1 chip.
  - Chips on the felt are a size bigger, and an item's level sits on its rim instead of covering the picture.
  - Twelve newer chips that fell back to bet-chip cream now have colours of their own.
- **Felt upgrades get a badge:** each upgrade's own picture in the corner of its square, and a strip colour no other upgrade shares.
- **Pattern chips go on numbers they watch.** Odd Fellow, Even Keel, Low Roller, Penthouse, Prime Time, Square Deal, Teen Idol, Fibonacci, Nickel and Seventh Heaven only go on numbers in their own set (e.g. Seventh Heaven on 7, 17 or 27), and only those light up while you hold one.
  - On its own number a pattern chip now pays both ways: the straight bet and its bonus.
  - On a wheel with none of its numbers (Teen Idol on the Mini Wheel) it can still go anywhere.
  - Chips already on the felt from an older save stay where they are.
- **Info cards say a chip is also a bet:** "Its own number also pays as a straight bet of its level (35 to 1)." Watch chips (Dozen Watch, Pillar, Doorbell, Last Digit, Clover, Far Side) say their bonus fires on other numbers.

## 0.0.51
- **Every new wheel has its own Enforcer,** met on that wheel only, and always somewhere in Act I:
  - **The Twins** (Twin Ball): two balls drop, but only the better one counts for you.
  - **The Mechanic** (Crooked Wheel): the fat pockets move every 2 spins, not just every table.
  - **The Ringmaster** (Carousel): the hot arc runs backwards, 2 pockets a spin.
- **Three legendary capstones,** one for each combo family:
  - **Ivory Tower** (chip): whenever anything hits, your tallest chip scores half its pay too.
  - **Standing Ovation** (rule): an extra ball earns another ball, once a table.
  - **House Odds** (rule): with 3 or more box chips on the felt, outside boxes pay +1x.
- **The Cheater's Wheel is fairer:**
  - Payments are a touch smaller (they were 25% bigger).
  - It starts with an Even Stevens beside its Satin Gloves.
  - The bot's win rate is about 27% (it was 6%).
- Every wheel now sits in the same difficulty band for the bot: 21–41% in Act I.

## 0.0.50
- **Combos you can see.** Six named combos, groups of items that feed each other:
  - **Encore Chain:** Respin or Second Wind, plus Encore or Wind-Up.
  - **Skyscraper:** High Rise or Old Timers, plus a growing chip.
  - **Long Odds:** an Odds Maker, plus another box chip.
  - **Growth Engine:** chips that grow other chips, plus chips that grow.
  - **Crown Jewels:** a Conductor, plus a multiplier chip.
  - **House of Zero:** zero chips, plus zero rules.
- **How they show up:**
  - **At the table:** the combos your build has switched on are listed under your House Rules. Hover one to see what it's made of.
  - **When one fires:** when every part of a combo acts in the same spin, its name flashes up (e.g. **ENCORE CHAIN!**) with a sting and a buzz.
  - **In the Cage:** an item's card now says about how much Take a spin it adds to your build, and if it would complete a combo ("Completes the LONG ODDS combo").
  - **Run report:** counts how often each combo fired.

## 0.0.49
- **A guided first run.** A brand-new player's first run on the European wheel is walked through by Dolores, one action at a time. Only the spot she's talking about is lit; the rest of the felt dims.
  1. Put the Box Office on a column.
  2. Put the Magnet on a number.
  3. Bet on red.
  4. SPIN. The first ball is rigged to land on a red number in your Box Office's column, so you see a bet and a chip pay together.
  5. Keep playing the table.
  6. In the Cage, drag something off the counter to buy it.
  7. NEXT TABLE, and you're on your own.
- Every one of her lines has a **SKIP TUTORIAL** button.
- Casebook > How to Play > **Replay the guided first run** turns it back on.
- While it runs, the free chip and the usual first-time tips stay out of the way.

## 0.0.48
- **Phone polish:**
  - **Vibration:** a little buzz on hits, big wins, jackpots and placing chips. Most Androids support it; iPhones don't let web pages vibrate. You can turn it off in Options > Vibration.
  - **Bigger touch targets when upright:** fatter split and corner zones on the upright felt, bigger rack tokens, and no tap-to-zoom (the upright felt is already big).
  - **Long-press to inspect:** long-press an empty spot to see its odds, or a chip to see its card (phones have no hover).
  - **Faster odds:** Twin Ball's pay-off chance is about 10x faster (3ms instead of 37ms on desktop, so no stutter on phones). It's cached between updates, too.
  - **Fixed:** previews on the Crooked Wheel and the Carousel could show stale results after the fat pockets or the arc moved.
  - **Phone test checklist:** `docs/phone_test.md` lists what to check on a real iPhone or Android.

## 0.0.47
- **The run's arc, finished:** steady odds early, stacking in the middle, then spins and combos late.
  - **Early, better odds:** the **Odds Maker** chip sits on an outside box, and every bet there pays +0.25x per level, your betting chips included. At level 4, red pays 2 to 1.
  - **Mid game, stacking pays:**
    - **Keystone:** a hit pays +4 Take per chip stacked on it.
    - **Tall Stack:** +1 Take every spin per level of your tallest chip.
    - **High Rise** (House Rule): chips at level 5 or higher score x2. It stacks with Old Timers.
  - **Late game, spins and combos:**
    - **Night 4 now runs 7 balls,** like the tables upstairs, so Act I's last night gives you room to go after numbers.
    - **Extra balls,** anything past a table's usual count (respins and so on), show as gold balls under the wheel, with an EXTRA BALL banner.
    - **Encore** (House Rule): extra balls score x2.
    - **Second Wind** (House Rule): your first straight-up hit at each table earns a ball.
    - **Wind-Up:** grows a level every time you earn a respin.
    - **Combo chain:** Respin chips and Second Wind feed Encore, Wind-Up and Keystone, and High Rise doubles the big stacks.
- **Payments rebalanced** for night 3 (112) and night 4 (310) so overall difficulty stays where it was.

## 0.0.46
- **Portrait mode, part 2: every screen.** The home screen, wheel select, end of run, Pawn Shop, Casebook, Options, Credits and the title card all have upright layouts now:
  - **Home:** the wheel spins at the top, with the sign and buttons beneath.
  - **Wheel select:** the same layout you know, stacked: modes, the wheel between its arrows, the details, then DEAL ME IN.
  - **Pawn Shop:** narrower lanes with more room between rows, Feats on two lines each.
  - **Casebook:** the list on top and the detail panel underneath.
- Turning the phone mid-run re-lays out every screen on the spot.

## 0.0.45
- **Portrait mode, part 1: the table and the Cage.** Hold your phone upright and the game re-lays itself out. Rotate back and the landscape layout returns.
  - **The felt stands up** like a real table seen from the end: numbers run down in three roomy columns, with the outside boxes along the left. The squares are bigger than in landscape, which makes them easier to hit with a thumb.
  - **Table:**
    - the payment bar across the top;
    - the wheel beside BALLS, SPIN, your stack and the odds;
    - the felt with your bet chips, rack, rules and side job beside it;
    - the count underneath.
  - **Cage:**
    - the counter across the full width, then the description;
    - the felt with your modes and rack beside it;
    - NEXT TABLE at the bottom.
  - Drag-to-buy, dialogue, cards, banners, the free-chip pick and the pause menu all fit the upright screen.
  - **Other screens** (title, wheel select, Pawn Shop, Casebook...) still show the landscape layout, centred, until part 2.
- The web build and phones no longer lock to landscape.

## 0.0.44
- **New wheels that change how a spin works,** not just how many zeros there are:
  - **Twin Ball:**
    - Two balls drop every spin (the second one is gold), and a bet wins if either lands on it.
    - A lost stake is only charged once.
    - Both balls in one pocket is **TWIN!**: the spin's Take x3.
    - Four spins a table, with bigger payments.
  - **Crooked Wheel:**
    - Four pockets are three times as wide. You can see them on the wheel, and they're marked x3 on the felt.
    - They come in far more often, and their payouts follow the true odds, so every bet stays fair.
    - They move to new numbers at every table: chase them or stay put.
  - **Carousel:**
    - A gold arc of seven pockets glows on the wheel and steps round after every spin. A ball inside it doubles the spin.
    - The felt underlines the arc and, faintly, where it's going next.
    - Momentum is built in, and you start with a Kingmaker.
- **Fewer look-alikes:**
  - American and Triple Zero are merged into the **Zero Wheel** (0, 00 and 000, with a Sentinel, a Wildcard Zero and +$2).
  - Sunrise has given way to the Carousel.
  - Now every wheel in the selector plays differently.
- **Saves and Feats:**
  - Old saves, unlocks and Feats carry across.
  - New Feats: Seeing Double (Twin Ball), Bent Pins (Crooked), Carousel Rider.
- **Hit chances** account for crooked pockets and both balls.

## 0.0.43
- **Start steady, hunt numbers later.** A single number hits 1 spin in 37, so a lone number chip often went whole tables without scoring. The run now grows from safe bets into big ones on its own, without any gating by night:
  - **Four new box chips** sit on the outside boxes. They hit about half the time (or a third) but pay small:
    - **Even Stevens:** its box wins, +2 Take.
    - **Box Office:** its column or dozen wins, +3 Take.
    - **Coin Purse:** its box wins, +$1.
    - **Streak Rider:** its box wins, it grows a level (up to 8).
  - Box chips stack and level like any chip, but they can't keep up with later payments on their own. Number chips, stacking, respins and multipliers are where the big Take is.
  - **The opening pick** always includes one option for the outside boxes.
  - **Kits:** the European kit is now Box Office + Magnet, and the French kit trades its Hedge for Even Stevens.
  - **Upstairs tables (Act II and endless) run 7 balls,** so there's room to chase numbers and combos. Their payments are 15% bigger to match.
- **See the odds:**
  - every chip's info card says how often it pays ("Pays on 18 of 37 spins (49%)");
  - hovering a spot shows "hits 18 in 37";
  - Dolores explains the odds at your first table.

## 0.0.42
- **Drag to buy, Balatro-style.** Drag an item off the Cage counter:
  - **A chip onto the felt:** bought and placed in one move. It stays free to move until the spin.
  - **A felt upgrade onto a lit spot:** bought and laid there.
  - **Anything onto the glowing "DROP HERE TO BUY" box** over your rack and House Rules: bought into the rack, rules or perks.
  - **If you can't afford it,** it won't lift, and its card says why.
  - Click, then BUY still works.
- **See where a chip can go.** While you hold or drag a chip, every spot it fits pulses gold (green where it would level up a twin), and everywhere else is dimmed. The status line says the rule in words, e.g. "Goes on an even-money box: red, black, odd, even, high or low."
- **Info cards everywhere:** free chips, everything on the Cage counter, opening, bonus and stash picks, Refine paths, and Pawn Shop and Casebook tiles. The same card shows:
  - the one-line effect;
  - where it goes and how it scales;
  - the fine print;
  - how it fits your build;
  - its price.
- **Shorter descriptions:** every chip, rule, upgrade, favour and voucher is now one short line. The rules detail lives on the card.
- **Table HUD:**
  - the balls count sits under the wheel ("BALLS 4/6");
  - cash is just "$4";
  - your betting-chip stack lies right under the felt;
  - the speed and MENU buttons moved up into the top bar;
  - the LOG button is gone (click the score panel's receipt for the full calculation);
  - "where it pays" previews now clearly recolour the felt.
- **The Take bar fills as the count plays.** Each win pours in with rising coin ticks, a multiplier surges it, a loss drains it. A sparkling leading edge, "HALFWAY", and a gold flash and "PAID!" the moment you cross the payment. (Fastest speed still does one quick fill.)
- **Hedge fixed:** it never pays its box's odds now (it was paying on a hit as well). It's insurance: every spin its box misses, +2 Take per level.

## 0.0.41
- Placements aren't final until the next spin. Any chip you place, in the Cage or at the table, can be picked back up for free until you spin:
  - **In the Cage:** click it (or right-click it) and it's back in your hand, ready to put somewhere else. MOVE is also free for these chips.
  - **At the table:** right-click it, or hold it on a touch screen and choose "Pick up chip".
  - **Stacked onto a twin:** only the chip you just added comes back off; the rest of the stack stays.
  - **Sticky:** even Sticky chips can be repositioned until the spin.
  - **How to tell:** chips placed this turn have a dashed cyan ring and say NEW on their info card.
  - Spinning locks every placement in. Older chips still cost $2 to move in the Cage.

## 0.0.40
- The Mini wheel's felt now fills the same space as every other wheel, at the table and in the Cage. Its four columns of numbers are wider squares instead of a small felt with empty space around it.
- On a busy Cage counter, price tags are shortened to fit the narrower tokens (e.g. the Loan Shark's "+15%").

## 0.0.39
- **No more accidental buys.** Clicking an item in the Cage now selects it: it lights up, and the panel shows what it does, how it fits your build, and a BUY button with its price. Click it again (or BUY) to buy it. Right-click or long-press still holds an item through a reroll.
- **See what your chips do.** Point at (or tap) any of these and a card pops up beside it:
  - a chip on the felt: its level, how many are stacked, any refine or flaw, and what it does (plus any other chips on that spot);
  - a chip in your rack;
  - a House Rule or a voucher.
- **Smoother placing:**
  - While you hold a chip from the rack, every spot it can go is outlined. Spots where its twin already sits glow green, because it'll level up there.
  - The chip follows your pointer as a ghost (a red cross where it can't go).
  - You can drag a chip from the rack straight onto the felt.
  - Right-click puts the held chip back down.
  - After you place a chip, the next one in your rack is picked up automatically.

## 0.0.38
- Playtest kit:
  - **Copy report:** a new button on the end screen copies the whole run as text, ready to paste. It covers:
    - each table, with its payment, Take, spins, the straight-up / inside / outside mix, condition, route and side job;
    - every free chip taken or passed, and every Cage purchase;
    - where the money came from, the top chips, and the final felt and House Rules.
  - `docs/playtest.md`: a one-page guide for testers (what to play, what to answer), plus what to watch for.
  - `docs/balance_report.md`: the balance bot's view. The finding to watch: about a third of the bot's lost runs end on the very first table.
  - `tools/sim.gd -- report` prints item buy rates, Enforcer and condition clear rates, and where runs end.

## 0.0.37
- The Casebook replaces the Almanac, the Journal and run History. One screen, four tabs:
  - **COLLECTION:** every chip, felt upgrade, House Rule and Dealer perk, as icon tiles grouped by family.
    - Each family shows seen, bought and locked counts and a progress bar.
    - Seen tiles are bright, bought tiles have a gold frame, and locked tiles show their Marker cost.
    - Tap a tile for its description, what it works with and its rarity. A locked one takes you to the Pawn Shop.
  - **STORY:** every story scene, by chapter (Prologue, The story, Faces in the Cage, Between nights), with a count per chapter. Click a page to replay it.
  - **HOW TO PLAY:** ten short guide pages covering every part of the game. "Hear it from Dolores" replays her lines for that topic.
  - **RUNS:** your last 10 runs (hover one for its key chips and seed) and this week's weekly-challenge results (click one to copy its share code).
- The title menu is now Pawn Shop, Casebook, How to Play, Options, Credits and Quit.

## 0.0.36
- The Pawn Shop is now the hub for everything about Markers: earning them and spending them.
  - **Top bar:** your Markers and a progress bar to the next unlock you can buy. If you're short, it names the Feats that would earn the rest.
  - **UNLOCKS tab:** the unlock tree. Hovering an unlock you can't afford yet lists the Feats that would pay for it. Clicking one you can't afford says how many Markers you need and how to get them.
  - **GOALS tab:** every Feat, grouped into Spins, Tables, Enforcers, Runs, Wheels and Challenges.
    - Each group has a progress bar and the Markers still left to earn.
    - Each Feat shows its reward.
    - A gold arrow marks any Feat that would, on its own, pay for the next unlock.
- The separate Feats screen is gone; the title menu's "Feats" button became "Almanac" until the Casebook arrives.

## 0.0.35
- Casino-marquee look: every button is now a lit sign. They have a black lacquer face, gold trim and a ring of light bulbs.
  - At rest the bulbs glow warm and twinkle.
  - On hover they chase round the border.
  - On a press they all flash.
  - Big "hero" buttons (NEW RUN, DEAL ME IN) breathe with a slow pulse.
- A new home screen:
  - **The sign:** "ROULETTER" is a neon sign in a frame of chasing bulbs. It flickers now and then, like an old tube.
  - **Markers board:** shows your Markers and a progress bar to the next Pawn Shop unlock. Click it to go straight to the Pawn Shop.
  - **NEW RUN** is a big pulsing plaque, with CONTINUE beside it.
  - **The run you left** sits on a ticket stub: wheel, night, where you are, marker left, cash, seed and key chips.
  - **The wheel** spins under a soft spotlight, with chips tumbling past now and then.
  - **Everything else** is in a tidy grid of smaller marquees.

## 0.0.34
- The game takes its time now. At the new default speed (Normal), the wheel spin, the count, chips flying, banners and screen transitions all play about 1.5x slower.
- Fast-forward: a > / >> / >>> button next to MENU at the table and in the Cage (or press F) cycles Normal, Fast and Fastest.
  - Fast is the old speed.
  - Fastest is the old Fast spins (a short wheel spin and a brisk count).
  - The pause menu and Options have the same setting. If you had Fast spins on, you start on Fastest.

## 0.0.33
- Fixed: on iPhone Safari (landscape), the game could slide under the address bar and run off the bottom of the screen, hiding your stack, chips and SPIN.
  - The page is now pinned to the screen and can't scroll or bounce.
  - The game measures the part of the screen that's really visible and fits itself into it.
- New option, Screen fit (Options, also from the in-game MENU): shrink the game to 95-70% and pin it to the top, for any browser that still hides part of it.
- Add to Home Screen: the web build is now an installable app. On iPhone, Share > Add to Home Screen opens it full screen in landscape, with no Safari bars at all. The title screen says so on the web.

## 0.0.32
- Under the hood, so the next round of features is safer to build:
  - The run is split in two: `core/run_table.gd` (state, saves, tables, spins) and `core/run_state.gd` (the Cage), which extends it.
  - The table screen's overlays (free chip, touch menu, quick edits, tips) moved into `scenes/screens/table_overlays.gd`.
  - Behaviour is unchanged: the balance bot gives the same results.
- Versioned saves: run saves and profiles carry a format version.
  - Older run saves are upgraded step by step on load.
  - A save from a newer version of the game is refused rather than misread.

## 0.0.31
- Every Enforcer has a musical sting: a low stab and a four-note motif from a dark scale, worked out from their name. It plays as their card comes up.
- Enforcer entrances: the loading card before a boss table holds longer. A spotlight snaps on, their portrait slides in out of the dark, and a red bar sweeps under the name.
- A victory theme: a brisk major-key version of the lounge band with a horn line, playing on the end screen when you pay the marker in full.
- Each wheel has its own table skin:
  - French: blue felt.
  - European: classic green.
  - American: bright green with a red rail.
  - Mini: purple.
  - Triple Zero: charcoal.
  - Sunrise: burnt orange.
  - Cheater's: crimson.

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

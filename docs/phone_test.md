# Phone test checklist

The web build is played on phones more than anywhere else. Automated runs cover a phone-shaped
browser (Playwright, iPhone 13 profile), but some things only a real phone shows. Run through
this after any big UI change, on at least one iPhone (Safari) and one Android (Chrome).

## Setup
- [ ] Open the game's link. The loading card shows, then the title card.
- [ ] Tap once: sound starts (browsers only allow audio after a tap).
- [ ] Share > **Add to Home Screen**, then launch from the icon: it opens full screen.

## Orientation
- [ ] Held upright, every screen uses the portrait layout (the felt stands up at the table).
- [ ] Turn the phone sideways: it switches to landscape within a second.
- [ ] Turn it **during a spin**: the count finishes and nothing is lost or overlapping.
- [ ] Turn it in the Cage with a chip held: the chip stays held; placing still works.

## Touch
- [ ] Tap a number: a bet goes on (portrait: no zoom; landscape: the felt zooms first).
- [ ] Tap a split / corner line on the upright felt: the right bet goes on.
- [ ] Long-press a bet: the edit menu opens. Long-press an empty number: its info card shows.
- [ ] Drag an item off the Cage counter onto the felt: it's bought and placed.
- [ ] Drag it onto the glowing rack box instead: it's bought into the rack.
- [ ] Every button is comfortably tappable (nothing needs a fingernail).

## Feel
- [ ] Android: a buzz on SPIN, the ball landing, wins, big wins and placing chips (Options > Vibration turns it off).
- [ ] iPhone (iOS 18 or newer): a light haptic tick at the same moments (a few for a big win). Older iPhones: nothing, and no errors.
- [ ] Tap a House Rule, rack chip or Cage item: its card opens and stays open after you lift your finger. The next tap anywhere closes it.
- [ ] The pay-off chance under the wheel updates without a stutter, on Twin Ball too.
- [ ] Screen fit (Options) shrinks the game if the browser's bars cut it off.

Note anything odd with the phone model, browser and the screen it happened on.

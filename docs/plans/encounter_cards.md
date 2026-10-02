# Encounter cards dealt from a deck

Make the choice of encounters before a fight look like the player has been dealt three cards from a
deck. Each card is the size of a printed playing card and carries a picture of the encounter. The deck
is decoration only: it does not run down and has no count.

Builds on [encounter_choice.md](encounter_choice.md). Code: `src/scenes/screens/encounter_card.*`,
`src/scenes/screens/encounter_choice.*`, `src/scenes/screens/run_screen.gd`.

## What the player sees

1. At the end of the walk up the corridor, the deck slides down from above the top edge of the
   corridor area until all of it shows, above where the cards will land.
2. Three cards leave the deck one after another, face down, and slide to their places in a row over
   the corridor. Each lands slightly turned, as the item tokens sit askew on the board.
3. The cards turn face up one after another. Then the Walk past button fades up.
4. Hovering a card lifts it: it turns straight, rises and grows a little. The shadow does not grow,
   because the token shadow is a shared theme style.
5. Picking a card: the other two turn face down and slide back to the deck, the deck slides back up,
   and the picked card slides up to where the deck was. Then the encounter begins, and the picked
   card stays there while the encounter is shown.
6. Walk past: all three cards turn face down and slide back to the deck, the deck slides back up,
   and then the run moves on.

The cards are not scaled by corridor depth and no longer stand where enemies would. They sit in a
row centred in the corridor area and stay inside it, so they never cover the player's side of the
screen. If the corridor area is too short for a card, the row is scaled down to fit.

## The card

The proportions of a standard poker card (63 × 88 mm, 5:7). The current card is 280 × 380; the new
one keeps the height and is about 272 wide.

Front, top to bottom:

| Part | What it shows |
| --- | --- |
| Title | The encounter's name (`name_key`). |
| Picture | The encounter's image in a frame, drawn with the interface look's portrait material so it matches the portraits. |
| Kind line | The kind (Fight, Rest, Event, Reward, Shop) on a band in the kind's colour (`Colours.BEAT_*`). |
| Hint | The existing hint text (`EncounterCard._hint_text`). |

The front is a worn panel in the token style, so it follows the panel wear and token shadow settings.

Back: the Devil Book painting (`monsters/01 Monster basic v21/Identified Monster Ver.21/Devil Book.jpg`)
centred on a dark card with a printed border. The painting is square with a black background, so it
sits inside the card with dark space above and below. The deck is a few card backs stacked with a
small offset.

## Scene structure

`EncounterCard` stays a `Button` (the `ButtonBare` style, so it draws nothing itself) for `UIJuice`
and the `pressed` signal; the highlight is drawn on the front. The visible card is a child `Card` control holding `Front`
and `Back`:

- The deal moves and turns the button itself (`position`, `rotation`); the choice places it freely, not in a container.
- `UIJuice` animates the button's offset transform for hover and press, as now.
- The turn over squashes `Card` to zero width through its offset transform, swaps `Front` and
  `Back`, and widens it again. Because this is a different node from the one `UIJuice` animates,
  the two do not fight.

The card ignores clicks until it is face up, and every card ignores clicks once one is picked.

`EncounterChoice` gains a `Deck` node of three stacked card backs, and clips to the corridor area so
the part of the deck above the edge is hidden.

## Signals and the run screen

`picked(index)` and `skipped()` are emitted after the cards have gone back to the deck, not on the
click. The run screen keeps its handlers as they are. `reveal(duration)` starts the deal instead of the
fade, and the run screen's call over the end of the walk stays.

The dev commands (`--pick`, `--autofight` in `src/debug/dev.gd`) and `tests/ui/test_run_screen.gd`
emit `picked` and `skipped` directly, so they skip the animation and need no change.

## Encounter images

`EncounterDef` gains `image: String`, a path to a picture in `assets/encounters/`. An empty value
uses the default for the encounter's kind, set in `EncounterCard`. The pictures are copied from the
monster collection at 1024 pixels square, as JPEG on black, which leaves room for the larger picture planned for the
encounter screen.

Every pick below is a placeholder for the owner to replace. Each content file marks it with
`# placeholder image`.

| Encounter | Picture (from `../dark-corridor-design/monsters/`) |
| --- | --- |
| `event_shrine` (A dripping shrine) | Mystery Statue A |
| `event_wanderer` (A figure in the dark) | Hermit A |
| `fight_grunt` (A dim corridor) | Bone Golem |
| `fight_tough` (A blocked passage) | Living Statue A |
| `fight_elite` (An elite ambush) | Fire Goblin A |
| `fight_boss` (The warden's gate) | Black Knight 2A |
| `relic_cache` (A forgotten reliquary) | Treasure Box Re A |
| `rest` (A quiet alcove) | Blue Light |
| `shop_pedlar` (A pedlar's cart) | Goblin Merchant A |
| `shop_rare` (Rare goods) | Evil Merchant A |
| Every other shop (kind default) | Goblin Merchant B |

Kind defaults for the other kinds use the same pictures as the table: fight Bone Golem, event Hermit
A, rest Blue Light, reward Treasure Box Re A.

## Settings

A new **Encounter cards** section on the F7 tab, stored as print settings in
`PrintLook.PRINT_SETTING_DEFAULTS` so the look presets save them:

| Setting | What it sets |
| --- | --- |
| `card_deal_time` | How long one card takes to travel from the deck. |
| `card_deal_gap` | The time between one card leaving the deck and the next, and between one card turning over and the next. |
| `card_turn_time` | How long one card takes to turn over. |
| `card_tilt` | The largest turn a card lands with. |
| `card_spacing` | The gap between cards, as a share of a card's width. |
| `deck_peek` | How much of the deck shows below the top edge, as a share of its height (1 = all of it). |

The section also has a **Restart encounter** button that deals the cards again with the current
settings (see `docs/systems/run_screen.md`).

## Sounds

`assets/sound-effects/ui/paper/` already holds `card_*` and `slide_*` recordings. The plan uses them
first: a slide as each card leaves the deck and a card sound as each one turns over. If they do not
fit, a batch of card deal and card turn sounds can be fetched with the `sfx` skill for the owner to
sort.

## Tests

- `EncounterCard`: an encounter with no image gets its kind's default; the card ignores clicks until
  it is face up.
- `EncounterChoice`: pressing a card emits `picked` once the cards have gone back, and a second press
  in the meantime does nothing; Walk past emits `skipped` the same way.
- `test_the_cards_stand_side_by_side_in_the_corridor` in `tests/ui/test_run_screen.gd` calls
  `_place_cards()` and checks the cards run left to right inside the corridor area. That still holds,
  but during the deal a card is between the deck and its place, so the test reads each card's
  resting place rather than where it is drawn at that moment.

## Docs to update

- `docs/systems/run_screen.md`, the choice of encounters section.
- `docs/systems/encounter.md`, the encounter card telegraph section, and the `image` field.
- `docs/design/authoring.md`, the `image` field.
- `docs/design/art_audio.md`, the card back and encounter pictures as placeholders.
- `docs/systems/debug_panel.md`, the new F7 section.

## Decided

- The deck sits at the centre of the corridor area's top edge.
- The Walk past button stays as it is for now.

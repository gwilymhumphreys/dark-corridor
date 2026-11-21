# Plan: item pools, haste and slow, lives

Three changes the owner decided on 2026-11-20 (decisions #65, #66, #68, #69 and #70). They are independent, so
each is its own stage with its own tests, docs and commit. Reviewed against the code on 2026-11-20.

Suggested order: haste and slow first, then lives, then tags and item pools.

## Stage A: haste and slow (decision #66)

Each is an on-or-off status on an actor with a duration. A new application adds its duration to the
time left. While one is on, the actor's item cooldown bars fill faster or more slowly over time.

### Current state

- `CombatManager.sim_step` fills each item's bar with `it.cooldown.step()`, which adds one step
  (`Ticker.step`). A gated item skips the call.
- `TimedStatus` already adds a reapplication's duration to the time left (`reapply` raises the
  ticker's threshold), and its `count` is unused, so it is the base both statuses need.
- `CombatHooks` is the hook base for statuses and relic passives; `StatusManager.hooks_of(actor)`
  lists them in order.

### Design

| Piece | What |
|---|---|
| `HasteMechanic`, `SlowMechanic` | New mechanics (`'haste'`, `'slow'`) in `src/content/mechanics/`, registered in `MechanicRegistry._build`, each naming its status. |
| `HasteStatus`, `SlowStatus` | Extend `TimedStatus`. Override a new hook, `cooldown_rate(target) -> float`, returning `Balance.HASTE_RATE` or `Balance.SLOW_RATE`, or 1.0 while the actor also has the other one. |
| `CombatHooks.cooldown_rate` | New hook, default 1.0. A relic passive can use it later ("your items fill 10% faster"). |
| `StatusManager.cooldown_rate(actor)` | The product of every hook's rate for that actor. |
| `Ticker.advance(amount)` | Adds `amount` steps; `step()` becomes `advance(1.0)`. |
| `CombatManager.sim_step` | Fills each item's bar with `advance(StatusManager.cooldown_rate(it.owner))`. |

- An effect applying haste or slow carries only a duration (`ItemEffect.duration`) and a target
  shape: self for haste, an opponent shape for slow. Its value is unused.
- Only the bar filling over time changes. Trigger pushes (the full authored seconds, owner), the
  charge and decharge mechanics, status ticks and relics are unchanged.
- Display (owner): the health bar shows the icon alone, with no number. An item that applies haste
  or slow has no value pill, like every status-applying effect.
- Both on at once: neither has an effect (owner). Each keeps counting down its own time, so when the
  shorter one ends the other takes effect for what it has left.
- Determinism holds: the rate is read from statuses in a fixed order each step.

### Open

1. **Pricing.** Unpriced at first, like the attack bonuses. The parked note in `item_heuristics.md`
   on timed debuffs applies.
2. **Content the owner adds:** items that apply them, the two mechanic shops (`shop_haste`,
   `shop_slow`), icons in the `IconSlots` folders and the keyword card text.

### Tests

On fixture items: a hasted actor's item fires sooner and a slowed one's later by the expected steps;
reapplying adds duration; the status expires and the rate returns to 1.0; trigger pushes and charge
are unchanged; a gated item still does not fill; both statuses at once fill at the normal rate, and
the longer one takes effect when the shorter ends.

### Docs

`systems/mechanics.md` (the twelve, a new section), `status_manager.md` (the hook),
`combat_model.md` (the Ticker), `lexicon.md` (drop "planned"). The lexicon now says "slow" is not
used for a long-cooldown item; docs that still say "slow item" change to "long-cooldown item" in the
same stage. Item file comments are the owner's content and are left alone unless he asks.

## Stage B: full heal after every fight, and lives (decisions #68 and #69)

**Built 2026-11-21.** Open points 1 and 2 went with this plan: a lost fight shows its own panel, and
`FIGHT_WON` fires only for a win. `Balance.FIGHT_MAX_HP` is a placeholder (point 3); point 4 is left to
tuning. A death in an event or from a relic run trigger still ends the run.

### Current state

- `RunManager._on_encounter_resolved` ends the run on a lost fight (`_end_run(Outcome.DIED)`). A won
  fight runs `_apply_fight_won_gain` (`Balance.FIGHT_WON_HEAL` health and `Balance.FIGHT_WON_GOLD`).
- `advance()` calls `_full_heal()` when crossing into a new act; the run has one act, so it never
  happens.
- The rest encounter (`content/encounters/rest.gd`) is in `EncounterPools.RIGHT`.
- The run screen treats a resolved fight as won unless the run has ended
  (`run_screen.gd`, the `FIGHTING` state), then burns the square and the enemies.
- A fight's seed comes from the run seed and the beat position (`_combat_seed_for`), so fighting the
  same fight again with the same board gives the same result.

### Design

- `RunManager.lives: int`, starting at `Balance.STARTING_LIVES`, saved in the snapshot and read with
  a default.
- After every fight, won or lost, `_full_heal()` restores the player and the allies.
- Every fight, won or lost, gives `Balance.FIGHT_WON_GOLD` and raises maximum health by
  `Balance.FIGHT_MAX_HP` (a `RunEffect.max_hp`), replacing `FIGHT_WON_HEAL`. The gain is applied
  before the full heal, so the player starts the next fight at the new maximum.
- A lost fight also costs one life, and gives no relic if it is an elite or an act boss. At zero
  lives the run ends as now; otherwise the run moves on to the next beat.
- A lost final boss ends the run (`Outcome.DIED`) whatever lives are left: one attempt (owner).
- `RunEvent.FIGHT_WON` fires only for a won fight, so a relic that reacts to winning does not react
  to a loss.
- `RunEffect.gain_life(n)` (new kind `LIFE`) for event options and relic run triggers.
- Lives in shops: a `StockEntry.lives(amount)` kind and a `LifeDef` that extends `ItemDef`, the way
  potions do (decision #57), so a life is shown and bought like any good. Its price is
  `Balance.SHOP_PRICE_LIFE`.
- `rest` leaves `EncounterPools.RIGHT`. The rest encounter type and its panel stay in the code.
  **Done:** `content/encounters/rest.gd` is deleted and out of the pools.
- Run screen: a lost fight with lives left goes on as a won one does (the square burns), after a
  panel that says a life was lost and how many are left, with Continue, in the same style as the
  rest panel (decision #64). The lives are shown on the character sheet beside health.
- Autotest: the run carries on after a loss; the report records lives lost per fight, and the run
  outcome is DIED only when lives run out. Baselines change.
- `RunManager.RunEvent.FIGHT_LOST` can now exist, because a relic could react to a lost fight. It is
  added with the first relic that needs it.

### Open

1. **The lost fight panel.** Whether a lost fight shows its own panel, or the run goes straight on
   with the lives count changing on the sheet.
2. **`FIGHT_WON` on a loss.** This plan fires it only for a win. If a lost fight should count as a
   fight won for relics too, that is one line.
3. **The health step:** the owner's value, the same for every fight unless the owner wants a larger
   one for elites and bosses. Starting lives are 3 and a life costs 100 gold (owner); both go in
   `balance.gd`.
4. **Enemy damage.** `item_heuristics.md` sets it from what a fight should cost in health, which no
   longer applies. A new rule is the owner's, decided in tuning.

### Tests

Full heal after a won and a lost fight, allies included; a loss with lives left costs one, gives the
gold and health step and moves on; a lost elite gives no relic; the last life ends the run; a lost
final boss ends the run with lives left; lives save and load; `gain_life`; buying a life; maximum
health rises after every fight; `rest` is not offered; the autotest continues after a loss.

### Docs

`run_manager.md` (health economy, lives, snapshot), `encounter.md` (rest, shops, run effects),
`save.md`, `run_screen.md` (the lost fight panel, the lives display), `autotest.md`, `lexicon.md`.

## Stage C: one list of tags, and item pools (decisions #65 and #70)

Two steps, each its own commit: first the tags replace `types` and `mechanics` with no change to
what the game does, then item pools are built on the tags.

### Current state

- `ItemDef.types` holds type tags (`ItemType`: weapon, armour, skill, spell, trinket) and
  `ItemDef.mechanics` holds mechanic ids. About 40 item files under `content/items/` set each, plus
  the fixture items.
- Readers of `types`: `TargetFilter` (`Kind.TYPE`), `Draft._has_any_type` (a stock entry's `types`),
  `CharacterCatalog.starting_board` (`starting_item_types`), the `HasItemType` run condition, the
  tooltip's type line, and `VfxDriver.travel_folders` (one sound folder per type tag).
- Readers of `mechanics`: `TargetFilter` (`Kind.MECHANIC`), `Draft._passes` (a stock entry's
  `mechanic`, used by the ten mechanic shops), and the tooltip's keyword column (`keyword_ids`).
- `test_pool_integrity` checks each mechanics list resolves, is in alphabetical order with no
  duplicates, and lists every mechanic an effect deals or applies.
- `CharacterDef.item_pool` lists item ids. `RunManager._draft_pool()` returns it plus
  `ColorlessPool.ITEMS` (empty). Rewards, shops and `has_items_for` draw from `_draft_pool()`, and
  `starting_board` draws from `item_pool`.
- An item in no character's list is never drafted. That is how Chunk of Flesh (created in fights),
  the enemy Claw and the example items stay out of drafts.

### Step 1: tags (built 2026-11-20)

Built with two differences from the table below: `TargetFilter` keeps its `TYPE` and `MECHANIC`
conditions and `StockEntry` keeps `types` and `mechanic`, both now read against `tags`, because
merging them changed no behaviour. The owner asked for the items to be tagged in the same change:
Mighty Blow gained `attack`, the spore items `spores`, the flesh items `flesh`, and the Smith's
untyped items a type tag.

`ItemDef.tags: Array[String]` replaces `types` and `mechanics`. A tag is a type tag, a mechanic id,
or another name content refers to (such as a pool that is not a mechanic). Each reader moves to
`tags`, with these points:

| Reader | Change |
|---|---|
| `TargetFilter` | One condition kind, `TAG`. `add_type` and `add_mechanic` become `add_tag`. |
| `StockEntry`, `Draft` | `types` and `mechanic` become one `tags` list: an item passes when it holds one of them, and a mechanic shop lists only its mechanic. |
| Tooltip type line | Shows only the tags that are type tags; it already skips names with no display name. |
| Tooltip keyword column | Reads `tags`. Type tags have no keyword card, so they drop out as now. |
| `VfxDriver.travel_folders` | Reads only the type tags, so a mechanic tag does not add a sound folder ahead of the delivery's own mechanic. |
| `starting_board`, `HasItemType` | Read `tags`. |
| `test_pool_integrity` | The same checks on `tags`: each tag is a type tag, a mechanic or a listed other tag; alphabetical with no duplicates; every mechanic an effect deals or applies is listed. |

- The item files change their two lines into one, in alphabetical order. This is a rename of a field,
  not a change to what any item counts as.
- `ItemType` stays as the list of type tags and their display names. A new `ItemTags.OTHER` lists
  the tags that are neither, so a misspelt tag fails the integrity test.
- Nothing in the game changes: the GUT suite and the autotest baselines stay the same.

### Step 2: item pools

**Built 2026-11-21**, with the owner's starting pools below rather than pools that keep every item a
character had: the Smith loses its bleed, poison, burn and decharge items (Acid Bath, Bloodletting,
Dagger, Deep Forge, Iron Maiden, Jar of Acid, Poker, Tongs, Warhammer, Wide Forge). Bloodletting,
Deep Forge, Poker, Tongs, Warhammer and Wide Forge now reach no character. No draftable item lacks
a pool tag: Mighty Blow carries `attack` since step 1, and Hex Bolt and Sundering Bolt are examples,
so they are not draftable. `FixtureContent.install` makes every authored item undraftable, so the
fixture character, holding attack, shield and poison, is offered the three draftable fixture items.

- A pool is a tag (owner): the tags decide what is in each pool. Any tag can be made a pool,
  including a type tag (owner). `ItemPools.POOL_TAGS` lists which tags are pools: every mechanic id,
  plus spores and flesh (owner). A type tag is added there only when a character should need it,
  because an item needs every one of its pool tags and a character holding only attack would
  otherwise never be offered a weapon. An item that makes or spends spores or Chunks of Flesh carries that tag, so it is offered
  only to a character holding that pool.
- An item needs every one of its tags that is a pool. A character with `item_pools` holding all of
  them is offered the item; type tags do not limit who is offered it.
- `CharacterDef.item_pools: Array[String]` replaces `item_pool`.
- `ItemPools.items_for(pool_ids) -> Array` (new, `src/content/items/item_pools.gd`) returns every
  draftable item whose needed pools are all in `pool_ids`, in catalog order so draws stay
  deterministic.
- `_draft_pool()` and `starting_board` use it. `ColorlessPool` is removed.
- `ItemDef.draftable: bool = true`. Chunk of Flesh, the enemy Claw and the example items set it to
  false, since they can no longer be kept out by leaving them off every list.
- Each character's `item_pools` is set so it is offered at least the items it has now. This also
  offers it every other character's items that its pools cover; that is the intended effect, but
  which pools each character holds is the owner's.

- Starting pools (owner, until characters are revisited): every character holds attack, shield and
  heal. The Spore Druid adds poison and spores, and the Fleshmancer adds flesh and bleed. The Smith
  holds only the three, so the Smith's burn, charge, decharge and crit items are not offered to
  anyone until a character holds those pools.
- Items with no pool tag (Mighty Blow, Hex Bolt and Sundering Bolt) are being reworked by the owner.
  Until then an item with no pool tag is offered to every character.
- The two forges now list `attack` as well as burn (owner, 2026-11-20).

### Open

1. Whether summon or other engines become pools (content).
2. The characters' real pools, when characters are revisited.

### Tests

Step 1: the existing filter, shop, tooltip, sound folder and starting board tests read `tags`; the
integrity test as above. Step 2: `items_for` with fixture items: an item needing two pools appears
only when both are held; a type tag does not limit it; an undraftable item never appears; the order
is fixed. The fixture character moves to `item_pools`. `test_pool_integrity`,
`test_starting_board`, `test_draft` and `test_run_manager` change to read the computed pool.

### Docs

Step 1: `item.md` (the tags section replaces the type tags and mechanics list sections, and the
target filters), `encounter.md` (stock entries),
`tooltips.md`, `design/authoring.md`, `lexicon.md` (Tag no longer planned; Type tag becomes a kind
of tag). Step 2: `draft.md`, `run_manager.md`, `design/authoring.md` (how an item gets into a pool),
`lexicon.md` (Item pool no longer planned).

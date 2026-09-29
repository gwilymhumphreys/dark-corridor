# Plan: relics as items without a timer

A relic becomes a kind of item: same definition fields, same tooltip, same fire pipeline, but no
cooldown. It fires when one of its triggers happens instead of when a bar fills. Relics are meant to
be powerful, run-changing abilities, and the set of kinds should eventually cover everything grail's
character traits do (grail's `localization_1.1.1.tsv`, `trait_*_info` rows).

## Owner decisions (2026-09-29)

- A relic is an item with no timer: passive abilities and triggers only.
- The tooltip is the same as an item's.
- All the kinds of ability grail's traits have are wanted in the end (table below).
- A relic firing does not count as an item firing, but the effects it applies (poison and so on)
  set off triggers as usual.
- Enemies can have relics, drawn first in the same place as the enemy's items.
- A relic can fire every time its trigger happens, or be limited ("the first time each fight").
- An always-on relic ability is not a status; it shares the hook functions statuses use, so it
  works the same way without special cases for hidden statuses.
- A relic's effects are listed in its tooltip the same way as an item's.

## Current state

- `RelicDef` (`src/content/relics/relic_def.gd`) is its own type with two fixed kinds:
  `COMBAT_START_STATUS` (Stone Ward, Iron Idol) and `MAX_HP_BONUS` (Vital Charm).
- `RunManager.relics: Array[Relic]` holds them for the run (decision #6). `_apply_relics_to_player`
  applies the status after `Encounter.begin()`; `_apply_relic_grant` applies max HP once.
- Relic tokens on the sheet (`CombatViewFramed._sync_relics`) have no tooltip and take no hover.
  The reward panel's relic option (`RewardOption.setup_relic`) shows only the name.
- Item triggers (`ItemDef.trigger_subs`) push charge into the item's bar; they never fire it
  directly. `Ticker.push(1.0)` fills a whole bar, which `combat_model.md` already describes as an
  instant reaction.
- Combat events (`EventBus.Event`): `ITEM_FIRED`, `APPLIED` (every mechanic and status that lands,
  including attack, shield and heal), `ITEM_DESTROYED`, `CRIT`.
- A status's `outgoing_bonus` only raises attacks (`Item._scaled_value` asks for it only when the
  effect's mechanic is attack).

## Kinds of relic ability

| Kind | grail examples | How a relic does it |
|---|---|---|
| When something happens, do something | "When you shield, heal 2"; "When you take damage, poison 3" | Item effects fired by a trigger (stage 1) |
| At the start of each fight | Stone Ward, Iron Idol; "At battle start, play an extra attack card" | Same, on a new fight start event (stage 1) |
| Limited per fight | "The first time you heal, shield twice the amount" | `fires_per_fight` on the definition (stage 1) |
| Always-on bonus | "Your attack items have +2 attack"; "+5% crit chance" | A passive: an item effect that holds for the whole fight (stage 2) |
| Outside fights | "When you win a fight, gain max HP"; "When you skip a draft, gain gold"; Vital Charm | Run events and run effects (stage 3) |
| Health thresholds and rule changes | "The first time your health reaches 0, heal back to 30%"; "When you crit, fire another item" | A passive class written for the relic, with a new hook where needed (stage 4) |

## Design

### Definition

- `RelicDef extends ItemDef`. It keeps `name_key`, `icon`, `rarity`, `description_key`,
  `mechanics`, `effects`, `trigger_subs`, `crit_chance` and `panel_colour_name` from `ItemDef`.
  `RelicDef._init` sets `cooldown` to one sim step (`Balance.STEP`), so the `Item` it builds has a
  one-step `Ticker`; the tooltip never shows it.
- New fields:

| Field | Meaning |
|---|---|
| `fires_per_fight: int` | 0 = no limit; 1 = "the first time each fight" |
| `passives: Array[ItemEffect]` | Always-on effects, written like item effects, that hold for the whole fight (stage 2 and 4) |
| `run_triggers: Array[Dictionary]` | `{event: RunEvent, effect, amount}` for outside-fight abilities (stage 3) |

- A relic's trigger entry is the same dictionary as an item's (`event`, `filter`, `source_filter`)
  without `seconds`: a relic trigger always fills its whole bar.
- The `Kind` enum and the status fields (`status_id`, `status_count`, `status_duration`) are
  removed in stage 1. `max_hp_bonus` stays, applied on grant as today, until stage 3 replaces it
  with a `PICKED_UP` run trigger.
- `RelicCatalog` stays separate from `ItemCatalog`, so relics are never drafted as items and the
  reward pool stays shared (decision #27).

### In a fight

- `Actor.relics: Array[Item]` holds one `Item` per relic for the current fight, owned by that
  actor and separate from `board`. It is empty between fights.
  - Player: `RunManager.begin_current` fills it from `RunManager.relics` before
    `Encounter.begin()`, replacing `_apply_relics_to_player`. The run keeps only the `Relic` (its
    definition), so per-fight state such as the fire count resets each fight.
  - Enemies: `EnemyDef.relic_ids` (new); `EnemyDef.make_actor` fills `relics` as it fills `board`.
    Enemy actors are built for each fight, so nothing else is needed.
  - `CombatManager._register_actor` registers `actor.relics` alongside the board. `teardown`
    dissolves the relic items and empties the list for the player. `Actor.dissolve` is extended to
    dissolve `relics` as it does `board`, which covers enemies.
- A relic item's `Ticker` has a threshold of one step and is never stepped by time. Its triggers
  subscribe with a push of 1.0. Each step, after the item sweep, a relic whose bar is full fires
  through `_fire_item`, so it gets targeting, crit, deliveries and the combat log like an item. It
  fires the step after its event, the same one-link-per-step rule items follow.
- A relic's fire does not publish `ITEM_FIRED`, so items that react to "an item fired" ignore
  relics (owner). For the same reason it skips `_drain_uses` and `_drain_actor_fire_statuses`: a
  relic's attack does not use up the Smith's Empowered stacks. The events its effects cause when they land (`APPLIED` for poison, shield and so
  on, `DAMAGE_TAKEN`) are published as usual, so those triggers do react. `CRIT` is still published
  when a relic crits.
- After `fires_per_fight` fires, the relic stops firing for the rest of the fight. `Item.fires`
  counts every item's fires in the fight; the relic token also uses it to flash.
- Because the relics are not on the board, board-wide effects ("your items", "charge a random
  item", consume) never pick a relic.
- New combat event `FIGHT_START`, published once in the first sim step after crossings are
  collected, so a start-of-fight relic fires on step two like any other trigger.
- New combat event `DAMAGE_TAKEN`, published when an actor loses health from any source; its actor
  is the one that lost health. This covers grail's "when you're hit" and "when you take damage".
  `Actor.take_damage` has no access to the bus, so it is published where the combat manager
  already reports health loss: the attack mechanic's land, and the status damage paths
  (periodic ticks, `_show_status_damage`). Event damage outside a fight
  (`Encounter` option damage) publishes nothing.
- Other events (health thresholds, fight won within combat) are added when a relic needs one.

### Always-on bonuses (stage 2)

Owner decisions (2026-09-29): an always-on relic ability is not a status, so nothing that acts on
statuses (removing, stealing, counting, consuming, the `APPLIED` event) can touch it. It works
through the same hook functions statuses use. Its tooltip lines are the same as an item's effect
lines.

**Shared hook base class.** The hook functions move from `StatusEffect` into a new base class,
`CombatHooks` (owner, 2026-09-29). `StatusEffect` extends it, and keeps what only statuses have
(`count`, `duration`, `ticker`, `setup`, `reapply`, `consume`, `is_spent`, presentation).

**Passives.** A relic's `passives` are `ItemEffect`s, written the same way as its `effects`
(mechanic, value, shape, target filter). "Your weapon items have +2 attack" is an `attack_bonus`
effect of 2 with shape `ALL_OWN_ITEMS` and a weapon type filter.

- When a relic's `Item` is built for a fight, each passive becomes an instance of a hook class,
  chosen by the effect's mechanic from a new registry (mechanic id to class). The instances live on
  the relic's `Item` in `passives`. A mechanic with no passive class is an authoring error, caught by
  a content check.
- The first passive classes are for the existing `attack_bonus` and `attack_percent_bonus`
  mechanics. Their `outgoing_bonus` returns the bonus when the firing item belongs to the relic's
  owner and matches the effect's shape and filter (`TargetFilter.matches`). Items created during the
  fight are covered, because the check runs at fire time.
- Every place that loops over an actor's statuses to call a hook also loops over the passives of
  that actor's relics, passives first. These places are `StatusManager.resolve_incoming_damage`,
  `outgoing_bonuses` and `has_evasion`, and `CombatManager._drain_actor_fire_statuses` and
  `_on_holder_attacked`. A small helper returns the list in that order so the order stays fixed
  (decision #24). A passive is never removed during a fight, so the return value of
  `on_owner_item_fired` and `on_holder_attacked` is ignored for passives.
- The relic's fire path does not use passives, and a relic with only passives has no triggers and
  never fires.
- `outgoing_bonus` is extended from attacks to every mechanic an item delivers:
  `Item._scaled_value` asks for bonuses for every effect, and the hook receives the effect's mechanic
  so each class decides which it raises. Existing statuses keep raising attacks only. Shield and heal
  bonuses need their own bonus mechanics, added when a relic needs one.

**Tooltip.** Passive lines are built by `_effect_line` exactly as an item's effect lines, so the
example above reads "[attack] +2 to each of your weapon items". They come after the trigger line and
the triggered effects, with no heading; the wording keeps them apart (owner's example: "When you
[poison] deal that much [bleed]" then "Your [poison] items have +2 [poison]"). A passive's value is shown as written, not scaled by bonuses.
`TooltipContent.keyword_ids` also looks at passives, so their keyword cards appear.

### Several triggers with their own effects (stage 2b)

Owner (2026-09-29): a relic must be able to have several triggers that do different things, and
several passives, so a relic is not limited in what it can do. Passives are already a list with one
entry per ability. Triggers today share one bar and one `effects` list, so every trigger fires
every effect.

- A relic trigger entry may carry its own `'effects'` and `'fires_per_fight'`. An entry without them
  fires the relic's `effects` and counts against the relic's `fires_per_fight`, as today, so Stone
  Ward and Iron Idol are unchanged.

  ```gdscript
  trigger_subs = [
    {'event': EventBus.Event.APPLIED, 'filter': ShieldMechanic.ID, 'effects': [ItemEffect.heal(2.0)]},
    {'event': EventBus.Event.APPLIED, 'filter': AttackMechanic.ID, 'effects': [ItemEffect.heal(4.0)],
     'fires_per_fight': 1},
  ]
  ```

- In a fight the relic stays one `Item`, so the token, tooltip, passives and flash are unchanged.
  The `Item` gets one one-step `Ticker` per trigger entry (`Item.trigger_tickers`) and a fire count
  per entry; each entry subscribes its own ticker. The relic's `cooldown` ticker is no longer used.
- `CombatManager.sim_step` checks each entry's ticker. A full one queues that entry, unless its
  limit (the entry's, or the relic's for an entry without its own effects) is reached. Queued relic
  entries fire after the items, in relic order then entry order. Two entries full in one step both
  fire.
- `_fire_item` takes the effects to fire; `Item.fire` gains an optional effects argument, default
  `def.effects`. Crit uses the relic's `crit_chance` for every entry. `Item.fires` still counts every
  fire, for the flash.
- Tooltip: each entry with its own effects is its trigger line followed by its effects and its limit.
  The entries without their own effects keep the current layout (their trigger lines, then the
  relic's effects, crit and limit). Passives come last.
- Keyword cards also look at the entries' effects.

### Outside fights (stage 3)

- New `RunEvent` values in the run manager: `PICKED_UP`, `FIGHT_WON`, `FIGHT_LOST`,
  `DRAFT_SKIPPED`. The run manager checks every relic's `run_triggers` when one happens.
- Run effects: `MAX_HP` (raises max and current HP), `HEAL`, `GOLD`. More are added as relics need
  them.
- Vital Charm becomes `{event: PICKED_UP, effect: MAX_HP, amount: 20}`. A `PICKED_UP` effect is
  applied once, on grant, and is not re-applied when a save is loaded, as today.

### Tooltip and display

- `TooltipContent.build(item)` works unchanged on a relic's `Item`. For a relic:
  - The charge line is empty and `TooltipPanel` hides the charge row.
  - The type line reads "Relic".
  - The trigger line names the event and is followed by the effect lines, for example "When
    [shield] is applied:" then "[heal] 2". "At the start of each fight:" for `FIGHT_START`.
  - A limited relic adds a line "Once per fight" (or "N times per fight").
  - All wording is placeholder copy for the owner to rewrite.
- Relic tokens on the sheet become inspectable: `CombatViewFramed.inspectable_at` and `_cell_for`
  also look at the relic tokens. During a fight the tokens hold the player's `relics` items; outside a
  fight they hold an `Item` built from each definition, as the draft does for items. `_sync_relics`
  rebuilds them when a fight starts or ends as well as when a relic is granted.
- Relic tokens set `ItemCell.show_cooldown = false`, since a relic has no bar to show.
- An enemy's relics are drawn in its item row (`EnemyHud`, through `CharacterPanel.build_items`),
  before its items. `EnemyHud._fit_cell_px` counts them when it shrinks the row.
- A relic token flashes when its relic fires, and its deliveries start from the token: `item_pos`,
  `_cell_for` and `inspectable_at` check the relic tokens as they do `_player_cells`; `CharacterPanel`'s
  `cell_centre`, `cell_at`, `item_at` and `cell_rect` (used by the enemy HUD) cover its relic cells.
- The reward panel's relic option uses `RewardOption.setup(Item.new(relic_def))` and the item
  tooltip, and `DraftOverlay.inspectable_at` stops skipping relic options.

### Save

Unchanged: the snapshot stores relic ids. Nothing a relic does in a fight is saved (decision #26).

## Stages

1. Definition, fight triggers, `FIGHT_START`, `DAMAGE_TAKEN`, `fires_per_fight`, enemy relics,
   tooltip, inspectable tokens and reward option, the firing flash. Stone Ward and Iron Idol are
   rewritten as `FIGHT_START` relics. Their shield now arrives as a delivery a few steps into the
   fight instead of before the first step, which can change fight results and autotest baselines.
2. Built 2026-09-29. The shared hook base class, `passives` and their registry, the attack bonus passive classes,
   bonuses for every mechanic, passive tooltip lines.
2b. Built 2026-09-29. Several triggers per relic, each with its own effects and limit.
3. Run events and run effects. Vital Charm is rewritten.
4. Health thresholds and rule changes, one at a time as relics are authored.

Each stage is its own change with its own tests and doc updates.

## Decisions to record

A new decision-log entry when stage 1 ships:

- A relic is an item without a timer. Amends #21 (the relic's runtime is now an `Item`, not a
  separate type) and `item.md`'s "no passive item type" section (relics are the exception; board
  items stay active).
- Amends #6: the run still owns the player's relics, but during a fight the player's `Actor` holds
  their items in `relics` (not on the board), so enemies can have relics the same way.
- #34 stands for now: relics carry no type tags until the owner decides otherwise.

## Docs to update

`docs/systems/content.md` (Relic section), `item.md`, `architecture.md`, `combat_manager.md` (the
relic list and new events), `tooltips.md`, `run_manager.md`, `run_screen.md` (the relics box),
`docs/design/authoring.md` (how to write a relic), `docs/design/lexicon.md` if a new term is
needed, `docs/decision_log.md`.

## Tests

- A relic fires on its trigger the next step, and not by time.
- `fires_per_fight` stops it after the limit and resets in the next fight.
- A relic's weapon attack does not use up an Empowered stack.
- `FIGHT_START` relics fire once per fight; `DAMAGE_TAKEN` publishes for status damage and hits.
- Board-wide targeting never picks a relic.
- A relic's fire does not charge an item that reacts to `ITEM_FIRED`; its poison does charge an item
  that reacts to poison being applied.
- An enemy relic from `EnemyDef.relic_ids` fires in a fight, and the enemy HUD draws it before the
  items.
- The tooltip builder for a relic: no charge line, "Relic" type line, trigger line.
- The sheet's hit test finds a relic token; the reward panel returns a relic option target.
- A weapon attack bonus passive raises a matching item's attack, including an item created during
  the fight, and not an item of another type or another actor.
- A passive is not listed in the status row, and removing or counting statuses never finds it.
- Passive tooltip lines match the item effect line for the same effect, and come after the
  trigger line and its effects.
- A content check fails for a passive whose mechanic has no passive class.
- Two trigger entries with their own effects each fire only their own effects; both fire when both
  events happen in one step; an entry's limit stops only that entry; an entry without effects still
  fires the relic's effects.
- The tooltip lists each entry's trigger line with its own effects.
- All on fixture relics (`FixtureContent`), not the authored ones.

## Open questions

- The trigger line and "Once per fight" wording.
- Allies' relics: not planned; allies have none.
- "Deal that much": a triggered effect whose value is the amount of the event that set it off. Events
  carry no amount today (`APPLIED` carries only the mechanic id); added when a relic needs it.

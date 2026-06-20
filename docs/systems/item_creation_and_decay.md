# Dark Corridor — Item Creation & Decay Support PRD

> **This is engineering work, NOT content — built by a building agent.**
> It specs two general engine capabilities the **Fleshmancer** character (design:
> [`../design/character_ideas.md` → *Flesh Golem / Meat*](../design/character_ideas.md))
> needs beyond the apply / tick / resolve model. The capabilities are **general**
> (any future character can make or expire items); they are named here for the driver. The
> chunk-of-flesh item, the attack commons that create it, the character def, and **all numbers**
> stay the **owner's content** (decision #23).

Content PRD's engine counterpart. Sits under the [Architecture Map](architecture.md).
Extends [`item.md`](item.md), [`combat_model.md`](combat_model.md), and
[`combat_manager.md`](combat_manager.md); adds **no new resolution model** (it reuses
fire → resolve → Delivery → land/fizzle). Same shape as [`spore_engine.md`](spore_engine.md).

**Engine:** Godot 4.
**Date:** 2026-06-19. **BUILT 2026-06-19** (Caps 1–2, create + decay; presentation flagged below lags).
**Extended 2026-06-20** (Caps 3–4: the `ITEM_DESTROYED` event + own-board consume, wired so consume-
death = decay-death; PRD: [`../plans/item_consume_and_destroy_event.md`](../plans/item_consume_and_destroy_event.md)).

Boundaries live in the hub: [architecture.md → Interface contracts](architecture.md#interface-contracts-boundary-hub).

---

## Purpose

The Fleshmancer's identity is an **item economy**: its attacks **create chunks of flesh** (small,
created items) that **decay** after a few activations — a churning board the player feeds by
spending HP. Two seams the spine lacked:

1. **Mid-fight item creation** — add an `Item` to a live board *during* combat.
2. **Item decay / limited use** — remove an item after a fixed number of activations.

**What needs NO engine work (author as content whenever — don't over-build):** the base **attack /
block commons** (a `DAMAGE` effect; self-block) — the built item subtypes; the chunk's **own
behaviour** — a `DAMAGE` effect on a cooldown is already the built weapon subtype. Only **creating**
the chunk and **expiring** it were new.

### Consistency with decision #23 — general seams, no baked chunk

Same discipline as [`spore_engine.md`](spore_engine.md): the engine gained a **new effect kind**, an
**`ItemEffect` field**, an **add-item verb**, and an **item-targeted use-status** — it hardcodes no
"chunk of flesh." *Which* item is created, *how many* activations it lasts, *what* it does, and all
numbers are `ItemDef` / `Balance`, authored by the owner.

---

## Capability 1 — Mid-fight item creation (a cousin of summon) — BUILT (2026-06-19)

> **Realized:** a new `Delivery.Kind.CREATE_ITEM` (beside `SUMMON`). `ItemEffect` / `Payload` /
> `Delivery` carry **`create_item_def_id`** (an `ItemCatalog` id), copied through `Payload.from_effect`
> and `_spawn_delivery` exactly as the summon fields are. Shape **`SELF`** → the created item lands on
> the **firing actor's own board**. `CombatManager.add_item(actor, def_id)` (the parallel of
> `add_actor`) builds `Item.new(...)`, resets its cooldown, appends it to `actor.board`, registers its
> Ticker + `trigger_subs` (shared helper `_register_item`), and seeds its decay (`_seed_item_uses`).
> Resolved at the Delivery's **land** in `_land` (the point `SUMMON` calls `add_actor`).
> **Combat-scoped:** created items are tracked in `_created_items` (mirroring `_player_tokens`);
> `teardown()` strips them from their (possibly run-scoped) board and dissolves them, so the run
> snapshot — taken between fights ([`save.md`](save.md)) — never serializes a created chunk. The
> player's *drafted* board is restored intact. **Determinism:** creation runs at Delivery-land inside
> the deterministic sweep — no RNG. **Robustness:** an unknown `create_item_def_id` (a content typo)
> is **logged and skipped** — `ItemCatalog.get_def` returns null, `add_item` guards it — never a
> crash mid-fight; the `SUMMON` twin (`_spawn_token`) was hardened the same way.

**Driver:** the attack commons' rider — "on fire, create a chunk of flesh on my own board."

**Presentation (flag — UI, lags the engine):** the board **grows mid-fight**, so the run-screen item
area must handle an added slot, and a created item wants an arrival tell. See
[`run_screen.md`](run_screen.md), [`ui_layout.md`](ui_layout.md). Not yet drawn.

**Open / to decide when content needs it:**

- **Board capacity:** no max board size is enforced today (a create always appends). If the design
  wants a cap, decide the full-board behaviour (drop / queue / replace-oldest) with the owner.
- **Ordering:** created items append to the end. For the player's *own* items, board order is
  presentation / draft-order only (targeting is actor-level; items don't body-block), so there is no
  summon-style front-insert decision.

---

## Capability 2 — Item decay / limited use (an item-targeted use-status) — BUILT (2026-06-19)

> **Realized:** a `DecayStatus` (`StatusEffect` subclass, id `'decay'`) + one `StatusRegistry` line.
> State = `count` (activations remaining); not time-driven (no ticker), not damage-consumed (not
> block's `absorb`) — **drained by the holder item's fire**. Reapply **stacks** (the base default =
> "top up"). `ItemDef.starting_uses: int = 0` is the authoring seed: `_seed_item_uses` applies Decay
> with `count = starting_uses` at item birth (fight start, or `add_item` for a created chunk); 0 =
> unlimited. **Drain in the fire pipeline:** `CombatManager._fire_item` calls `_drain_uses(it)` AFTER
> spawning the item's payloads, which invokes a new `StatusEffect.on_holder_fired(item, ctx)` hook;
> `DecayStatus` decrements there and, at 0, calls `ctx.remove_item(item)` — so the final activation
> still lands ("decay 2" = two full hits, then removal). **Removal path** (`CombatManager.remove_item`,
> the genuinely new plumbing Cap 1 reuses): drop the item from `actor.board` + the swept `_items` set,
> `bus.unsubscribe` its triggers, and `Item.dissolve()` it (the single-item cycle break beside
> `Actor.dissolve()`). **`StatusContext` realized** (the reserved `ctx`): a minimal class with one
> `remove_item(item)` capability the Combat manager fulfils. **Determinism:** decrement + removal are
> deterministic per-fire steps — no RNG.

**Driver:** the chunk decays after N activations ("decay 2" — fires twice, then gone). Generalized to
a manipulable limited-use status: apply to *any* item, set *any* count, *top up* (reapply stacks).
Name **Decay** (the destroy-on-use status; reads on flesh *rots away* and non-flesh *wears out* alike;
flavour rides the *item* name, not the keyword).

A sibling mechanic, **ammo**, would be a **separate** status (same count-drained-by-firing shape, but
empties to **silence + reload** rather than **destroy**). Decay, ammo, and block form a family
(count-pools drained by an event, differing in drain-event and what-they-remove) — they share the
pattern, not the status. One destroy-on-use status (Decay) is reused across characters.

**The model — block's twin** (the structural parallel that made this small):

| | lives on | drained by | when empty |
|---|---|---|---|
| **block** (built) | an Actor | incoming damage (`absorb`) | removes itself |
| **decay** (this) | an Item | that item firing (`on_holder_fired`) | removes **the item** |

The item-targeted half of the status system's dual Actor/Item targeting ([`status_manager.md`](status_manager.md))
makes the dynamic cases fall out for free — apply decay to another item; set any count; top up = reapply.

**Considered & rejected — a fixed `decay: int` field on the item.** Simpler, but it bakes decay as an
intrinsic authoring fact (no apply-to-others, no vary-count, no top-up without bespoke code, and a
field→status migration the moment a second decay effect is authored). The status is the right home; the
def's `starting_uses` keeps the simple-authoring upside.

**Loop / cascade note:** items that create items invite cascades, but accrual-only triggers are
loop-proof by construction (the Bazaar lesson, [`combat_model.md`](combat_model.md): a chain advances
at most one link per step), and decay + the design's HP cost are the governors. No special loop guard
is needed — a create→create chain cannot run away within a step (the created item is registered after
the current step's cooldown pass, so it first ticks next step).

**Presentation (flag — lags the engine):** the item panel / cooldown ring should show activations
remaining ([`tooltips.md`](tooltips.md)); removal wants a dissolve tell. Decay's activations-left
renders like block's count. Not yet drawn.

---

## Capability 3 — `ITEM_DESTROYED` event (the charge-on-destroy hook) — BUILT (2026-06-20)

> **Realized:** a new `EventBus.Event.ITEM_DESTROYED`, published in `CombatManager.remove_item` —
> `bus.publish(ITEM_DESTROYED, it.def.id, it.owner, it)` — **before** the item's `bus.unsubscribe` /
> `Item.dissolve()`, so the bus still routes the event to the **other** items. **Source = the destroyed
> item's owner**, so `OWN_SIDE` trigger filtering works ("when *my* item dies", decision #30). The
> trigger side needs no new code: an item subscribes `{ event: ITEM_DESTROYED, amount: … }` like any
> other trigger (the push `amount` is a fraction of the cooldown bar, `combat_model.md`). The optional
> `filter` can later narrow by destroyed item def id (`it.def.id` is the published data).

**Driver:** a charge-on-destroy item — "whenever one of your items is destroyed, charge."

**Teardown guard:** `remove_item` runs mid-fight (decay / Cap-4 consume) **and** as the combat-scoped
strip during `teardown()`. A fight ending is **not** a "destroy" for triggers, so the publish is
suppressed once `_resolved` (the flag `add_item` guards on; teardown also nulls `bus`, the redundant
backstop). **Determinism:** published in the deterministic removal path — no RNG.

## Capability 4 — Own-board item-consume (the Mass-twin) — BUILT (2026-06-20)

> **Realized:** `ItemEffect` / `Payload` carry **`consume_item_def_id`** / **`consume_item_amount`** /
> **`consume_item_scale`**, copied through `Payload.from_effect` exactly as the `consume_*` (status) /
> `summon_*` / `create_item_def_id` fields are. Resolved in **`CombatManager._fire_item`** (item-removal
> lives on the manager; `Item` stays downward-clean — the exact parallel of opponent-fuel Mass,
> `spore_engine.md` Cap 1): before spawning each payload's deliveries, `_consume_board_items` counts the
> owner's matching board items, removes up to `consume_item_amount`, and scales the payload value by the
> count (`+= count * consume_item_scale`). It iterates a **copy** of the board (removal mutates it
> mid-pass, cf. `_drain_uses`). **`consume_item_amount <= 0` = consume ALL present**; `> 0` = up to that
> many. A no-fuel consume is a safe no-op. **Determinism:** the count/remove sweep is deterministic —
> no RNG.

**Driver:** a "consume your chunks for a scaling effect" payoff (the Mass-payoff feel on board items).

### The synergy — the critical wiring (why Caps 3 & 4 ship together)

Capability 4 removes its consumed items **via `CombatManager.remove_item`** (the Capability-3-publishing
path), **never a silent `board.erase`** — so each consumed item publishes `ITEM_DESTROYED`. A charge-on-
destroy item (Cap 3) therefore charges off **both** *passive decay* and *active consume* with no extra
code: **consume-death and decay-death are the same event.** Passive decay is a charge *trickle*; active
consume is a deferred charge *burst*; the decay clock is the dial between them. This constraint is the
point of building the two together.

**Loop-safety:** a big consume + several charge items spikes (eat 6 → 6 pushes → a payoff fires), but
it is loop-safe **by construction** — accrual-only triggers land *next tick*, no within-step recursion
(the Bazaar lesson, [`combat_model.md`](combat_model.md)). It is the power ceiling to watch in `/tune`;
**no** loop guard is added.

**Open / deferred:** the destroyed-item trigger `filter` (narrowing a charge by *which* def died) is
not yet needed; all numbers (charge fractions, consume amounts, scaling) are content (`ItemDef` /
`Balance`); no flesh content is baked — only the seams + tests ship.

---

## Testing (built)

- **GUT units** ([`tests/combat/test_status_effect.gd`](../../tests/combat/test_status_effect.gd)):
  the registry builds Decay; it drains one per fire and asks `ctx` to remove the host item at 0;
  reapply tops up charges.
- **GUT integration** ([`tests/combat/test_combat_manager.gd`](../../tests/combat/test_combat_manager.gd)):
  `starting_uses` seeds the status (and 0 seeds nothing); decay drains per fire and removes the item
  after the last hit lands (deregistered from the sweep); a self-limiting decay attack stops after its
  uses (no runaway); `add_item` appends + registers a working Ticker and the created item fires;
  `CREATE_ITEM` lands an item on the firer's own board; created items are stripped at teardown
  (drafted board restored / snapshot clean). **Caps 3 & 4:** `ITEM_DESTROYED` fires on a decay-destroy
  with the owner as source; it does **not** fire at teardown; a `trigger_subs` item charges off it one
  step later; own-board consume counts / removes / scales, respects the amount cap, and a no-fuel
  consume is a safe no-op; the consumed items publish `ITEM_DESTROYED` (the synergy).
- **Autotest E2E:** still owner-driven content — a temporary chunk-creating attack run is the
  remaining E2E check, deferred to the Fleshmancer content build.

---

## Then content (owner, not this PRD)

The chunk-of-flesh `ItemDef` (a `DAMAGE` effect, cooldown, `starting_uses`); the attack commons with a
`CREATE_ITEM` effect; the Fleshmancer `CharacterDef` + item pool; `Balance` numbers.

## Open / deferred

- **Board capacity** behaviour on a full board (Cap 1) — owner call; unbounded today.
- **Activations-left display** + arrival / dissolve tells — presentation, not yet drawn.
- **Autotest draft-strategy classification (when CREATE_ITEM content is authored):** the draft
  strategy's family classifier (`AutoTestDriver._family_of`) keys off an item's *primary* effect
  (`effects[0]`) → `damage` / `block` / `poison` / `heal` / `status` / `other`. A `CREATE_ITEM`-*primary*
  item falls to `'other'`, so the family strategies won't prefer it — **parallel to SUMMON's current
  gap** (it falls to `'other'` too). A damage-attack-*with*-a-create-rider is unaffected (its primary
  effect is `DAMAGE`). When create-primary content exists, give `CREATE_ITEM` (and SUMMON) a family in
  `_family_of`. Code left unchanged — nothing needs it until then (owner, 2026-06-19). See
  [`autotest.md`](autotest.md).
- **`StatusContext` scope** — minimal (`remove_item`); add `apply_status` / `spawn` / `publish` / `rng`
  only as later statuses need them (the no-speculative-surface discipline).
- **All numbers** (chunk damage / cooldown, decay counts, HP costs) are content — `ItemDef` / `Balance`.

## Dependencies

- **Delivery / combat_model** — reuses fire → resolve → Delivery → land/fizzle; Cap 1 adds `CREATE_ITEM`.
- **Item** — `create_item_def_id` on a def; `starting_uses`; the fire pipeline drains the holder's
  decay (`_drain_uses` → `on_holder_fired`); `Item.dissolve()` (single-item cycle break).
- **StatusManager / StatusEffect** — the item-targeted **DecayStatus** (drained by the holder's fire,
  removes the item at 0) seeded from `starting_uses`; **`StatusContext`** realized as a minimal
  `remove_item` seam (the reserved `ctx`); the `on_holder_fired` hook.
- **Combat manager** — `add_item` + `CREATE_ITEM` resolution at land; `remove_item` (the individual-
  item removal that fulfils `ctx.remove_item`, now also **publishing `ITEM_DESTROYED`**, teardown-
  guarded); `_created_items` combat-scoped tracking + teardown strip; **`_consume_board_items`** (Cap 4,
  count + `remove_item` + scale, called from `_fire_item`).
- **EventBus** — the new `Event.ITEM_DESTROYED` (Cap 3); the trigger machinery (`trigger_subs` + the
  bus route) is reused unchanged — a charge item just subscribes the new event.
- **Driven by content:** the owner's chunk `ItemDef` + Fleshmancer commons exercise these seams (the
  chunk, a charge-on-destroy item, and the consumer items + all numbers stay owner content).

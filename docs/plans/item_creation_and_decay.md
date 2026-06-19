# Dark Corridor — Item Creation & Decay Support PRD

> **This is engineering work, NOT content — a building agent should implement it.**
> It specs two general engine capabilities the **Fleshmancer** character (design:
> [`../design/character_ideas.md` → *Flesh Golem / Meat*](../design/character_ideas.md))
> needs beyond the current apply / tick / resolve model. The capabilities are **general**
> (any future character can make or expire items); they are named here for the driver. The
> chunk-of-flesh item, the attack commons that create it, the character def, and **all numbers**
> stay the **owner's content** (decision #23).

Content PRD's engine counterpart. Sits under the [Architecture Map](../systems/architecture.md).
Extends [`item.md`](../systems/item.md), [`combat_model.md`](../systems/combat_model.md), and
[`combat_manager.md`](../systems/combat_manager.md); adds **no new resolution model** (it reuses
fire → resolve → Delivery → land/fizzle).

**Engine:** Godot 4.
**Date:** 2026-06-19. **Deferred capability — not yet built.** Build alongside the content that
needs it (coordinate with the owner — see *Build order*).

Boundaries live in the hub: [architecture.md → Interface contracts](../systems/architecture.md#interface-contracts-boundary-hub).
Hub entries get added **when each capability is built** (forward spec, like the pre-prototype PRDs).

---

## Purpose

The Fleshmancer's identity is an **item economy**: its attacks **create chunks of flesh** (small,
created items) that **decay** after a few activations — a churning board the player feeds by
spending HP. Two seams the spine lacks:

1. **Mid-fight item creation** — add an `Item` to a live board *during* combat.
2. **Item decay / limited use** — remove an item after a fixed number of activations.

**What needs NO engine work (author as content whenever — don't over-build):**

- The base **attack / block commons** (a `DAMAGE` effect; self-block) — the built item subtypes.
- The chunk's **own behaviour** — a `DAMAGE` effect on a cooldown is already the built weapon
  subtype. Only **creating** the chunk and **expiring** it are new.

**Is:** two capabilities — (1) a way to put a new `Item` on a board mid-fight, (2) a use-counter
that removes an item after N fires.

**Is not:** the chunk / commons / character / numbers (content — owner's); a new resolution model;
the draft / draftable layer.

### Consistency with decision #23 — general seams, no baked chunk

Same discipline as [`spore_engine.md`](../systems/spore_engine.md): the engine gains a **new effect
kind**, an **`ItemEffect` field**, an **add-item verb**, and an **item-targeted use-status** — it hardcodes no
"chunk of flesh." *Which* item is created, *how many* activations it lasts, *what* it does, and all
numbers are `ItemDef` / `Balance`, authored by the owner. The engine learns to express what content
chooses; it bakes nothing.

---

## Capability 1 — Mid-fight item creation (a cousin of summon)

**Driver:** the attack commons' rider — "on fire, create a chunk of flesh on my own board."

**Current state (confirmed by code, 2026-06-19):** there is **no runtime item-board mutation**.
Items are fixed on `actor.board` at loadout (`run_manager.gd`, `encounter.gd`). The only mid-fight
spawn is a **summon**, which adds a whole **`Actor`** (`CombatManager.add_actor` / `_spawn_token`),
not an item. So item creation is genuinely new — but it has a near-exact precedent to mirror.

**The work (mirror the `SUMMON` path — the doc already calls item-creation "a cousin of
roster-add"):**

- A new **`Delivery.Kind.CREATE_ITEM`** (beside `SUMMON`) in `delivery.gd`.
- `ItemEffect` gains **`create_item_def_id: String`** (an `ItemCatalog` id) — the parallel of
  `summon_def_id`. Copied through `Payload` and `Delivery` exactly as the summon fields are.
- Target-shape **`SELF`** → the created item lands on the **firing actor's own board** (as `SUMMON`
  shape `SELF` spawns on the summoner's side).
- A **`CombatManager.add_item(actor, def_id)`** verb, the parallel of `add_actor`: build
  `Item.new(ItemCatalog.get_def(def_id), actor)`, append to `actor.board`, and **register its
  Ticker + `trigger_subs`** with the central tick / event bus (the same registration items get at
  fight start, and that `add_actor` performs for a token's board). Resolved at the Delivery's
  **land** in the Combat manager — the point where `SUMMON` calls `add_actor`.
- **Combat-scoping — the key correctness point.** A created item is **combat-scoped**: it must be
  removed at `teardown()` and **never serialized into the run snapshot** ([`save.md`](../systems/save.md)).
  The player actor's *drafted* board is run-state; naively appending a created item to it would
  pollute the save. Track created items as combat-scoped (mirror how `_player_tokens` are
  combat-scoped vs. run-scoped `allies`) so teardown strips them and the snapshot ignores them.
- **Determinism:** creation runs at Delivery-land inside the deterministic sweep — no RNG.

**Presentation (flag — UI, can lag the engine):** the board **grows mid-fight**, so the run-screen
item area must handle an added slot, and a created item wants an arrival tell. See
[`run_screen.md`](../systems/run_screen.md), [`ui_layout.md`](../systems/ui_layout.md). The tell
itself is presentation/content.

**Open / to decide when built:**

- **Board capacity:** is there a max board size? If so, what happens when a create lands on a full
  board — drop the create, queue it, or replace the oldest chunk? A design call; decide with the owner.
- **Ordering:** created items append to the end. For the player's *own* items, board order is
  presentation / draft-order only (targeting is actor-level, items don't body-block), so there is no
  summon-style front-insert decision — confirm this holds.

---

## Capability 2 — Item decay / limited use (an item-targeted use-status)

**Driver:** the chunk decays after N activations (owner's example: "decay 2" — it fires twice, then
is gone). Generalized to a **manipulable limited-use** status: uses you can apply to *any* item, set
to *any* count, or *top up* (the design wants all three). Name: **Decay** (resolved with the owner,
2026-06-19) — the destroy-on-use status; reads on flesh (*rots away*) and non-flesh (*wears out*)
alike. Flavour (e.g. "wither") rides the *item* name, not the status keyword.

A sibling mechanic, **ammo**, would be a **separate** status, *not* this one reused (owner,
2026-06-19): same count-drained-by-firing *shape*, but a different **empty-behaviour** — ammo
**silences + reloads** the item; decay **destroys** it. Decay, ammo, and block form a family
(count-pools drained by an event, differing in drain-event and what-they-remove) — they share the
pattern, not the status. Keep **one** destroy-on-use status (Decay) reused across characters rather
than per-theme clones, so the player learns one keyword (the complexity budget).

**Current state (confirmed, 2026-06-19):** **no use-counter / lifespan** exists on items or summons;
items fire forever until their owner is reaped or combat ends. Removing a **single live item** while
its owner still lives **does not exist** — items leave only at owner-death or teardown.

**The model — decay is an item-targeted "use" status, NOT a fixed field (resolved with the owner,
2026-06-19).** It is structurally **block's twin**: block is a *pool of count on an Actor, drained by
incoming damage, that removes itself when empty*; the use-status is a *pool of count on an Item,
drained by that item firing, that removes the **item** when empty*. This rides the status system's
dual Actor/Item targeting (the key extension over Spire — [`status_manager.md`](../systems/status_manager.md))
and the dynamic cases fall out for free — apply decay to another item; set any count; top up = reapply
(stacks by default).

| | lives on | drained by | when empty |
|---|---|---|---|
| **block** (built) | an Actor | incoming damage (`absorb`) | removes itself |
| **use / decay** (this) | an Item | that item firing | removes **the item** |

**The work:**

- **A `StatusEffect` subclass — the use-status** (id e.g. `'decay'`): one class file + one
  `StatusRegistry` line (the authoring pattern). State = `count` (activations remaining). Not
  time-driven (no Ticker) and not damage-consumed (not block's `absorb`) — **drained by the holder
  item's fire**, the way block's pool is drained by the damage pass. Reapply **stacks** by default
  (= "add charges"). Combat-scoped like every status (#26).
- **`ItemDef` gains a starting count — the authoring seed:** a field like **`starting_uses: int = 0`**
  (0 = unlimited / never decays). It is *just a seed*: when the item is created (at fight start for
  drafted items, or via `add_item` for created chunks), if `starting_uses > 0` the engine applies the
  use-status to it with `count = starting_uses`. Authoring stays one number; the live thing is the
  status. *(An item "born carrying a status" is mildly new — item-targeted statuses are applied
  during a fight today; seeding one at item birth is a small addition to the create/loadout path.)*
- **Drain in the fire pipeline** ([`item.md`](../systems/item.md)): the item **fires and resolves its
  payload first**, then the pipeline **decrements its use-status** by 1 — so the final activation
  still lands ("decay 2" = two full hits, then removal). The fire pipeline **already consults an
  item's own statuses** (gates in step 1, value-modifiers in step 3), so this is one more consultation
  in that same place — **not** a new event-subscription hook.
- **A new individual-live-item removal path** (the genuinely new plumbing, needed by Cap 1 too): when
  the use-status empties, **remove the item** — drop it from `actor.board`, **deregister its Ticker +
  triggers** (mirror the dead-actor reap that stops a reaped actor's items firing), and **dissolve it
  to break the `Item`↔`Actor` reference cycle** ([`actor.md`](../systems/actor.md); verify
  `Actor.dissolve()` covers a single item, or add an item-level dissolve). Cap-1's combat-scoped
  teardown strip converges on this same path.
- **This is the case that fleshes out `StatusContext`.** Today `ctx` is `null` everywhere and the
  class doesn't exist, because no status needed to act beyond its target — the status PRD reserves it
  for exactly "a status that spawns / removes." The use-status emptying → "remove my host item" *is*
  that case: introduce a **minimal `StatusContext` with a `remove_item(item)`** capability the Combat
  manager fulfils. *(The fire pipeline could remove the item directly as a simpler alternative;
  `ctx`-driven is the more general, on-grain answer and is recommended.)*
- **Determinism:** the decrement + removal are deterministic per-fire steps in the sweep — no RNG.

**Considered & rejected — a fixed `decay: int` field on the item.** Simpler, but it bakes decay as an
intrinsic authoring fact: you couldn't apply it to other items, vary the count, or top it up without
bespoke code, and you'd face a field→status migration the moment a second decay effect is authored.
The owner wants those dynamics, so the status is the right home now (the def's `starting_uses` keeps
the simple-authoring upside).

**Loop / cascade note:** items that create items invite cascades — but accrual-only triggers are
**loop-proof by construction** (the Bazaar lesson, [`combat_model.md`](../systems/combat_model.md):
a chain advances at most one link per tick), and decay + the design's HP cost are the governors. No
special loop guard should be needed; the implementer confirms a create→create chain cannot run away
within a single tick.

**Presentation (flag):** the item panel / cooldown ring should show **activations remaining**
([`tooltips.md`](../systems/tooltips.md) / the item panel), and removal wants a dissolve tell.

---

## Build order (recommendation)

Each test-first, its own green commit, the headless autotest as the regression backstop
([`autotest.md`](../systems/autotest.md), handoff rhythm):

1. **Capability 2 (decay use-status)** — testable on **any existing item** by giving its def
   `starting_uses = N` (or applying the use-status directly). Delivers the use-status, the
   fire-pipeline drain, the minimal `StatusContext`, and the individual-item-removal path Cap 1 reuses.
2. **Capability 1 (creation)** — the bigger piece (new kind + `add_item` + combat-scoping +
   growing-board presentation); reuses step 1's removal path for the teardown strip.
3. **Then content (owner, not this PRD):** the chunk-of-flesh `ItemDef` (a `DAMAGE` effect,
   cooldown, `decay`); the three attack commons with a `CREATE_ITEM` effect; the Fleshmancer
   `CharacterDef` + item pool; `Balance` numbers.

---

## Testing

- **GUT units:** the use-status drains one per fire and removes its host item at 0 *after* the last
  hit lands; reapplying adds charges (count goes up); a use-status applied to an arbitrary item makes
  it decay; `starting_uses` on a def seeds the status at creation; a removed item stops being ticked
  and stops emitting / receiving trigger events; `add_item` appends and registers a working Ticker; a
  created item fires; created items are gone after `teardown()` and **absent from a round-trip snapshot**.
- **Autotest E2E:** a temporary build with a chunk-creating attack runs a fight; the report shows
  the chunk's fires / damage and a board that grows then shrinks. Confirms determinism / no runaway.

---

## Dependencies / files touched

- **`delivery.gd`** — new `Kind.CREATE_ITEM`.
- **`item_effect.gd` / `payload.gd`** — `create_item_def_id`, copied through to the Delivery.
- **`item_def.gd`** — `starting_uses` seed field. **`item.gd`** — fire-pipeline drain of the
  use-status (decrement after the payload resolves; request removal at 0).
- **The use-status `StatusEffect` subclass + `StatusRegistry`** — new status class (id `'decay'`) +
  its one registration line; the seed-on-create application from `starting_uses`.
- **`StatusContext` (new, minimal)** — realize the reserved `ctx` seam with a `remove_item(item)`
  capability the Combat manager fulfils (passed into the use-status's hook).
- **`combat_manager.gd`** — `add_item` (append + register Ticker/triggers); resolve `CREATE_ITEM` at
  land; the individual-item removal (deregister + dissolve) that `ctx.remove_item` calls;
  combat-scoped tracking + teardown strip.
- **`actor.md` / dissolve** — single-item reference-cycle break (verify coverage or add it).
- **save** — created (combat-scoped) items excluded from the run snapshot.
- **Presentation** (`run_screen` / item panel / `tooltips` / `vfx`) — growing board, the use-status's
  activations-left readout (it renders like block's count), arrival + dissolve tells. Presentation may
  lag the engine; the seams land first.
- **autotest report** — created-item attribution.

---

## Open / deferred

- **Board capacity** behaviour on a full board (Cap 1) — owner call.
- **Activations-left display** + arrival / dissolve tells — presentation.
- **`StatusContext` scope** — start minimal (`remove_item`); add `apply_status` / `spawn` / `publish`
  / `rng` only as later statuses need them (the PRD's incremental, no-speculative-surface discipline).
- **All numbers** (chunk damage / cooldown, decay counts, HP costs) are content — `ItemDef` /
  `Balance`, never this doc (docs describe systems, not numbers — `CLAUDE.md`).

## Dependencies

- **Delivery / combat_model** — reuses fire → resolve → Delivery → land/fizzle; Cap 1 adds a kind.
- **Item** — declares `create_item_def_id` on a def; declares `starting_uses`; the fire pipeline
  drains the holder's use-status.
- **StatusManager / StatusEffect** — a new item-targeted **use-status** (drained by the holder's
  fire, removes the item when empty), seeded from `starting_uses`; **`StatusContext`** realized as a
  minimal `remove_item` seam (the reserved `ctx`).
- **Combat manager** — `add_item` + `CREATE_ITEM` resolution at land; the individual-item removal
  (fulfils `ctx.remove_item`); combat-scoped tracking. The driver content (the owner's chunk
  `ItemDef` + Fleshmancer commons) is what exercises these seams; this PRD is the engine they run on.
- Hub interface-contract entries added when each capability is built.

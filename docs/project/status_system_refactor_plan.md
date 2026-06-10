# Status System Refactor — Implementation Plan

> **✅ LANDED 2026-06-10** — all phases complete; 251 GUT tests green, full-descent autotest wins.
> The canonical record is now decision-log **#29** + the rewritten [`status_manager_prd.md`](status_manager_prd.md).
> This plan can be deleted; kept briefly for reference. Not in the docs index.
>
> Captures the agreed redesign of the status system from a centralized data rulebook to
> polymorphic per-status classes (the Slay-the-Spire `AbstractPower` model).

## Goal

Move statuses from **one shared `StatusDef` per type + a `StatusManager` that switches on
`shape`** to **a class per status that owns its own state and behaviour via hooks**. Scales to
many statuses with wildly different effects; kills the "duration is global" bug as a side effect.

### Ratified decisions (this session)
1. **Hooks receive `(target, ctx)`** — a status stores **no** target reference (preserves the
   no-back-reference / no-RefCounted-cycle invariant in `status.gd`).
2. **String-id statuses now** (#23 extended to statuses) — the `StatusDef.Type` enum is removed;
   statuses are keyed by string id like items/relics.
3. **Reapply default = stack (additive)** — re-applying an existing status adds to it; classes
   override for refresh/max. (For timed statuses the additive analog is *extend the duration* —
   see Reapply model below.)

---

## Target architecture

```
Status (base, evolve src/combat/status.gd)         # state + no-op/identity hooks
├── TimedStatus        # owns a duration Ticker, expiry, extend-on-reapply
│   ├── WeakStatus           id 'weak'        modify_outgoing
│   ├── VulnerableStatus     id 'vulnerable'  modify_incoming
│   └── BlindStatus          id 'blind'       causes_evasion
├── PeriodicStatus     # tick cadence + per-tick decay + item-target guard
│   └── PoisonStatus         id 'poison'      on_step → take_damage; is_fuel; dot_tick_weight
├── PoolStatus         # absorb pool
│   └── BlockStatus          id 'block'       absorb
├── SilenceStatus      id 'silence'           gates_fire   (static, no ticker)
└── SporesStatus       id 'spores'            is_fuel       (inert counter)
```

- **`StatusRegistry`** (replaces `StatusCatalog`): `id → creator` map, one registration line per
  status (behaviour lives per-file; full self-registration deferred). `create(id) -> Status`.
- **`StatusContext`** (new, thin): the only surface a status may touch from a hook — `apply_status`,
  `spawn_token`, `publish_event`, `rng`, `timekeeper`. Built and handed in by the CombatManager.
  Starts minimal; grows as statuses need more. `null`-tolerant for apply-outside-combat.
- **`StatusManager`** stays the **facade** the engine calls; its bodies become delegation loops over
  `target.statuses`. The engine **stops naming statuses** — `type == BLOCK` → `status.absorb(...)`,
  the fuel-shape check → `status.is_fuel()`.
- **Deleted:** `StatusDef` (data absorbed into classes), `StatusCatalog`, `StatusDef.Type` enum,
  `StatusDef.Shape` enum.

## Hook contract (the status interface)

| Concern | Hook | Default |
|---|---|---|
| first-time setup | `on_apply(target, ctx)` | no-op |
| expiry side-effect | `on_expire(target, ctx)` | no-op |
| re-application | `reapply(count, duration, source, flags)` | **additive count** (timed: extend duration) |
| per-step active effect | `on_step(target, ctx) -> bool expired` | `false` |
| outgoing damage (Weak) | `modify_outgoing(amount, target, ctx) -> float` | identity |
| incoming amplify (Vulnerable) | `modify_incoming(amount, target, ctx) -> float` | identity |
| absorb (Block) | `absorb(amount, flags, target, ctx) -> float remaining` | identity |
| gate a fire (Silence) | `gates_fire() -> bool` | `false` |
| evasion (Blind) | `causes_evasion() -> bool` | `false` |
| Mass fuel | `is_fuel() -> bool` + `count` | `false` |
| presentation | **fields** `name_key: String`, `color: Color`, `icon: String` (typed on the base, set by plain assignment in each class's `_init`) | '' / white / '' |
| autotest DoT attribution | `dot_tick_weight() -> float` | `0.0` (PoisonStatus: `count × per-tick`) |

> **Presentation are fields, not methods — POT depends on it.** `tools/extract_pot.gd` scans for
> `name_key\s*=\s*'...'` *assignments*; a `func name_key() -> String: return 'Weak'` would NOT be
> extracted. So each class sets `name_key = 'Weak'` (plain assignment in `_init`) against a
> base-declared `var name_key: String = ''` — satisfies static typing AND keeps POT working with no
> extractor change. (If presentation ever moves to methods/consts, widen the extractor regex.)

**Pull vs push:** modifiers (`modify_*`, `absorb`, `gates_fire`, `causes_evasion`) are PULL — the
engine queries them at the precise pipeline stage, in `target.statuses` array order, preserving
determinism (#24) and amplify-before-absorb (#6). Active effects (`on_step`, `on_expire`) are PUSH —
the status acts via `ctx`.

## Apply / reapply model

`StatusManager.apply(target, id, count, duration, source, flags, ctx = null) -> Status`
- existing of same `id` on target → `existing.reapply(count, duration, source, flags)`
- else → `StatusRegistry.create(id)`, set state, `on_apply(target, ctx)`, append.

Reapply defaults (ratified **stack**):
- Base (`PoolStatus`/`PeriodicStatus`/`SporesStatus`): `count += incoming.count`.
- `TimedStatus`: extend remaining — `ticker` gains `from_seconds(incoming.duration)` worth (the
  timer analog of stacking; matches the design's "applications extend duration"). Classes may
  override to refresh-to-new or max.

This is where **per-application duration** lives — `duration` is a constructor/apply argument, not a
global on a def. The original bug is gone.

---

## Migration — exhaustive call-site list (from grep)

### Data carriers (type changes)
- `Status` (instance): `type: int → id: String`. (Every `s.type == StatusDef.Type.X` becomes
  `s.id == 'x'`, including the test helpers `_find` / `_has_status`.)
- `ItemEffect`: `status_type: int → status_id: String`; `consume_type: int → consume_id: String`;
  **add** `duration: float`. Sentinels `-1 → ''`.
- `Payload`: same three.
- `Delivery`: `status_type → status_id`; **add** `duration`.
- `RelicDef`: `status_type → status_id`; **add** `status_duration: float`.

### Engine
- `status_manager.gd` — full rewrite to the facade (apply/advance/resolve_incoming/outgoing/
  has_evasion/consume all delegate). New `apply` signature. (`info()` has **no callers** — drop it,
  or reduce to reading the instance's `name_key`/`color` if the UI later wants it.)
- `combat_manager.gd` — `apply` call at land (pass `status_id`, `duration`, `ctx`); DoT-tick visual
  Delivery color via `status.color()` (was `StatusCatalog.get_def(...).color`); consume calls use
  `consume_id`; `STATUS_APPLIED` event payload becomes the string id; trigger-filter compare.
- `item.gd` — `_is_gated` via `status.gates_fire()`; `outgoing_damage_mult`; consume id.
- `run_manager.gd` — relic apply passes `status_id` + `status_duration`.
- `event_bus.gd` — **the trigger filter is typed `int`** (`subscribe(..., filter: int = -1)`, guard
  `filter >= 0 && filter != data`). The `STATUS_APPLIED` payload is now a string id, so `filter`
  becomes a Variant defaulting to `null`, guard `filter != null && filter != data`. Callers:
  `combat_manager.gd:115` (`sub.get('filter', -1) → null`), `item_def.gd` doc comment,
  `auto_test_driver.gd` (`int(sub.get('filter', -1)) → sub.get('filter', '')`), and the avenger
  `trigger_subs` filter literal.

### Content
- `item_catalog.gd` — 10 status/consume references → string ids (`'block'`, `'poison'`, `'weak'`,
  `'vulnerable'`, `'silence'`, `'blind'`, `'spores'`); set `duration` on timed appliers (Wilt Frond
  `2.0`, Pocket Shrooms blind, Sunder vulnerable, etc.).
- `relic_catalog.gd` — `'block'` + `status_duration` (0 = pool, no timer).
- Avenger `trigger_subs` `'filter'`: `StatusDef.Type.POISON → 'poison'`.

### UI / presentation
- `enemy_hud.gd` `_status_color` — drop the hardcoded `match status.type`; use `status.color()`.

### Autotest
- `auto_test_mode.gd` `_dot_sources_of` / `_dot_label` — replace `def.shape == PERIODIC &&
  damage_per_tick` + `def.name_key` with `status.dot_tick_weight()` + `status.name_key()`.
- `auto_test_driver.gd` — `_status_applied_by` / `_board_applies_status` / family `match` and the
  `greedy-synergy` filter: `status_type int → status_id String`; sentinel `-1 → ''`; family map
  `BLOCK/POISON → 'block'/'poison'`.

### Registry / catalog
- `StatusCatalog → StatusRegistry`.

### Localization
- Status `name_key`s move from `StatusCatalog` into the classes. **Resolved:** the extractor scans
  `.gd` for `name_key = '...'` assignments (not catalog enumeration), so setting `name_key = 'Weak'`
  in each class's `_init` keeps extraction working — no extractor change. (See the presentation note
  above.) Run the POT pipeline after the move and diff `messages.pot` to confirm all 7 names persist.

### Tests
- `test_status_manager.gd` — rewrite to the new model (apply signature, instance hooks).
- `test_combat_manager.gd` — ~20 `StatusDef.Type` refs → ids; `consume_type`; trigger filter.
- `test_item.gd`, `test_run_manager.gd`, `test_relic.gd` — id swaps + relic `status_duration`.

---

## Execution order (green checkpoints)

The enum removal forces every call site, so there is a red window. Sequence to keep it short:

1. **Framework files** — `status.gd` (base), `TimedStatus`/`PeriodicStatus`/`PoolStatus`, the 7
   concrete classes, `StatusRegistry`, `StatusContext`. `--import` to register the `class_name`s.
2. **Rewrite `StatusManager`** to delegate; new `apply` signature.
3. **Data carriers** — `ItemEffect`/`Payload`/`Delivery`/`RelicDef` to string-id + duration.
4. **Call sites** — content, engine, UI, autotest (the lists above).
5. **Delete** `StatusDef` + `StatusCatalog` + enums.
6. **Tests** — rewrite/fix.
7. **Verify** — `--import`, full GUT, a headless autotest smoke (`--nosave --notutorial
   --single-fight`), fix to green.
8. **Docs** — `status_manager_prd.md` (model flip), `authoring.md` (statuses are now file-per-status
   content), `decision-log.md` (new decision + #23 extension), `item_heuristics.md` (drop the
   "durations are global" note), architecture boundary hub (status hook contract). Update POT.

## Risks / watch

- **Determinism (#24):** aggregation iterates `target.statuses` in insertion order — preserved.
  Incoming damage stays two-pass (amplify via `modify_incoming`, then `absorb`) to keep #6 order.
- **RefCounted cycle:** statuses store no target (ctx passed per-hook); the existing `source` ref is
  unchanged and still cleared at teardown/`dissolve()`.
- **Item-target statuses:** statuses live on Items too (silence, item-Weak). Base hooks must tolerate
  `target is Item` (periodic guard kept; covered by `test_periodic_status_on_an_item_does_not_crash`).
- **Apply outside combat:** relic application at fight start may have a `null`/minimal ctx — `on_apply`
  must not require it (Block/pool touch nothing).
- **Mass fuel rule:** `is_fuel()` true only for PoisonStatus + SporesStatus (today's stacked-only
  rule); timed/pool/static return false.
- **POT pipeline:** confirm status names still extracted after leaving `StatusCatalog`.

## Files

- **New:** `status_timed.gd`, `status_periodic.gd`, `status_pool.gd`, `block_status.gd`,
  `poison_status.gd`, `weak_status.gd`, `vulnerable_status.gd`, `silence_status.gd`,
  `blind_status.gd`, `spores_status.gd`, `status_registry.gd`, `status_context.gd`
  (under `src/content/statuses/` + base in `src/combat/`).
- **Rewritten:** `status.gd`, `status_manager.gd`.
- **Modified:** `item_effect.gd`, `payload.gd`, `delivery.gd`, `relic_def.gd`, `combat_manager.gd`,
  `item.gd`, `run_manager.gd`, `event_bus.gd`, `item_def.gd` (doc comment), `item_catalog.gd`,
  `relic_catalog.gd`, `enemy_hud.gd`, `auto_test_mode.gd`, `auto_test_driver.gd`, the 5 test files.
- **Deleted:** `status_def.gd`, `status_catalog.gd`.
</content>

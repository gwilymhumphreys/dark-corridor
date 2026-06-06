# Run screen & presentation tree (Phase 4)

The watchable run UI built in Phase 4 ([phase4_plan](../project/phase4_plan.md)).
It realizes the [UI/Layout PRD](../project/ui_layout_prd.md) + [VFX driver
PRD](../project/vfx_driver_prd.md) in the **framed** layout. The presentation only
*reads* the logic and *emits intents* — the same intents the autotest Driver calls.

## Presentation tree

```
main.tscn (Main) ── main_controller.gd
└─ ScreenHolder (Control)
   ├─ title_screen.tscn      Start Run / Resume → Game.start_run / resume_run
   ├─ run_screen.tscn        the live run (below)
   └─ outcome_screen.tscn    Victory / You Died → New Run / Return to Title
```

`MainController` boots with `Game` (already in TITLE — autoloads ready first) and
**swaps the active screen on `Game.phase_changed`** (TITLE / RUN / DEATH / WIN). It
holds no game state. Dev hooks: title `--autostart`, MainController `--shot
[--shot-delay s]`. `project.godot`'s `main_scene` is `main.tscn` (the corridor
testbed + combat sandbox stay runnable as direct scenes).

## The real-time seam (how the run runs)

The **logic tree stays out of the scene tree** (the Phase-3 invariant). The run
screen is the one real-time client: each `_physics_process` it calls
**`CombatManager.tick(delta)`** on the active fight (`steps_due × sim_step`) — the
*same* one tick the headless autotest runs via `sim_step()`. Nothing mounts the
`RunManager` / `Encounter` / `CombatManager`.

`run_screen.gd` is a **polling FSM** mirroring `AutoTestMode.run_full`:

```
IDLE → enter beat → fight? APPROACHING → FIGHTING ─(resolved)→ after-beat
                    rest?  resolves on begin → after-beat
after-beat: pending draft? DRAFTING (await pick) ; else advance → enter beat
run_ended → Game → outcome screen
```

It **polls `cm.is_resolved()`** (never reacts inside the `resolved` signal), so the
fight is torn down + advanced safely — the run fulfils the outcome (reward / run-end)
via its own signal chain *during* the resolving tick. Slow-mo-on-hover is a
`cm.request_slowmo` intent, only while FIGHTING.

**Battle-speed + pause (the player's clock controls).** Both are presentation-only —
the headless autotest mounts none of this:

- **Battle-speed dial** — a session preference on `Game` (`battle_speed`, cycled ×1/×2/×3
  by `Game.cycle_battle_speed`, never saved). The run screen applies it to each fight's
  `Timekeeper` **base scale** on entry and live on `Game.battle_speed_changed`. The hover
  slow-mo override still **replaces** this base absolutely while inspecting, returning to
  it on release (resolved: absolute slow-mo — [timekeeper_prd](../project/timekeeper_prd.md)).
- **Pause** — a run-screen gate (`_paused`), **not** a `Game` phase. `ui_cancel` (Escape)
  toggles it during APPROACHING / FIGHTING; while paused, `_physics_process` (the approach
  walk *and* the fight clock) and the hover `_process` are short-circuited. It raises the
  pause menu; quit-to-menu routes through `Game.return_to_title()` (which **keeps** the
  save, so Title's Resume re-enters the beat).

## The framed combat view

`combat_view_framed.tscn` (the swappable `CombatView` — the framed-vs-fullscreen
open is isolated here; full-screen is an additive later compare). Composition:

- **Corridor top-right** — `combat_corridor.tscn` (`SubViewportContainer` →
  `SubViewport` → `CorridorScaled` → the **thorn-demon as a central-axis occupant**).
  Resizeable; the SubViewportContainer clips it. See *Enemy-in-corridor* below.
- **Player portrait left** (outside the corridor); **both board strips**
  (`board_strip.tscn` → `item_cell.tscn` per item: family-colour panel + value +
  cooldown ring + fire recoil); **HP bars**; **potion slots**.
- **VFX wall** (`vfx_driver.gd`) over it — projectiles fly in screen space from a
  board cell to the target (the enemy target = the corridor's on-screen centre).

The view `bind(cm, player, enemy, potions)`s the live fight and exposes
`item_pos` / `actor_pos` to the wall; `release()` nulls the wall's `cm` ref before
teardown.

### Enemy-in-corridor occupant (the approach)

The corridor is a perspective law: a tile at depth `e` cells scales by
**`depth_ratio^e`** about the vanishing point (the renderer origin). An object **on
the central axis always projects to the vanishing point** — only its scale changes.
So the enemy is a child of `CorridorScaled` at the origin, scaled by
`CorridorScaled.axis_scale(depth)` (the same law). The **approach** (`run_screen`
APPROACHING state) tweens depth `APPROACH_DEPTH_START → 0` over `APPROACH_DURATION`
(off `_physics_process`, so the headless test walks it), gliding the corridor for
parallax; the **fight clock is not ticked until arrival**, so combat is frozen while
the demon walks into full view. Constants in `src/data/balance.gd`.

## Overlays

- **Draft** — `draft_overlay.tscn` raises 3 `draft_card.tscn`s after a fight; a pick
  emits `picked(index)` → `RunManager.apply_draft_pick`. No skip.
- **Map** — `map_strip.tscn` draws the run's beats as a labelled line (Fight / Rest /
  Boss) with the position haloed; `mark_position` on each advance.
- **Speed button** — `speed_button.tscn` on the HUD (bottom-right): an always-visible
  ×1/×2/×3 toggle calling `Game.cycle_battle_speed`, label tracking the live setting.
- **Pause menu** — `pause_menu.tscn`, a CanvasLayer **above** the HUD with an opaque
  centered panel (no translucent scrim — the pixel-art opacity rule) + Resume / Quit-to-menu;
  its full-rect Catcher swallows input so the paused board can't be clicked through.

## Localization

Player-facing text is localizable: **static UI text lives in the `.tscn`s**
(auto-translated — titles, buttons, "Choose a reward", the "You" portrait); **dynamic
text uses `tr()`** (item names/rarity/tooltips, the map labels, the outcome title).
The POT pipeline is built (`tools/extract_pot.gd` → `locale/messages.pot` + `en.po`,
registered in `project.godot`) — see [localization](../reference/localization.md).

## File map

`src/scenes/main.tscn` + `main_controller.gd`; `src/scenes/screens/`
(title · run · outcome · draft_overlay · draft_card · map_strip · speed_button · pause_menu); `src/scenes/combat/`
(combat_view_framed · combat_corridor · board_strip · item_cell); `src/vfx/vfx_driver.gd`;
the occupant law on `src/scenes/corridors/corridor_scaled.gd` (`axis_scale`). Tests in
`tests/ui/`.

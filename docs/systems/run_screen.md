# Run screen & presentation tree (Phase 4)

The watchable run UI built in Phase 4 ([phase4_plan](../history/phase4_plan.md)).
It realizes the [UI/Layout PRD](ui_layout.md) + [VFX driver
PRD](vfx_driver.md) in the **framed** layout. The presentation only
*reads* the logic and *emits intents* — the same intents the autotest Driver calls.

## Presentation tree

```
main.tscn (Main) ── main_controller.gd
└─ ScreenHolder (Control)
   ├─ title_screen.tscn      Start Run → character_select → Game.start_run ;
   │                         Resume → resume_run ; Settings → settings_screen
   ├─ run_screen.tscn        the live run (below)
   └─ outcome_screen.tscn    Victory / You Died → New Run / Return to Title
```

**Title overlays.** Start Run raises **`character_select.tscn`** (one `character_card`
per `CharacterCatalog.ids()` — name + blurb + a starting-kit hint; a pick →
`Game.start_run(seed, character_id)`, so the run opens in the chosen character's pool +
kit, #27). The Settings button raises **`settings_screen.tscn`** (below). Dev hooks skip
the menu: `--autostart` (default-character run), `--select`, `--settings`.

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
IDLE → enter beat (auto-rolled or fixed — a live encounter already) → begin beat
                    begin:  event?  EVENTING (await option pick) → after-beat
                            fight?  APPROACHING → FIGHTING ─(resolved)→ [won & run continues? SUMMARY (await Continue)] → after-beat
                            rest?   resolves on begin → after-beat
after-beat: pending draft? DRAFTING (await pick OR skip-for-gold) ; else advance → enter beat
run_ended → Game → outcome screen
```

Beats **auto-roll** their content (`RunManager._roll_beat`), so every beat enters with a live
encounter — there's no player path-pick. An **EVENT** beat raises `event_overlay.tscn` (prose + a
binary choice → `Encounter.pick_event_option`, applying the outcome + resolving), parking the FSM
until the pick, like the draft overlay. *(The `CHOOSING` state + `choice_overlay.tscn` are
**dormant** — kept inert behind `has_pending_choice()` (always false now) for a possible future
fork-beat.)*

It **polls `cm.is_resolved()`** (never reacts inside the `resolved` signal), so the
fight is torn down + advanced safely — the run fulfils the outcome (reward / run-end)
via its own signal chain *during* the resolving tick. Slow-mo-on-hover is a
`cm.request_slowmo` intent, only while FIGHTING.

**Combat log surfaces** (the watchable read of [combat_log.md](combat_log.md)). On building the
fight the screen creates a `CombatLog` and assigns it to the live `CombatManager.combat_log`,
keeping its own ref (`_log`) so the summary survives the manager's teardown. A small
`combat_stats_readout.tscn` on the HUD shows the player's running **Dealt · Taken** (net),
refreshed each tick, visible only while FIGHTING. On a **won, non-final** fight the FSM parks in
**SUMMARY** — `combat_summary.tscn` (the per-item damage report from `summary(PLAYER)` + the
event-log timeline from `events` + a Continue button) — *before* the draft; **Continue** resumes
to `after-beat`. A loss or the **final** win ends the run instead (the outcome screen), so the
summary is skipped there.

**Battle-speed + pause (the player's clock controls).** Both are presentation-only —
the headless autotest mounts none of this:

- **Battle-speed dial** — a session preference on `Game` (`battle_speed`, cycled ×1/×2/×3
  by `Game.cycle_battle_speed`, never saved). The run screen applies it to each fight's
  `Timekeeper` **base scale** on entry and live on `Game.battle_speed_changed`. The hover
  slow-mo override still **replaces** this base absolutely while inspecting, returning to
  it on release (resolved: absolute slow-mo — [timekeeper.md](timekeeper.md)).
- **Pause** — a run-screen gate (`_paused`), **not** a `Game` phase. `ui_cancel` (Escape)
  toggles it at any point in a live run; while paused, `_physics_process` (the approach
  walk *and* the fight clock) and the hover `_process` are short-circuited. It raises the
  pause menu (Resume / **Settings** / Quit-to-menu); **Settings** raises `settings_screen.tscn`
  *inside* the pause menu's CanvasLayer (layer 100) so its opaque screen covers the paused
  panel, returning to it on Close. Quit-to-menu routes through `Game.return_to_title()`
  (which **keeps** the save, so Title's Resume re-enters the beat).

**Settings** (`settings_screen.tscn`) — audio volume sliders (Master / Music / Effects), a
mute-when-unfocused toggle, a UI font dropdown (Smooth / Pixel — see `ui_theme.md`), and a
fullscreen toggle, all bound to the **`Prefs`** autoload, which applies each change (bus
level / window mode / theme font / focus-mute) and persists it to `user://` (a ConfigFile,
**separate** from the run `Save`). Opened from the title and the pause menu; Close emits
`closed` and the opener frees it. See
[audio](audio.md).

## The framed combat view

`combat_view_framed.tscn` extends the **`CombatView` base class** (`combat_view.gd`) — the
swappable surface (bind / release / approach controls / hover / the `item_pos` / `actor_pos` /
`target_pos` lookups the VFX wall reads). The run screen and `VfxDriver` are typed against the
base, so the framed-vs-fullscreen open is isolated here; a full-screen variant is an additive
later compare (extend the base, swap one preload). The **corridor-forward** layout (the layout
mockup), composition:

- **Corridor large, top-left** — `combat_corridor.tscn` (`SubViewportContainer` →
  `SubViewport` → `Corridor3D`, with each enemy a `Sprite3D` inside its 3D scene).
  Resizeable; the SubViewportContainer clips it. See *Enemies in the corridor* below.
- **An `enemy_hud` pinned above each enemy's corridor sprite** — its **item cells** (top),
  a **status-icon row + HP bar**, and the enemy's **name** (`Actor.display_name`, `tr()`'d).
  The corridor renders **one sprite per enemy**, arranged side by side and shrunk by
  count (`CombatCorridor.set_enemies`); the view pins each HUD's bottom-centre just above
  its sprite each frame via `CombatCorridor.enemy_anchor(i)`. The HUD / ally-slot item cells
  are smaller than the player's board (`ItemCell.set_cell_size`). The view **reconciles** its
  widgets to the live roster every frame (`_sync_rosters` / `_drop_missing`), so a **reaped
  dead enemy** (CombatManager removes it from combat) loses its HUD + sprite at once.
- **Player portrait + HP centre-bottom** (`BottomBar/PlayerPortrait` — portrait, HP bar,
  "You"); the **player's board is a column down the right edge** (`RightPanel/PlayerItems`,
  a grid of `item_cell.tscn`: a themed `PanelSlot` frame holding a placeholder item icon, a
  centred row of effect-coloured value pills (`value_pill.tscn`, one per value-bearing effect)
  straddling the top edge, a cooldown wipe (a horizontal line rising bottom→top) + fire recoil),
  with the **potion slots** above it.
- **Allies / summon tokens in the slots flanking the player** — `ally_slot.tscn` (portrait
  + HP + name + item cells), filling **left-to-right** (2 left of the player, then 2 right —
  capped per side; past 4 bodies, overflow tokens alternate to the emptier side;
  `AllyLeft` / `AllyRight`). A **downed run-scoped ally keeps its slot** (dimmed; it stops
  participating, revived to full next fight); a **dead combat-scoped token is reaped** like an
  enemy (slot removed). The view reads the CombatManager's rosters (`enemies` +
  `player_side()`) each frame, so mid-fight summons (a boss add, a player token) appear as
  they spawn.
- **VFX wall** (`vfx_driver.gd`) over it — projectiles fly in screen space; `actor_pos`
  resolves the player to its portrait, each enemy to its HUD, each ally/token to its slot;
  `item_pos` finds an item's cell in the right-edge column or any HUD/slot.

The view `bind(cm, player, potions)`s the live fight (it reads the rosters off the CM)
and exposes `item_pos` / `actor_pos` / `target_pos` to the wall; `release()` nulls the
wall's `cm` ref before teardown.

### Enemies in the corridor (the approach)

`CombatCorridor` instances `corridor_3d.tscn` and adds one `Sprite3D` per enemy through the
corridor's enemy methods ([corridor_3d.md](corridors/corridor_3d.md#enemies)). The sprites are lit by
the corridor light, so they come out of the dark on the approach. The container is drawn through the
[world clamp](palette_clamp.md#world-clamp).

- **One sprite per enemy:** the view passes the enemy roster to `set_enemies` each frame. An enemy
  keeps its sprite and image while it stays in the fight; a reaped enemy's sprite is freed and a new
  enemy (a summon) gets its own. The sprite shown during the approach, before the fight is bound, is
  taken over by the first enemy.
- **Placement:** `CombatCorridor` decides the spread (`SPREAD`) and shrink by count
  (`_count_shrink`). Each sprite is sized to `Balance.ENEMY_PAINTED_HEIGHT` screen pixels at depth 0
  and placed at the shared depth, offset sideways by `_offset_x`. Perspective makes deeper sprites
  smaller.
- **Several enemies** share one depth, each `DEPTH_STEP` metres further than the one before, so
  overlapping sprites are never drawn at the same distance.
- **HUD anchor:** `enemy_anchor(i)` unprojects the top centre of sprite `i` at its arrived depth and
  adds `HUD_GAP`. It does not move during the approach. The corridor image is 1:1 with the container,
  so the unprojected point plus the container's centre is the global screen point. Projectiles and
  damage numbers aim at the HUDs (`actor_pos`).
- **Images:** a random cut-out sample from `assets/monsters/cut_out/` (`MonsterImages`, its own RNG,
  so seeded runs are unchanged).

The cut-out copies are made by `tools/cut_out_monsters.gd` (usage in its header): a pixel's opacity
comes from its brightest colour channel, partly transparent pixels are brightened so edges have no
dark outline, and each image is cropped to its visible part. Dark areas inside a figure become
see-through too. Re-run the tool after adding or changing an image in `assets/monsters/`.

The **approach** (`run_screen` APPROACHING state) tweens depth `APPROACH_DEPTH_START → 0` over
`APPROACH_DURATION` (off `_physics_process`, so the headless test walks it), gliding the corridor for
parallax; the **fight clock is not ticked until arrival**, so combat is frozen while the enemy walks
into view. Constants in `src/data/balance.gd`.

## Overlays

- **Draft** — `draft_overlay.tscn` raises 3 `draft_card.tscn`s after a fight; a pick
  emits `picked(index)` → `RunManager.apply_draft_pick`. A themed **Skip button** (with a
  `UIJuice` node) emits `skipped` → `RunManager.apply_draft_skip` instead, banking gold and
  refreshing the gold HUD before advancing (decision #33). Both paths then advance.
- **Gold HUD** — a minimal `GoldReadout` label on the HUD (`tr('Gold: {0}')`), seeded from
  run-state on entry (covers a resumed run's banked gold) and refreshed after each skip.
  Placeholder placement — the owner can relocate / juice it.
- **Map** — `map_strip.tscn` draws the run's beats as a line of colour-coded dots (cleared
  solid, upcoming rings, the current beat haloed) with an "Act N" label and edge chevrons
  for off-screen beats; `mark_position` on each advance.
- **Speed button** — `speed_button.tscn` on the HUD (bottom-right): an always-visible
  ×1/×2/×3 toggle calling `Game.cycle_battle_speed`, label tracking the live setting.
- **Pause menu** — `pause_menu.tscn`, a CanvasLayer **above** the HUD with an opaque
  centered panel (no translucent scrim — the pixel-art opacity rule) + Resume / Settings /
  Quit-to-menu; its full-rect Catcher swallows input so the paused board can't be clicked
  through. Pausing mid-approach also halts the corridor treadmill (the renderer's cosmetic
  self-animation), not just the depth walk.

## Localization

Player-facing text is localizable: **static UI text lives in the `.tscn`s**
(auto-translated — titles, buttons, "Choose a reward", the "You" portrait); **dynamic
text uses `tr()`** (item names/rarity/tooltips, the map labels, the outcome title).
The POT pipeline is built (`tools/extract_pot.gd` → `locale/messages.pot` + `en.po`,
registered in `project.godot`) — see [localization](localization.md).

## File map

`src/scenes/main.tscn` + `main_controller.gd`; `src/scenes/screens/`
(title · character_select · character_card · settings_screen · run · outcome · draft_overlay ·
draft_card · map_strip · speed_button · pause_menu · combat_summary); `src/autoloads/prefs.gd`;
`src/scenes/combat/` (combat_view_framed · combat_corridor · enemy_hud · ally_slot · item_cell ·
combat_stats_readout); `src/vfx/vfx_driver.gd`;
`src/scenes/combat/monster_images.gd`; the corridor is `src/scenes/corridors/corridor_3d.gd`.
Tests in `tests/ui/` and `tests/corridors/`.

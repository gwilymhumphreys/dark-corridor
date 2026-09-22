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

**Title overlays.** Start raises **`character_select.tscn`** (one `character_card`
per `CharacterCatalog.ids()` — personal name + role subtitle + a starting-kit hint; a pick →
`Game.start_run(seed, character_id)`, so the run opens in the chosen character's pool +
kit, #27). The Settings button raises **`settings_screen.tscn`** (below). Dev hooks skip
the menu: `--autostart` (default-character run), `--select`, `--settings`.

`MainController` boots with `Game` (already in TITLE — autoloads ready first) and
**swaps the active screen on `Game.phase_changed`** (TITLE / RUN / DEATH / WIN). It
holds no game state. Dev hooks: title `--autostart` (with `--character=ID` to pick the character), MainController `--shot
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
                            fight?  APPROACHING → FIGHTING ─(resolved)→ after-beat
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
`cm.request_slowmo` intent, only while FIGHTING. The item tooltip is fed every frame a combat view
exists (approach, fight, report, draft) and hidden only while the pause menu is open
([tooltips.md](tooltips.md)).

**Combat log surfaces** (the watchable read of [combat_log.md](combat_log.md)). On building the
fight the screen creates a `CombatLog` and assigns it to the live `CombatManager.combat_log`,
keeping its own ref (`_log`). A small `combat_stats_readout.tscn` on the HUD shows the player's
running **Dealt · Taken** (net), refreshed each tick, visible only while FIGHTING. When a fight
resolves, its log becomes `_last_log` — the fight the **Report** button shows — and the run goes
straight on to `after-beat`; nothing parks. Holding `_last_log` separately from `_log` is what lets
the report outlive the `CombatManager`'s teardown at the next advance.

**Combat report** — `combat_summary.tscn` (the per-item damage report from `summary(PLAYER)` + the
event-log timeline from `events` + a Close button), raised and dismissed by the **Report** button in
the information section. The button appears once a fight has finished and stays through the beats
that follow, so the last fight can be read during the draft, an event or the next approach. The run
keeps running behind the panel; opening the next beat (`_advance`) puts the report away.

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
  **Space** (the `toggle_pause` action) pauses and resumes without the menu, showing a small
  **Paused** panel at the top centre of the HUD (`HUD/PausedPanel`). Escape during a Space pause
  raises the menu over it (still paused); Space does nothing while the menu is up.
  Opening a [debug panel](debug_panel.md) pauses the same way, and closing the last one resumes
  unless the player paused or raised the menu in the meantime.

**Settings** (`settings_screen.tscn`) — audio volume sliders (Master / Music / Interface / Game), a
text size slider, a mute-when-unfocused toggle and a fullscreen toggle, all bound to the **`Prefs`**
autoload, which applies each change (bus level / theme text sizes / window mode / focus-mute) and
persists it to `user://` (a ConfigFile, **separate** from the run `Save`). The rows sit in a
`ScrollContainer` so the screen stays usable at the largest text size. Opened from the title and the
pause menu; Close emits `closed` and the opener frees it. See [audio](audio.md) and the
[text ladder](ui_theme.md#the-text-ladder-and-the-text-size-setting).

## The framed combat view

`combat_view_framed.tscn` extends the **`CombatView` base class** (`combat_view.gd`) — the
swappable surface (bind / release / approach controls / hover / the `item_pos` / `actor_pos` /
`target_pos` lookups the VFX wall reads). The run screen and `VfxDriver` are typed against the
base, so the framed-vs-fullscreen open is isolated here; a full-screen variant is an additive
later compare (extend the base, swap one preload). The **corridor-forward** layout (the layout
mockup). The view places its parts in the run screen's [screen sections](ui_layout.md#screen-sections):

- **Corridor large, top-left** — `combat_corridor.tscn` (`SubViewportContainer` →
  `SubViewport` → `Corridor3D`, with each enemy a `Sprite3D` inside its 3D scene).
  Resizeable; the SubViewportContainer clips it. See *Enemies in the corridor* below. `PrintFrame`
  draws the optional border and overlay ([print_frame.md](print_frame.md)).
- **An `enemy_hud` pinned above each enemy's corridor sprite** — the enemy's **name**
  (`Actor.display_name`, `tr()`'d), then a **status-icon row + HP bar + status numbers**, then its
  **item cells**. The HUD is **hidden for most of the approach** and fades in over the last
  `Balance.ENEMY_REVEAL_DURATION` seconds of the walk, so it is up when the fight starts (the run
  screen calls `CombatView.show_enemies`); a summon that spawns mid-fight fades in over the shorter
  `ENEMY_FADE_IN` instead. Each OUTSIDE-set status shows as a `status_icon.tscn`:
  the status's icon on a square of its colour. The mechanic statuses (shield, poison, burn,
  bleed, regen) show as **stack counts beside the HP bar** (`status_numbers.tscn`,
  `StatusNumbers` — one label per mechanic status in its colour, numbers untranslated).
  The corridor renders **one sprite per enemy**, arranged side by side and shrunk by
  count (`CombatCorridor.set_enemies`); the view pins each HUD's bottom-centre just above
  its sprite each frame via `CombatCorridor.enemy_anchor(i)`. The HUD / ally-slot item cells
  are smaller than the player's board (`ItemCell.set_cell_size`). The view **reconciles** its
  widgets to the live roster every frame (`_sync_rosters` / `_drop_missing`), so a **reaped
  dead enemy** (CombatManager removes it from combat) loses its HUD + sprite at once.
- **Player portrait + HP in the portrait section** — the portrait on the left, and to its right,
  aligned to the top of the section, the left-aligned name ("You") over the HP bar and status
  numbers — centred between the
  ally slots (the portrait row sits in a `PlayerPanel` that is only drawn with the `portrait_panel`
  print setting, [print_frame.md](print_frame.md)); the **player's board in the items section** (a grid of `item_cell.tscn`: a themed `PanelToken` frame holding the item's icon (`ItemDef.icon`), a
  centred row of effect-coloured value pills (`value_pill.tscn` instances placed in the scene, one shown per value-bearing effect)
  straddling the top edge, a cooldown fill drawn over the icon (`cooldown_fill.gdshader`: a
  semi-transparent fill rising bottom→top as the item recharges, with a solid line along its top
  whose edge is torn like the paper edges of the print look) + fire recoil). The grid is matched to
  the board every frame (`_sync_player_items`), so an item created during the fight gains a cell with a
  "Temporary" tag on its bottom edge, and a decayed or consumed item loses its cell,
  with the **potion slots** above it. A potion slot (`potion_slot.tscn`) is a `ButtonBare` button
  wrapping the same `ItemCell` as a board item, shown with `ItemCell.show_picture` (the icon, no
  pills or cooldown fill), so potions look like items and a board item can later be made clickable
  the same way. The potions sit in a one-row pencil grid of `POTION_SLOTS` squares (more if there are
  more potions; the three-slot limit is not enforced in code).
  **The board always fits its section:** `_fit_board` gives the cells the largest size, up to
  `ItemCell.CELL_SIZE` and down to `MIN_CELL_SIZE`, at which the potion row and every item fit, with
  the gap scaled to match, and refits whenever the item or potion count or the section changes
  (`board_cell_size`, which counts the potion row as one extra row). The potions take the same cell
  size. Behind the cells is a pencil grid with one square per cell, and each item and potion sits
  slightly askew on it ([print_frame.md](print_frame.md#how-it-works)). For screenshots,
  `--board-items N` (with `--autofight --shot`) fills the board with copies of the starting items up
  to N, and `--potions N` gives the player N Healing Draughts.
  **Temporary things fade out when the fight ends.** A created item stays on the board and a summon
  token stays on the roster until the `CombatManager` is torn down at the next advance, so
  `release()` drops them from the view itself: each created item's cell
  (`CombatManager.is_created_item`) and each token's ally slot is taken out of the lookup maps at
  once — no longer hoverable or a VFX target — and fades and shrinks away over `TEMPORARY_FADE_OUT`
  seconds before freeing. The per-frame sync does not rebuild a widget that is fading.
- **Allies / summon tokens in the slots flanking the player** — `ally_slot.tscn` (the portrait,
  and beside it a column of the name, the HP bar + status numbers, and the item cells, whose size
  shrinks so the row fits the column's width), filling **left-to-right** (2 left of the player, then 2 right —
  capped per side; past 4 bodies, overflow tokens alternate to the emptier side;
  `AllyLeft` / `AllyRight`). A **downed run-scoped ally keeps its slot** (dimmed; it stops
  participating, revived to full next fight); a **dead combat-scoped token is reaped** like an
  enemy (slot removed). The view reads the CombatManager's rosters (`enemies` +
  `player_side()`) each frame, so mid-fight summons (a boss add, a player token) appear as
  they spawn.
- **VFX wall** (`vfx_driver.gd`) over it — projectiles fly in screen space; `actor_pos`
  resolves the player to its portrait, each enemy to its HUD, each ally/token to its slot;
  `item_pos` finds an item's cell in the player's grid or any HUD/slot. A thrown consumable's
  effects start from its potion slot: the view remembers the slot's centre when it is pressed (the slot
  is removed by the throw), and `consumable_pos` returns it for the delivery's `consumable`.

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
  adds `HUD_GAP`. It does not move during the approach, and it leaves the head bob out, so the HUD
  holds still while the enemy image bobs. The corridor image is 1:1 with the container,
  so the unprojected point plus the container's centre is the global screen point. `enemy_centre(i)`
  is the same unprojection of the sprite's live centre, which is where `actor_pos` sends projectiles,
  impacts and damage numbers, so a hit lands on the creature rather than on the readout above it.
- **Hits:** the view passes the fight's deliveries to `show_hits` each frame and clears them on
  `release()`. Each hit enemy flinches — its sprite is knocked away from the camera by
  `CombatCorridor.flinch_offset`, a function of render time since the hit, so slow motion slows it
  and pause holds it — and is lit ([corridor_3d.md](corridors/corridor_3d.md#hit-lights)). The
  flinch and the light have separate durations, so shortening the light in the Corridor tab does not
  cut the flinch short. The ring the wall draws at the landing point is a placeholder shape
  ([vfx_driver.md](vfx_driver.md#what-is-built)), not the intended look, and each landing is nudged
  a little off the sprite centre so hits in a burst do not stack.
- **Images:** the enemy's own `image` ([enemy.md](enemy.md#enemy-definition-data)), or, when it has
  none, a random cut-out sample from `assets/monsters/cut_out/` (`MonsterImages`, its own RNG, so
  seeded runs are unchanged). The debug `--monster-image=` override replaces both.

The cut-out copies are made by `tools/cut_out_monsters.gd` (usage in its header): a pixel's opacity
comes from its brightest colour channel, partly transparent pixels are brightened so edges have no
dark outline, and each image is cropped to its visible part. Dark areas inside a figure become
see-through too. Re-run the tool after adding or changing an image in `assets/monsters/`.

The **approach** (`run_screen` APPROACHING state): the enemy stands still at `APPROACH_DEPTH_START`
and the player walks up to it over `APPROACH_DURATION`, which is set to keep the approach at the same
pace as a free walk ([the walking pace](corridors/corridor_3d.md#the-walking-pace)). Each frame `run_screen._walk(travelled)` sets
the corridor's walk distance (`CombatCorridor.set_walk_distance`, which moves `player_z`) and the
enemy's depth to `APPROACH_DEPTH_START - travelled`, so the corridor moves past while the enemy grows
to full size. The enemy starts near the edge of the corridor light's reach, so it is dim at the
start of the walk and brightens as the player closes on it. The distance walked is a blend between a
straight line and a `smoothstep`, set by `Balance.APPROACH_EASE`, so the walk starts and ends softly
without a large swing in speed. Over the last `Balance.ENEMY_REVEAL_DURATION` seconds of the walk the
run screen calls `CombatView.show_enemies`, which fades each enemy's name, health and items up over
that same time, so the readouts are in place when the fight starts. It only acts the first time, so
the run screen can call it every frame. On arrival the run screen calls `CombatView.begin_fight`,
which turns on the cooldown fills over the item icons. They are off until then: the fight clock is
frozen during the walk, so a fill would sit motionless over the art. It runs off `_physics_process` (so the headless test walks it), and the **fight clock is not
ticked until arrival**, so combat is frozen during the walk. Constants in `src/data/balance.gd`.

## Overlays

**Reward and event panels sit in the corridor, not over the whole screen.** The run screen adds
`draft_overlay` and `event_overlay` to the combat view's `CorridorArea` (`CombatView.corridor_area()`,
the corridor's rectangle), and their root Controls ignore the mouse, so the board, potions, portrait,
HUD and item tooltips keep working around them. An event beat has no fight, so the run screen still
builds the combat view for it with no `CombatManager` (`bind(null, ...)`: the player's side, no
enemies). When a fight resolves, the run screen calls `view.release()` at once so the last hits'
numbers and rings don't stay frozen in the corridor under the reward panel. `release()` also clears the item
cells' cooldown fills (`ItemCell.show_cooldown`) and fades away the fight's temporary things (below).
A view built without a fight never shows the fills. The choice overlay and the combat report are still
full-screen.

- **Draft** — `draft_overlay.tscn` shows each reward as a `RewardOption` (`reward_option.tscn`)
  after a fight: a button around the same `ItemCell` the board uses (the same icon and value pills),
  with a `UIJuice` node drawing the highlight on the cell's frame, so a reward hovers, presses and
  sounds like every other control the player picks ([control_feedback.md](control_feedback.md)). The
  button itself draws nothing (the `ButtonBare` theme variation). Hovering one shows the item
  tooltip, and pressing it emits `picked(index)` → `RunManager.apply_draft_pick`. The **gold button** in the
  panel's bottom right (`'+{0} gold'`, the amount from `Balance.GOLD_SKIP`) emits `skipped` →
  `RunManager.apply_draft_skip` instead, banking gold and
  refreshing the gold HUD before advancing (decision #33). Both paths then advance.
- **Gold HUD** — a minimal `GoldReadout` label in the information section (`tr('Gold: {0}')`),
  seeded from run-state on entry (covers a resumed run's banked gold) and refreshed after each skip.
- **Map** — `map_strip.tscn`, at the top of the information section, draws the run's beats as a line of colour-coded dots (cleared
  solid, upcoming rings, the current beat haloed) with an "Act N" label and edge chevrons
  for off-screen beats; `mark_position` on each advance.
- **Speed button** — `speed_button.tscn` in the information section: an always-visible
  ×1/×2/×3 toggle calling `Game.cycle_battle_speed`, label tracking the live setting.
- **Report button** — beside the speed button in the information section: hidden until the first
  fight has finished, then a toggle that raises and hides the combat report of the last fight.
- **Pause menu** — `pause_menu.tscn`, a CanvasLayer **above** the HUD with an opaque
  centered panel (no translucent scrim) + Resume / Settings /
  Quit-to-menu; its full-rect Catcher swallows input so the paused board can't be clicked
  through. Pausing mid-approach also halts the corridor's movement, not just the depth walk.

## Localization

Player-facing text is localizable: **static UI text lives in the `.tscn`s**
(auto-translated — titles, buttons, "Choose a reward", the "You" portrait); **dynamic
text uses `tr()`** (item names/rarity/tooltips, the map labels, the outcome title).
The POT pipeline is built (`tools/extract_pot.gd` → `locale/messages.pot` + `en.po`,
registered in `project.godot`) — see [localization](localization.md).

## File map

`src/scenes/main.tscn` + `main_controller.gd`; `src/scenes/screens/`
(title · character_select · character_card · settings_screen · run · outcome · draft_overlay ·
map_strip · speed_button · pause_menu · combat_summary); `src/autoloads/prefs.gd`;
`src/scenes/combat/` (combat_view_framed · combat_corridor · enemy_hud · ally_slot · item_cell ·
combat_stats_readout); `src/vfx/vfx_driver.gd`;
`src/scenes/combat/monster_images.gd`; the corridor is `src/scenes/corridors/corridor_3d.gd`.
Tests in `tests/ui/` and `tests/corridors/`.

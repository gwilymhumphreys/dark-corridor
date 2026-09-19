# Plan — the corridor walk: footsteps and head bob

One walking model in `Corridor3D` that the footstep sounds and the camera bob both
read, so they cannot drift apart, and a per-character stride length that sets the pace.

## Why it is built this way

The corridor is moved two different ways and they share nothing. The testbed eases
`velocity` toward `speed` and adds it to `player_z`. A fight approach has the host write
`player_z` straight from a smoothstep over `APPROACH_DURATION`, which leaves `velocity` at
zero for the whole walk (`run_screen.gd:200-203`, `corridor_testbed.gd:85-89`).

Anything reading `velocity` would therefore be silent during every fight. Instead the
corridor measures how far `player_z` actually moved each frame. That is correct whoever
moved it, needs no change to either host, and keeps `set_walk_distance` and `player_z`
exactly as the tests already use them.

Footsteps play one sample per footfall rather than looping a recording. A loop has to be
rate-matched to the pace, which means pitch-shifting it every time the speed changes, and
the approach eases in and out so the speed changes constantly. One sample per footfall is
exact at any speed with no pitch shift, and it matches how `SfxManager` already handles the
interface sounds.

## Changes

### 1. `src/content/characters/character_def.gd`

Add one field:

```gdscript
var stride_length: float = 0.65      # metres covered per footstep; sets the walking pace
```

Per-character values are the owner's to author. Everything stays on the default for now.

### 2. `src/scenes/corridors/corridor_3d.gd`

A new `@export_group('Walk')` and the walk model.

Exports:

| Export | Meaning |
|---|---|
| `stride_length` | Metres per footstep. The host overwrites it from the run's character. |
| `footsteps_on` | Whether footfalls play a sound. |
| `bob_on` | Whether the camera bobs. |
| `bob_height` | Metres the camera drops at a footfall. |
| `bob_sway` | Metres the camera leans sideways, one full lean every two steps. |

Read-only state: `walk_distance` (metres walked, counting both directions) and
`walk_speed` (metres per second). One signal, `footstep(index: int)`, emitted on each
footfall. The corridor plays the sound from it, and the tests assert on it, which matters
because headless runs load no audio at all and could not otherwise check the pacing.

Each `_process`, after `player_z` has moved:

- `moved = absf(player_z - _last_player_z) * section_length`
- If `moved` is over `MAX_FRAME_MOVE`, treat it as a teleport: update `_last_player_z`, add
  nothing, play nothing. This covers a host reseating the corridor.
- Otherwise add `moved` to `walk_distance`, and ease `walk_speed` toward `moved / delta`
  over roughly 0.12 seconds. The easing is needed because the run screen moves the corridor
  from `_physics_process` while this runs in `_process`, so a given frame may see two
  physics ticks of movement or none.
- `step_phase = walk_distance / stride_length`. When `floori(step_phase)` goes up and
  `walk_speed` is above `MIN_WALK_SPEED`, one footfall happened: call
  `SfxManager.play_footstep()`. At most one per frame.
- Bob, when `bob_on`: the weight is `walk_speed / stride_length` clamped to 0..1, which is
  steps per second capped at one, so the camera settles level as the walk stops.
  - `camera.position.y = -bob_height * (0.5 + 0.5 * cos(TAU * step_phase)) * weight`,
    lowest exactly at each footfall.
  - `camera.position.x = bob_sway * sin(PI * step_phase) * weight`, which is one lean
    every two steps, alternating sides like a real gait.
- `reset_walk()` clears the distance, the phase and the camera offset, for a host reseating
  the corridor. `_build()` does **not** call it: the debug panel rebuilds through
  `apply_settings` and doing so mid-approach would jump the phase and fire a spurious
  footfall. `_build()` only re-syncs `_last_player_z` so the rebuild is not read as a
  teleport.

Constants: `MAX_FRAME_MOVE` 2.0 metres, `MIN_WALK_SPEED` 0.05 metres per second.

The first footfall lands after one whole stride rather than the instant the walk starts,
which at a cautious pace is a little under a second.

`unproject()` is used for the enemy HUD anchors, and a bobbing camera moves what it
returns. The HUDs are hidden throughout the approach and fade in on arrival, when the walk
has stopped and the camera is level again, so this does not show. Worth a note in the doc.

### 3. `src/autoloads/sfx_manager.gd` and `default_bus_layout.tres`

The footstep recordings are dry, so the corridor's echo comes from a bus effect. Interface
sounds must stay dry, so they cannot share a bus.

- New bus `World`, sending to `Effects`, carrying an `AudioEffectReverb` set for a stone
  corridor. `Effects` still controls its volume, so the existing settings slider is enough.
- `SfxManager` gets a second `AudioStreamPolyphonic` player on that bus, built the same way
  as the existing one, and `play_world(stream, pitch, volume_db)` to play through it. The
  autoload is registered as `SfxManager`.

  Starting reverb values for a stone corridor, to be tuned by ear in the editor's audio
  panel: room size 0.5, damping 0.5, wet 0.25, dry 1.0, predelay 20 ms. `World` sends to
  `Effects`, so the existing volume preference covers it and `Prefs` needs no change — it
  looks buses up by name (`prefs.gd:20-24`).
- `WORLD_FOOTSTEP_DIR = 'res://assets/sound-effects/world/footsteps/steps/'`, loaded by the
  same guarded loader, so silent runs and headless tests stay silent with no extra work.
- `play_footstep()` picks one of the pool and plays it guarded, keyed `footstep`, through
  the world player.

### 4. `src/scenes/combat/combat_corridor.gd`

In `_ready`, after `apply_settings`, pass the run's stride down when a run exists:

```gdscript
if Game.run != null and Game.run.character != null:
  _corridor.stride_length = Game.run.character.stride_length
```

The corridor keeps its own default so the testbed and the tests work with no run loaded.

`_walk_start` is already captured there; call `_corridor.reset_walk()` beside it.

### 5. Pace numbers

The walk is currently far too fast for the sound to make sense: `speed` of 1.2 sections per
second is 3.6 m/s at a 3m section, which is a run.

- `Corridor3D.speed`: 1.2 → 0.233, which is 0.7 m/s, a cautious walking pace.
- `Balance.APPROACH_DURATION`: 5.0 → 6.0 seconds, and `APPROACH_DEPTH_START`: 5.0 → 1.4
  sections, so the approach covers 4.2 metres at 0.7 m/s. The two constants are set together:
  depth start divided by duration has to stay at the walking pace, or the approach walks at a
  different speed from a free walk and the footsteps stop matching.

The enemy starts at about 34% of its final size instead of 12.5%, because a cautious pace cannot
cover much ground. The reveal comes from the light instead: the owner shortened `light_range` in the default
look preset (2026-09-19), so the enemy starts near the edge of the light's reach, dim, and
brightens as the player closes on it. The preset is what runs; the value in the corridor scene
only applies when no preset is loaded, so the two are kept the same.

### 6. Assets

- `assets/sound-effects/world/footsteps/steps/` holds 24 steps as `.wav` and `.mp3`, cut
  from the one recording, with a common gain so their relative levels are untouched.
- `tile_slow.wav`, the 3.3 MB source recording, moves to
  `../dark-corridor-design/sound/footsteps/` with the cutting script, following the rule
  that only sounds the game plays live in `assets/`.

### 7. Tests — `tests/corridors/test_corridor_walk.gd`

- Walking a known distance gives the expected number of footfalls.
- Halving the stride doubles the footfalls over the same distance.
- A teleport-sized jump in `player_z` makes no footfall.
- The camera is level again once the walk stops.
- `reset_walk()` clears the distance and the camera offset.

### 8. Docs

- `docs/systems/corridors/corridor_3d.md`: the walk model in Movement, the new exports, the
  footstep and bob behaviour, and the HUD anchor note.
- `docs/systems/audio.md`: the World bus and its reverb, the footstep bank.
- `docs/design/asset_credits.md`: the steps folder and where the source recording went.
- No numbers in the docs, per the documentation rules; they point at the source.

## Deliberately not doing

- Moving the approach walk into the corridor. It would remove the duplicated smoothstep in
  `run_screen.gd` and `corridor_testbed.gd`, but it touches the run screen state machine and
  its tests, and the derived measurement makes it unnecessary. Worth raising separately.
- Alternating left and right feet. The source steps are not labelled, so the pool is picked
  at random and two identical steps can land in a row.
- Changing units from sections to metres across the corridor and `Balance`.

## After implementing

List every knob that controls the approach, with what each one does, so the owner can tune
the walk by eye.

# Audio

Centralised sound via two autoloads plus an audio bus layout. Both managers are
trimmed-down ports of a-machine's audio system — the reusable core only; the
game-specific catalogue (shards, lasers, shields, tutorial cues, save-backed
randomisation, telemetry) was intentionally left out and can be added back per
feature.

## Buses

`default_bus_layout.tres` (project root, auto-loaded by Godot — no project
setting needed) defines:

- **Master**
- **Music** → Master
- **Effects** → Master

So music and effects volume are controlled independently — see **Prefs** below.

## Prefs (`src/autoloads/prefs.gd`)

The settings autoload — persists per-player **volume** preferences to `user://` (a
`ConfigFile`, **separate** from the run `Save`, which holds run-state only and is cleared
on death/win). It stores a 0..1 linear level per audio key (`master` / `music` /
`effects`), applies each to its bus via `AudioServer.set_bus_volume_db` (`linear_to_db`;
0 → −80 dB silence), and re-applies them at boot. `set_volume(key, value)` clamps, applies,
and writes through immediately; `disabled` (mirrors `Save.disabled` — the tests / a nosave
run) skips the disk write. The [settings screen](run_screen.md) binds its sliders here.
Defaults + bus map are constants at the top of `prefs.gd`; the owner extends it with
video / accessibility keys as settings grow.

## SfxManager (`src/autoloads/sfx_manager.gd`)

One-shot sound effects through a single `AudioStreamPolyphonic` player (many
overlapping sounds, cheap). Routes to the **Effects** bus.

- **Cooldown** — a short per-key guard stops the same sound machine-gunning on
  rapid triggers (e.g. hover).
- **Pitch jitter** — each play gets a small random pitch so repeats don't sound
  robotic. Pass an explicit pitch to override.
- **Graceful no-op** — every `play_*` helper does nothing when its stream is
  missing, so callers (e.g. [UIJuice](ui_juice.md)) work before any audio
  assets exist.

API:

- `play(stream, pitch := -1.0, volume_db := 0.0)` — generic one-shot (negative
  pitch = random jitter).
- `play_guarded(key, stream, pitch, volume_db)` — same, but cooldown-guarded by
  `key`.
- `play_ui_hover()` / `play_ui_click()` / `play_ui_press()` — the shared UI bank.

The UI bank loads from the `UI_*_PATH` constants; drop files there and they're
picked up automatically:

- `assets/sound-effects/ui/hover.wav`
- `assets/sound-effects/ui/click.wav`
- `assets/sound-effects/ui/press.wav`

Tunable constants (polyphony, cooldown, pitch range, paths) live at the top of
`sfx_manager.gd`.

## MusicManager (`src/autoloads/music_manager.gd`)

Shuffled background music with a two-player crossfade. Loads every `.ogg` in
`assets/music/`, reshuffles when the playlist is exhausted, and crossfades into
the next track near the end of the current one. Routes to the **Music** bus.

- **No-op when empty** — safe to run before any tracks exist.
- **Web autoplay gating** — on web, playback starts on the first user input so
  the browser's AudioContext isn't left blocked.

Crossfade duration and the music directory are constants at the top of
`music_manager.gd`.

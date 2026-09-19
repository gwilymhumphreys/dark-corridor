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
- **World** → Effects, carrying an `AudioEffectReverb`

So music and effects volume are controlled independently — see **Prefs** below. World sounds
route through Effects, so the effects volume covers them and `Prefs` needs no extra key.

**Why World is separate.** Sounds coming from inside the corridor need its echo; interface
sounds are not in the room and must stay dry, so they cannot share a bus. The reverb is set for
a stone corridor and is tuned in the editor's audio panel.

## Prefs (`src/autoloads/prefs.gd`)

The settings autoload — persists per-player **volume** preferences to `user://` (a
`ConfigFile`, **separate** from the run `Save`, which holds run-state only and is cleared
on death/win). It stores a 0..1 linear level per audio key (`master` / `music` /
`effects`), applies each to its bus via `AudioServer.set_bus_volume_db` (`linear_to_db`;
0 → −80 dB silence), and re-applies them at boot. A key the player has never set falls back
to its default in `AUDIO_DEFAULTS`. `set_volume(key, value)` clamps, applies,
and writes through immediately; `disabled` (mirrors `Save.disabled` — the tests / a nosave
run) skips the disk write. The [settings screen](run_screen.md) binds its sliders here.
Defaults + bus map are constants at the top of `prefs.gd`; the owner extends it with
video / accessibility keys as settings grow.

**Silent runs.** A process launched with `--autotest` or `--shot` plays no sound: `Prefs`
mutes the Master bus at boot and leaves the stored levels alone, so the player's own
settings are untouched. Mute-when-unfocused is skipped in those runs, since the bus is
already muted. The flags are the `SILENT_ARGS` constant in `prefs.gd`.

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
- **Starts on first play** — the player is not autoplayed; the first real `play`
  starts it. A playback started with nothing to play is never released under the
  headless dummy audio driver and is reported as leaked at exit. Each start makes a
  new playback, so the playback handle is fetched again every time the player starts.

API:

- `play(stream, pitch := -1.0, volume_db := 0.0)` — generic one-shot (negative
  pitch = random jitter).
- `play_guarded(key, stream, pitch, volume_db)` — same, but cooldown-guarded by
  `key`.
- `play_ui_hover()` / `play_ui_click()` — the shared UI bank.
- `play_impact()` — a hit landing in combat, played once per landing by the
  [VFX wall](vfx_driver.md). Guarded, so a burst of hits in the same moment makes one sound.
- `play_world(stream, pitch, volume_db)` — a one-shot through the World bus, so it gets the
  corridor's echo. `play_guarded_world(key, ...)` is its cooldown-guarded form.
- `play_footstep()` — one footstep from the world bank, guarded. The corridor calls it on each
  footfall ([corridor_3d.md](corridors/corridor_3d.md)); nothing else decides the pacing.

**Variant folders.** The UI bank loads every sound in the `UI_*_DIR` folders, and each play
picks one at random, so a repeated action doesn't repeat the same recording. Drop a file in or
delete one and the pool changes with no code change:

- `assets/sound-effects/ui/hover/` — 8 page turns
- `assets/sound-effects/ui/click/` — 6 book closes and 2 book drops
- `assets/sound-effects/world/footsteps/steps/` — single footsteps, one per footfall

`assets/sound-effects/world/footsteps/walk_loop.*` beside that folder is a ready-made looping
walk cut from the same recording. Nothing plays it: it is there in case a walk is ever needed
without a corridor driving it.

Wav files must be 8-bit or 16-bit PCM; a 24-bit one imports as silence without failing the
import. See [godot_notes.md](godot_notes.md#importing-assets).

**No lead-in.** Every interface sound is trimmed so it starts at the first sample. The
recordings arrive with up to a third of a second of room tone before the sound itself, which on a
button reads as lag rather than as silence. Trim any new one before adding it.

**Two formats per sound.** Each one is kept as both the original `.wav` and a much smaller
`.mp3`. Files sharing a name before the extension are one sound, not two variants: the loader
groups by that name and takes a single file per sound, preferring the `.mp3` on web (so the
player downloads less) and the `.wav` everywhere else. The preference lists are
`EXTENSIONS_BY_SIZE` and `EXTENSIONS_BY_QUALITY`.

The combat impact sound is a single file at `COMBAT_IMPACT_PATH`
(`assets/sound-effects/combat/impact.mp3`). No file is there yet, so `play_impact()` is silent.

**Nothing is loaded in a silent run.** Like `MusicManager` below, the bank is skipped under the
headless dummy audio driver and in `--autotest` / `--shot` runs. The dummy driver never releases
a playback, so a sound played in a test would be reported as leaked at exit.

See [art_audio.md](../design/art_audio.md) for where effects come from and
[asset_credits.md](../design/asset_credits.md) for who recorded them.

Tunable constants (polyphony, cooldown, pitch range, paths) live at the top of
`sfx_manager.gd`.

## MusicManager (`src/autoloads/music_manager.gd`)

Shuffled background music with a two-player crossfade. Loads every `.ogg` and `.mp3`
in `assets/music/`, reshuffles when the playlist is exhausted, and crossfades into
the next track near the end of the current one. Routes to the **Music** bus.

The folder holds the tracks from three dungeon synth packs, credited in
[asset_credits.md](../design/asset_credits.md). Where a pack ships both a
full-length and a loop version of a track, the full-length one is in the project,
because the crossfade already blends a track out. Drop another `.ogg` or `.mp3` in the
folder and it joins the shuffle with no code change.

- **No-op when empty** — safe to run before any tracks exist.
- **Skipped when nothing can hear it** — no tracks are loaded under the headless
  dummy audio driver, or in an `--autotest` / `--shot` run. Besides keeping those
  runs silent, this avoids decoding the whole music folder every time. The dummy
  driver never releases a playback, so a track left playing is reported as leaked
  at exit — the same driver behaviour noted for `SfxManager` above.
- **Web autoplay gating** — on web, playback starts on the first user input so
  the browser's AudioContext isn't left blocked.

Crossfade duration and the music directory are constants at the top of
`music_manager.gd`.

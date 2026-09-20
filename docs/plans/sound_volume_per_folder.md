# Plan: a volume per sound folder

Sounds are not equally loud at the same peak level. A sword hit is a sharp
transient and an armour rustle is spread over half a second, so matching their
peaks leaves the rustle much quieter than the hit. At present the only way to
balance them is to re-encode the files, which loses quality each time and hides
the decision inside the audio data.

`SfxManager.play_sound(path, pitch, volume_db)` already takes a volume. Nothing
passes one. This adds a per-folder value that it reads.

## The shape

A sound folder may hold a `volume.cfg` file containing one number, the
adjustment in decibels:

```
-4.5
```

The folder stays the whole configuration for a sound, which is the existing
rule: adding or rebalancing a sound is a change inside its folder and no code
change. `_load_folder` only collects audio extensions, so the file is already
ignored by the bank loader.

## Behaviour

- A folder with no `volume.cfg` adjusts by 0 dB.
- The value is read from the folder whose recordings actually played. When
  `mechanics/attack/shielded` is empty and the fallback plays
  `mechanics/attack`, the parent folder's value applies.
- The `volume_db` argument is added to the folder's value rather than replacing
  it, so a caller that wants one quieter play keeps the folder's balance. This
  needs no change to the existing default of `0.0`.
- A value outside a sane range is clamped and warned about once, so a typed
  `-45` instead of `-4.5` cannot make a sound inaudible without saying so, and a
  `40` cannot deafen. Range and the constant name go in the source.
- A file that does not parse as a number reads as 0 dB and warns once, through
  the existing `_warn_once` with its own key prefix.
- Values are cached beside the banks and, like them, a missing file is cached
  too so the folder is not rescanned on every play.
- `play_sound` does not currently keep track of which of the three candidate
  paths supplied the bank it is about to play. It has to, so the volume comes
  from the folder that actually played rather than the one that was asked for.
- `play_sound_guarded` passes its `volume_db` straight to `play_sound`, so it
  picks this up with no change of its own.
- `play` and `play_world` take a stream rather than a folder path, so no folder
  volume applies to them. They keep their current behaviour.

## Changes

| File | Change |
| --- | --- |
| `src/autoloads/sfx_manager.gd` | `VOLUME_FILE`, the clamp range constant, a `_volumes` cache, `_volume_for(path)`, and the addition in `play_sound`. |
| `tests/ui/test_sfx_manager.gd` | `_volume_for` on a folder with a value, without one, with an out-of-range value and with an unparseable one. Tested directly, because a headless run sets `_silent` and `play_sound` returns before it reads anything. |
| `docs/systems/audio.md` | A short section on the file, next to the folder table. |

## Not in this change

- No volume per individual recording. A folder's recordings should be levelled
  against each other when they are prepared; the folder value balances that
  sound against other sounds.
- No runtime editing or debug panel. The file is edited and the game restarted.

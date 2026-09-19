# Asset credits

Who made the third-party assets in this repository, and where they came from.
This is the record an in-game credits screen or a store page is built from, so
every pack we ship a file from gets a row here.

**Location:** the files themselves are under `assets/`; the source packs they
were picked from are described in [asset_library.md](asset_library.md).

Add a row when a file from a new pack is copied into `assets/`, in the same
change.

## Music

All three packs are by arnocyreus. Each was supplied as WAV and converted to
`.ogg` into `assets/music/`, where [MusicManager](../systems/audio.md) shuffles
them together.

| Pack | Source | Tracks in the game |
| --- | --- | --- |
| Outrider's Oath — Dungeon Synth Soundtrack | https://arnocyreus.itch.io/outriders-oath-dungeon-synth-soundtrack | 10 |
| Lordran Tapes | https://arnocyreus.itch.io/lordrantapes | 5 |
| Bonfires — dark fantasy music | https://arnocyreus.itch.io/bonfiresdungeon | 9 |

Outrider's Oath and Lordran Tapes ship a full-length and a loop version of each
track; the full-length versions are the ones in the repository. Bonfires ships
one version of each track.

## Sound effects

All interface sounds are by **SpaceJoe** on Freesound (https://freesound.org/people/SpaceJoe/),
released under CC0, so no attribution is required — the record is kept here anyway. They are
three families from one recording session, which is why they sit together.

| Family | Files in the game | Freesound ids |
| --- | --- | --- |
| Quiet Page Turn | 8 in `assets/sound-effects/ui/hover/` | 484961 to 484968 |
| Book Close | 6 in `assets/sound-effects/ui/click/` | 484882, 484885, 484888, 484890, 484891, 484892 |
| Book Drop | 2 in `assets/sound-effects/ui/click/` | 484897, 484906 |

A single sound's page is at `https://freesound.org/s/<id>/`. Each sound is in the
repository twice, as the original `.wav` and as an `.mp3`; see
[audio.md](../systems/audio.md) for which one each build loads.

**The rest of the library.** SpaceJoe has 562 uploads — books, paper, locks, switches, safes,
lighters and more — and all of them are in `../dark-corridor-design/sound/spacejoe/` as
originals, outside this repository, with a `credits.csv` listing every id, name, licence and
URL. Only the sounds the game actually plays are copied into `assets/`. The user-scoped `sfx`
skill (`~/.claude/skills/sfx/`) fetched them and can fetch another uploader's library the same
way.

## Art

The art packs in use are listed in
[asset_library.md](asset_library.md#source-directories). Their authors and
source links are not recorded yet — the owner has these and they need filling
in here before release.

| Pack | Files in the game | Source |
| --- | --- | --- |
| 6000 Fantasy Icons | Icons and portraits under `assets/icons/`, `assets/portraits/` | not recorded yet |
| Monster volumes | `assets/monsters/cut_out/` | not recorded yet |
| UI Bundle (`BlackandWhiteUI.png`) | `assets/ui/` | not recorded yet |
| Palettes | `assets/palettes/` | not recorded yet |
| Cursors Pack 3 [RPG, RTS, MMO, TPS], by Wenrexa | `assets/ui/cursors/stone_pointer.png` | https://wenrexa.itch.io/cursors-pack-03 |

Cursors Pack 3 is CC0, so attribution is not required; the row is kept for the
record. Its itch.io page states that no generative AI was used.

## Fonts

| Font | Files in the game | Source |
| --- | --- | --- |
| Rakkas | `assets/fonts/rakkas.ttf`, named as the default font by the [theme](../systems/ui_theme.md) | not recorded yet |

Packs we are considering but do not ship a file from are out of scope for this
page; those are in [art_audio.md](art_audio.md).

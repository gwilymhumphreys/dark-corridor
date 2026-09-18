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

## Fonts

| Font | Files in the game | Source |
| --- | --- | --- |
| Rakkas | `assets/fonts/rakkas.ttf`, named as the default font by the [theme](../systems/ui_theme.md) | not recorded yet |

Packs we are considering but do not ship a file from are out of scope for this
page; those are in [art_audio.md](art_audio.md).

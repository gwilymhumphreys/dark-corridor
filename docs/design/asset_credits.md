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
| Quiet Page Turn | 7 in `assets/sound-effects/ui/hover/` | 484961 to 484963, 484965 to 484968 |
| Book Close | 3 in `assets/sound-effects/ui/click/` | 484885, 484888, 484890 |

A single sound's page is at `https://freesound.org/s/<id>/`. Each sound is in the
repository twice, as the original `.wav` and as an `.mp3`; see
[audio.md](../systems/audio.md) for which one each build loads.

**The rest of the library.** SpaceJoe has 562 uploads — books, paper, locks, switches, safes,
lighters and more — and all of them are in `../dark-corridor-design/sound/spacejoe/` as
originals, outside this repository, with a `credits.csv` listing every id, name, licence and
URL. Only the sounds the game actually plays are copied into `assets/`. The user-scoped `sfx`
skill (`~/.claude/skills/sfx/`) fetched them and can fetch another uploader's library the same
way.

### Footsteps

| Sound | Files in the game | Source |
| --- | --- | --- |
| Footsteps, Tile, Male Sneakers, Slow Pace, by SpliceSound, CC0 | `assets/sound-effects/world/footsteps/` | https://freesound.org/s/170506/ |

One recording of a slow walk on tile, cut up into its individual steps. `steps/` holds
one file per step, as `.wav` and `.mp3`, with a single gain applied across the set so
their relative levels are unchanged; two scuffs that were far louder than the rest were
left out.

The recording is dry, so the corridor's echo comes from the World bus rather than being
in the files ([audio.md](../systems/audio.md)).

The source recording and the scripts that cut it are in
`../dark-corridor-design/sound/footsteps/`, outside this repository, so the cut can be
redone without downloading it again.

### Combat

| Sound | Files in the game | Source |
| --- | --- | --- |
| Sword_Hit_Wood 01 and 02, by timmy_h123, CC BY | `assets/sound-effects/mechanics/attack/` | https://freesound.org/s/160412/ and /160411/ |
| Sword_Hit_Metal 01, 02, 15 and 19, by timmy_h123, CC BY | `assets/sound-effects/mechanics/attack/shielded/` | https://freesound.org/s/160396/, /160395/, /160409/ and /160404/ |

The attack sound. A hit on an unshielded target plays a sword on wood; a hit on a
shielded one plays a sword on metal ([mechanics.md](../systems/mechanics.md)). Both
families come from one recording session by the same person, which is why they sit
together.

They were uploaded as 24-bit 96kHz, which Godot imports as silence without failing, so
each was converted to 16-bit 48kHz before being added ([godot_notes.md](../systems/godot_notes.md)).

The uploader's other 64 recordings are archived at `../dark-corridor-design/sound/timmy_h123/`
([asset_library.md](asset_library.md)), which is where to look for more variants.

### Gold and shop

| Sound | Files in the game | Source |
| --- | --- | --- |
| Coin_Wood_Table_Singles_Drop_Spin_Takes_5, Effectsworks - COINAGE (Sonniss GDC 2018) | `assets/sound-effects/run/gold/coin_wood_*` | Sonniss GameAudioGDC bundle |
| coins throwing from hand to hand, Soundholder - Sack Of Coins (Sonniss GDC 2020) | `run/gold/coin_hand_*` | Sonniss GameAudioGDC bundle |
| Money,Coins,Hand,Count and Money,Coins,Handle, Hzandbits - Money (Sonniss GDC 2017) | `run/gold/count_hand_*`, `run/gold/handle_*` | Sonniss GameAudioGDC bundle |
| coins_9, CB Sound Design - Essential Sounds Vol.01 Coins (Sonniss GDC 2023) | `run/gold/clink_*` | Sonniss GameAudioGDC bundle |
| Clinking Coins 4 and 10, by AleXZavesa, CC BY | `run/gold/clink_bag_*`, `run/purchase/coins_clink_*` | https://freesound.org/s/853709/ and /853705/ |
| Money,Coins,Drop In Cash Register, Hzandbits - Money (Sonniss GDC 2017) | `run/purchase/register_drawer_*` | Sonniss GameAudioGDC bundle |
| Antique-Cash-Register_07, SoundBits - Antiques (Sonniss GDC 2019) | `run/purchase/antique_register_*` | Sonniss GameAudioGDC bundle |
| Coins_Pouch_Leather_Drop_Into and Coins_Wood_Slide_Gather, Effectsworks - COINAGE (Sonniss GDC 2018) | `run/purchase/pouch_drop_*`, `run/purchase/counter_slide_*` | Sonniss GameAudioGDC bundle |
| Heavy Money Bag - 1, by SpaceJoe, CC0 | `run/purchase/money_bag_*` | https://freesound.org/s/485716/ |
| Leather money pouch or purse with coins inside, catch in hand 5, by ZapSplat | `run/purchase/pouch_catch_*` | https://www.zapsplat.com/music/leather-money-pouch-or-purse-with-coins-inside-catch-in-hand-5/ |

These are candidates for review. A row comes out when none of its files are left in the game.

## Art

The art packs in use are listed in
[asset_library.md](asset_library.md#source-directories). Their authors and
source links are not recorded yet — the owner has these and they need filling
in here before release.

| Pack | Files in the game | Source |
| --- | --- | --- |
| 6000 Fantasy Icons | Icons and portraits under `assets/icons/`, `assets/portraits/` | not recorded yet |
| game-icons.net | The flat glyphs under `assets/icons/mechanics/` | https://github.com/game-icons/icons |
| Monster volumes | `assets/monsters/cut_out/` | not recorded yet |
| UI Bundle (`BlackandWhiteUI.png`) | `assets/ui/` | not recorded yet |
| Palettes | `assets/palettes/` | not recorded yet |
| Cool Cursors, by TheWiseHedgehog | `assets/ui/cursors/hand_pointer.png`, `hand_pointer_pressed.png` (edited) | https://thewisehedgehog.itch.io/cc |

Cool Cursors requires credit, given as a link to https://thewisehedgehog.itch.io/.
The pack may be edited but not redistributed. The original is in
`../dark-corridor-design/cursors/Cool Cursors/`.

## Fonts

| Font | Files in the game | Source |
| --- | --- | --- |
| Rakkas | `assets/fonts/rakkas.ttf`, named as the default font by the [theme](../systems/ui_theme.md) | not recorded yet |

Packs we are considering but do not ship a file from are out of scope for this
page; those are in [art_audio.md](art_audio.md).

class_name Colours
## Central colour palette (decision: one home for colours, like Balance for tuning numbers). Every
## gameplay / UI colour lives here so it is editable in one place and shared without duplication —
## an applier item references the SAME const as the status it applies, the map and choice cards
## share one beat palette, etc. British 'colours' for the file; Godot's `Color` keeps its API spelling.
##
## NOTE: a few colours still live at their use site by design — pure dev/debug tints (e.g. the
## corridor "see gaps" magenta) and colours inside the owner's uncommitted WIP files (map_strip).

# ── Statuses ─────────────────────────────────────────────────────────────────
# Each StatusEffect subclass AND its appliers reference the same const (applier = status colour).
const STATUS_BLOCK := Color(0.3, 0.6, 1.0)
const STATUS_POISON := Color(0.4, 0.8, 0.2)
const STATUS_WEAK := Color(0.6, 0.4, 0.7)
const STATUS_VULNERABLE := Color(0.85, 0.5, 0.2)
const STATUS_BLIND := Color(0.9, 0.9, 0.55)
const STATUS_SILENCE := Color(0.5, 0.5, 0.5)
const STATUS_SPORES := Color(0.45, 0.8, 0.7)     # placeholder fungal teal — owner re-tints

# ── Combat payloads / item panels ────────────────────────────────────────────
const DAMAGE := Color(0.9, 0.2, 0.2)             # the generic attack red
const HEAL := Color(0.3, 0.9, 0.4)
const ARCANE := Color(0.5, 0.2, 0.7)             # Hex Bolt (item-targeting)
const ENEMY_CLAW := Color(0.8, 0.4, 0.1)

# ── Relic panels ─────────────────────────────────────────────────────────────
const RELIC_STONE_WARD := Color(0.4, 0.5, 0.6)
const RELIC_VITAL_CHARM := Color(0.6, 0.3, 0.35)
const RELIC_IRON_IDOL := Color(0.45, 0.45, 0.5)

# ── Beat / encounter categories (choice cards; map_strip shares these once its WIP lands) ────
const BEAT_BOSS := Color(0.7, 0.4, 0.9)
const BEAT_RELIC := Color(0.85, 0.7, 0.3)
const BEAT_REST := Color(0.4, 0.75, 0.45)
const BEAT_EVENT := Color(0.45, 0.55, 0.8)
const BEAT_COMBAT := Color(0.7, 0.35, 0.35)

# ── Combat view (portraits, HP bars, cooldown ring, ally state) ──────────────
const PORTRAIT_PLAYER := Color(0.2, 0.3, 0.5)
const PORTRAIT_ENEMY := Color(0.5, 0.2, 0.22)
const HP_BAR_BG := Color(0.12, 0.12, 0.14)
const HP_BAR_FILL := Color(0.4, 0.75, 0.35)
const COOLDOWN_RING := Color(0.95, 0.95, 0.95)
const ALLY_DOWNED := Color(0.45, 0.45, 0.45)     # darken a downed (dead) ally — alpha 1, not transparency

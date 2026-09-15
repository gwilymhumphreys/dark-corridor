class_name Colours
## Central colour palette (decision: one home for colours, like Balance for tuning numbers). Every
## gameplay / UI colour lives here so it is editable in one place and shared without duplication —
## an applier item references the SAME colour as the status it applies, the map and choice cards
## share one beat palette, etc. British 'colours' for the file; Godot's `Color` keeps its API spelling.
##
## Static variables, not constants, so an interface palette file can replace them by name
## (docs/systems/interface_palette.md). They keep constant-style names so every `Colours.X` use
## reads the same. Treat them as constants everywhere else.
##
## NOTE: a couple of colours still live at their use site by design — pure dev/debug tints (e.g.
## the corridor "see gaps" magenta), which never ship.

# ── Statuses ─────────────────────────────────────────────────────────────────
# Each StatusEffect subclass AND its appliers reference the same colour (applier = status colour).
static var STATUS_BLOCK: Color = Color(0.3, 0.6, 1.0)
static var STATUS_POISON: Color = Color(0.4, 0.8, 0.2)
static var STATUS_WEAK: Color = Color(0.6, 0.4, 0.7)
static var STATUS_VULNERABLE: Color = Color(0.85, 0.5, 0.2)
static var STATUS_BLIND: Color = Color(0.9, 0.9, 0.55)
static var STATUS_SILENCE: Color = Color(0.5, 0.5, 0.5)
static var STATUS_SPORES: Color = Color(0.45, 0.8, 0.7)     # placeholder fungal teal — owner re-tints
static var STATUS_DECAY: Color = Color(0.55, 0.4, 0.35)     # placeholder rot brown — owner re-tints
static var STATUS_EMPOWERED: Color = Color(0.95, 0.75, 0.2) # placeholder might gold (Armourer empower) — owner re-tints

# ── Combat payloads / item panels ────────────────────────────────────────────
static var DAMAGE: Color = Color(0.9, 0.2, 0.2)             # the generic attack red
static var HEAL: Color = Color(0.3, 0.9, 0.4)
static var ARCANE: Color = Color(0.5, 0.2, 0.7)             # Hex Bolt (item-targeting)
static var ENEMY_CLAW: Color = Color(0.8, 0.4, 0.1)

# ── Relic panels ─────────────────────────────────────────────────────────────
static var RELIC_STONE_WARD: Color = Color(0.4, 0.5, 0.6)
static var RELIC_VITAL_CHARM: Color = Color(0.6, 0.3, 0.35)
static var RELIC_IRON_IDOL: Color = Color(0.45, 0.45, 0.5)

# ── Beat / encounter categories (choice cards; map_strip shares these once its WIP lands) ────
static var BEAT_BOSS: Color = Color(0.7, 0.4, 0.9)
static var BEAT_RELIC: Color = Color(0.85, 0.7, 0.3)
static var BEAT_REST: Color = Color(0.4, 0.75, 0.45)
static var BEAT_EVENT: Color = Color(0.45, 0.55, 0.8)
static var BEAT_COMBAT: Color = Color(0.7, 0.35, 0.35)

# ── Combat view (portraits, HP bars, cooldown ring, ally state) ──────────────
static var PORTRAIT_PLAYER: Color = Color(0.2, 0.3, 0.5)
static var PORTRAIT_ALLY: Color = Color(0.22, 0.28, 0.4)
static var PORTRAIT_ENEMY: Color = Color(0.5, 0.2, 0.22)
static var HP_BAR_BG: Color = Color(0.1, 0.1, 0.12)
static var HP_BAR_FILL: Color = Color(0.4, 0.75, 0.4)
static var ENEMY_HP_BAR_BG: Color = Color(0.12, 0.06, 0.06)
static var ENEMY_HP_BAR_FILL: Color = Color(0.72, 0.22, 0.22)
static var POTION: Color = Color(0.3, 0.7, 0.45)            # the potion slot swatch
static var COOLDOWN_RING: Color = Color(0.95, 0.95, 0.95)
static var ALLY_DOWNED: Color = Color(0.45, 0.45, 0.45)     # darken a downed (dead) ally — alpha 1, not transparency

# ── Map strip (1D progress map) ──────────────────────────────────────────────
# BEAT_BOSS / BEAT_RELIC above are shared with the choice cards; these are map-strip-only.
static var MAP_TRACK: Color = Color(0.4, 0.4, 0.45)
static var MAP_CURRENT_HALO: Color = Color(0.95, 0.92, 0.55)
static var MAP_CLEARED: Color = Color(0.5, 0.46, 0.3)       # a cleared beat — dim gold
static var MAP_ARROW: Color = Color(0.55, 0.55, 0.6)        # the scroll chevrons
static var MAP_LABEL: Color = Color(0.85, 0.85, 0.88)       # the "Act N" label
static var MAP_ROLLED_BEAT: Color = Color(0.65, 0.4, 0.4)   # a beat whose type is rolled on arrival

# ── Tooltip ──────────────────────────────────────────────────────────────────
# PLACEHOLDER rarity tint and changed-value accent — the colour treatment is the owner's call (tooltips.md).
static var RARITY_COMMON: Color = Color(1.0, 1.0, 1.0)
static var RARITY_UNCOMMON: Color = Color(0.6, 0.85, 1.0)
static var RARITY_RARE: Color = Color(1.0, 0.85, 0.4)
static var TOOLTIP_CHANGED: Color = Color(0.95, 0.92, 0.55)

# ── Interface (screen backgrounds and the theme) ─────────────────────────────
# The UI_PANEL_* and UI_TEXT_* colours match the greys drawn in the theme's images and set as its
# font colours. An interface palette recolours the theme by mapping each grey onto these, dark to light.
static var UI_BACKGROUND: Color = Color(0.04, 0.04, 0.05)
static var UI_BACKGROUND_WEAR: Color = Color8(51, 51, 51)          # background print wear marks (background_wear.md)
static var UI_BACKGROUND_WEAR_LIGHT: Color = Color8(123, 120, 120)
static var UI_BORDER: Color = Color8(153, 41, 34)                  # the printed border around the corridor (print_frame.md)
static var UI_PANEL_SHADOW: Color = Color8(0, 0, 0)
static var UI_PANEL: Color = Color8(31, 31, 31)
static var UI_PANEL_EDGE: Color = Color8(51, 51, 51)
static var UI_PANEL_LIGHT: Color = Color8(123, 120, 120)
static var UI_TEXT_DISABLED: Color = Color(0.35, 0.35, 0.35)
static var UI_TEXT_PRESSED: Color = Color(0.5, 0.5, 0.5)
static var UI_TEXT_DIM: Color = Color(0.6, 0.6, 0.66)
static var UI_TEXT_BUTTON: Color = Color(0.75, 0.75, 0.75)
static var UI_TEXT: Color = Color(1.0, 1.0, 1.0)

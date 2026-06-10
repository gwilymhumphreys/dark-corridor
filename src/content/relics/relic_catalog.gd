class_name RelicCatalog
## The relic definitions (decision #23 — authored in GDScript, keyed by Id). Stone Ward
## is the starting relic (combat-start block). Vital Charm + Iron Idol are the placeholder
## REWARD relics (granted by the reward routing — RELIC / ELITE / boss beats; #2): they
## prove both relic shapes (a direct max-HP mod + a combat-start status). Lazily built.

const STONE_WARD := 'stone_ward'
const VITAL_CHARM := 'vital_charm'
const IRON_IDOL := 'iron_idol'

# What a relic reward draws from (the RunManager's grant). Stone Ward is starting-only —
# not a reward. The owner curates this pool with the real relic content.
const REWARD_POOL: Array = [VITAL_CHARM, IRON_IDOL]

static var _defs: Dictionary = {}


static func get_def(id: String) -> RelicDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('RelicCatalog: unknown relic id "%s"' % id)
  return _defs[id]


static func _build() -> void:
  _defs[STONE_WARD] = _stone_ward()
  _defs[VITAL_CHARM] = _vital_charm()
  _defs[IRON_IDOL] = _iron_idol()


static func _stone_ward() -> RelicDef:
  var d := RelicDef.new()
  d.id = STONE_WARD
  d.name_key = 'Stone Ward'
  d.kind = RelicDef.Kind.COMBAT_START_STATUS
  d.status_id = 'block'
  d.status_count = Balance.RELIC_STONE_WARD_BLOCK
  d.panel_color = Colours.RELIC_STONE_WARD
  return d


## Placeholder reward relic — a direct run-state mod (max-HP growth, applied once on grant).
static func _vital_charm() -> RelicDef:
  var d := RelicDef.new()
  d.id = VITAL_CHARM
  d.name_key = 'Vital Charm'
  d.kind = RelicDef.Kind.MAX_HP_BONUS
  d.max_hp_bonus = Balance.RELIC_VITAL_CHARM_MAX_HP
  d.panel_color = Colours.RELIC_VITAL_CHARM
  return d


## Placeholder reward relic — a second combat-start-block relic (stacks with Stone Ward).
static func _iron_idol() -> RelicDef:
  var d := RelicDef.new()
  d.id = IRON_IDOL
  d.name_key = 'Iron Idol'
  d.kind = RelicDef.Kind.COMBAT_START_STATUS
  d.status_id = 'block'
  d.status_count = Balance.RELIC_IRON_IDOL_BLOCK
  d.panel_color = Colours.RELIC_IRON_IDOL
  return d

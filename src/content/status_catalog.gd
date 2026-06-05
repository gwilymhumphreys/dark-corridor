class_name StatusCatalog
## The status definitions (decision #23 — authored in GDScript, keyed by the
## StatusDef.Type enum). Lazily built once. Phase 1 covers the three shapes:
## block (pool), poison (periodic DoT), weak (a timed debuff stand-in).

static var _defs: Dictionary = {}


static func get_def(type: int) -> StatusDef:
  if _defs.is_empty():
    _build()
  return _defs[type]


static func _build() -> void:
  var block := StatusDef.new()
  block.type = StatusDef.Type.BLOCK
  block.shape = StatusDef.Shape.POOL
  block.stacking = StatusDef.Stacking.ADD
  block.color = Color(0.3, 0.6, 1.0)
  block.name_key = 'Block'
  _defs[block.type] = block

  var poison := StatusDef.new()
  poison.type = StatusDef.Type.POISON
  poison.shape = StatusDef.Shape.PERIODIC
  poison.stacking = StatusDef.Stacking.ADD
  poison.tick_interval = Balance.POISON_TICK_INTERVAL
  poison.damage_per_tick = Balance.POISON_DAMAGE_PER_TICK
  poison.color = Color(0.4, 0.8, 0.2)
  poison.name_key = 'Poison'
  _defs[poison.type] = poison

  var weak := StatusDef.new()
  weak.type = StatusDef.Type.WEAK
  weak.shape = StatusDef.Shape.TIMED
  weak.stacking = StatusDef.Stacking.REFRESH
  weak.duration = Balance.SAMPLE_DEBUFF_DURATION
  weak.color = Color(0.6, 0.4, 0.7)
  weak.name_key = 'Weak'
  _defs[weak.type] = weak

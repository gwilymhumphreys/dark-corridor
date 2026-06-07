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

  # Weak — the outgoing-damage stat-status (#6): while it sits on an actor, that actor's
  # outgoing DAMAGE payloads are scaled at fire time. A timed % debuff (cascade-safe).
  var weak := StatusDef.new()
  weak.type = StatusDef.Type.WEAK
  weak.shape = StatusDef.Shape.TIMED
  weak.stacking = StatusDef.Stacking.REFRESH
  weak.duration = Balance.STATUS_WEAK_DURATION
  weak.outgoing_damage_mult = Balance.STATUS_WEAK_DAMAGE_MULT
  weak.color = Color(0.6, 0.4, 0.7)
  weak.name_key = 'Weak'
  _defs[weak.type] = weak

  # Vulnerable — the incoming-damage stat-status (#6): damage to its holder is amplified
  # in the absorber pipeline's amplifier stage (before block). A timed % debuff.
  var vulnerable := StatusDef.new()
  vulnerable.type = StatusDef.Type.VULNERABLE
  vulnerable.shape = StatusDef.Shape.TIMED
  vulnerable.stacking = StatusDef.Stacking.REFRESH
  vulnerable.duration = Balance.STATUS_VULNERABLE_DURATION
  vulnerable.incoming_damage_mult = Balance.STATUS_VULNERABLE_DAMAGE_MULT
  vulnerable.color = Color(0.85, 0.5, 0.2)
  vulnerable.name_key = 'Vulnerable'
  _defs[vulnerable.type] = vulnerable

  var silence := StatusDef.new()
  silence.type = StatusDef.Type.SILENCE
  silence.shape = StatusDef.Shape.STATIC
  silence.gates = true
  silence.color = Color(0.5, 0.5, 0.5)
  silence.name_key = 'Silence'
  _defs[silence.type] = silence

  # Blind — the evasion stat-status (spore_engine_prd Cap 2): the holder's attacks WHIFF
  # while it's active (distinct from silence's "doesn't fire"). Placeholder for the owner's
  # blinding spore. Timed; re-application refreshes the duration (design's "extend").
  var blind := StatusDef.new()
  blind.type = StatusDef.Type.BLIND
  blind.shape = StatusDef.Shape.TIMED
  blind.stacking = StatusDef.Stacking.REFRESH
  blind.duration = Balance.STATUS_BLIND_DURATION
  blind.causes_evasion = true
  blind.color = Color(0.9, 0.9, 0.55)
  blind.name_key = 'Blind'
  _defs[blind.type] = blind

class_name StatusRegistry
## Maps a status string id (#23) to a creator for its StatusEffect subclass — the polymorphic
## replacement for StatusCatalog. One registration line per status; the behaviour lives in the
## class file. Lazily built once, like the other catalogs. New statuses are authored as a class
## file + one line here (docs/systems/status_manager.md).

static var _creators: Dictionary = {}


static func _build() -> void:
  _creators[ShieldStatus.ID] = func() -> StatusEffect: return ShieldStatus.new()
  _creators[PoisonStatus.ID] = func() -> StatusEffect: return PoisonStatus.new()
  _creators[BurnStatus.ID] = func() -> StatusEffect: return BurnStatus.new()
  _creators[RegenStatus.ID] = func() -> StatusEffect: return RegenStatus.new()
  _creators[WeakStatus.ID] = func() -> StatusEffect: return WeakStatus.new()
  _creators[VulnerableStatus.ID] = func() -> StatusEffect: return VulnerableStatus.new()
  _creators[SilenceStatus.ID] = func() -> StatusEffect: return SilenceStatus.new()
  _creators[BlindStatus.ID] = func() -> StatusEffect: return BlindStatus.new()
  _creators[SporesStatus.ID] = func() -> StatusEffect: return SporesStatus.new()
  _creators[DecayStatus.ID] = func() -> StatusEffect: return DecayStatus.new()
  _creators[BleedStatus.ID] = func() -> StatusEffect: return BleedStatus.new()
  _creators[EmpoweredStatus.ID] = func() -> StatusEffect: return EmpoweredStatus.new()
  _creators[AttackBonusStatus.ID] = func() -> StatusEffect: return AttackBonusStatus.new()
  _creators[AttackPercentBonusStatus.ID] = func() -> StatusEffect: return AttackPercentBonusStatus.new()


static func create(id: String) -> StatusEffect:
  if _creators.is_empty():
    _build()
  if not _creators.has(id):
    push_error('StatusRegistry: unknown status id "%s"' % id)
    return null
  return _creators[id].call()


static func has(id: String) -> bool:
  if _creators.is_empty():
    _build()
  return _creators.has(id)

class_name MechanicRegistry
## Maps a mechanic string id to its Mechanic subclass — one shared instance per id (docs/plans/
## mechanics.md). Lazily built once, like StatusRegistry. New mechanics are authored as a class
## file + one line here.


static var _mechanics: Dictionary = {}


static func _build() -> void:
  _mechanics[AttackMechanic.ID] = AttackMechanic.new()
  _mechanics[HealMechanic.ID] = HealMechanic.new()
  _mechanics[ShieldMechanic.ID] = ShieldMechanic.new()
  _mechanics[PoisonMechanic.ID] = PoisonMechanic.new()
  _mechanics[BurnMechanic.ID] = BurnMechanic.new()
  _mechanics[RegenMechanic.ID] = RegenMechanic.new()
  _mechanics[BleedMechanic.ID] = BleedMechanic.new()
  _mechanics[ChargeMechanic.ID] = ChargeMechanic.new()
  _mechanics[DechargeMechanic.ID] = DechargeMechanic.new()
  _mechanics[CritMechanic.ID] = CritMechanic.new()


static func get_mechanic(id: String) -> Mechanic:
  if _mechanics.is_empty():
    _build()
  if not _mechanics.has(id):
    push_error('MechanicRegistry: unknown mechanic id "%s"' % id)
    return null
  return _mechanics[id]


static func has(id: String) -> bool:
  if _mechanics.is_empty():
    _build()
  return _mechanics.has(id)


## How much of a shield a hit of this mechanic uses (1.0 = normal). An empty or unknown id
## uses the default 1.0.
static func shield_multiplier(id: String) -> float:
  if id == '':
    return 1.0
  if not has(id):
    return 1.0
  return get_mechanic(id).shield_multiplier()


## The registry holds one shared instance per id, so a choice made while the game is running
## has to be written into those instances. Call this after `IconSlots.set_icon` to update
## every already-built instance in place.
static func refresh_icons() -> void:
  for id: String in _mechanics:
    var mechanic: Mechanic = _mechanics[id]
    mechanic.icon = IconSlots.icon_for(id)

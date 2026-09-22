class_name EnemyPools
## Which enemies each act uses (docs/systems/enemy.md). An enemy in no list is authored but never met,
## the same way an item in no pool is never drafted. Size a regular enemy to its act's points range in
## docs/plans/encounter_points_budget.md.
##
## Both lists start empty: an empty regular list leaves every fight on its encounter's authored
## enemies, and an empty boss list leaves the boss fight on its own. Built lazily into `_by_act` so
## tests can put fixture lists in place (FixtureContent).

## One Array of EnemyCatalog ids per act. A generated fight (regular or elite) draws from these.
const REGULAR: Array = [
  [],
  [],
  [],
]

## One Array of EnemyCatalog ids per act: that act's boss fight, left to right.
const BOSS: Array = [
  [],
  [],
  [],
]

static var _by_act: Dictionary = {}   # 'regular' / 'boss' -> Array of Array[String], one per act


## The enemy ids a generated fight in `act` draws from.
static func regular(act: int) -> Array[String]:
  return _list('regular', act)


## The enemy ids of the boss fight that ends `act`. Empty = the boss encounter's own enemies.
static func boss(act: int) -> Array[String]:
  return _list('boss', act)


static func _list(kind: String, act: int) -> Array[String]:
  if _by_act.is_empty():
    _build()
  var acts: Array = _by_act[kind]
  var ids: Array[String] = []
  if act >= 0 and act < acts.size():
    ids.assign(acts[act])
  return ids


static func _build() -> void:
  _by_act['regular'] = REGULAR.duplicate(true)
  _by_act['boss'] = BOSS.duplicate(true)

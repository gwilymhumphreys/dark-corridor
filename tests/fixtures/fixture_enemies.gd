class_name FixtureEnemies
## Plain enemy definitions for tests (docs/systems/testing.md). FixtureContent adds the three below
## under their own ids and also puts the plain fixture enemy in place of every authored enemy, under
## the authored id, so an authored id still resolves but tuning a real enemy cannot change what a
## test sees.
##
## The numbers are fixture constants and must NOT be pulled from Balance, for the same reason as the
## ones in fixture_items.gd.

const ID: String = 'fixture_enemy'
const BIG_ID: String = 'fixture_big_enemy'
const ALLY_ID: String = 'fixture_ally'

const HP: float = 20.0
const BIG_HP: float = 60.0
const ALLY_HP: float = 15.0


## A fixture enemy under `id`: fixed health and one fixture claw.
static func enemy(id: String = ID) -> EnemyDef:
  return _def(id, 'Fixture Enemy', HP)


## A larger enemy, for tests that need two enemy sizes (a points draw).
static func big_enemy() -> EnemyDef:
  return _def(BIG_ID, 'Fixture Big Enemy', BIG_HP)


## A small actor for summons and recruited allies.
static func ally() -> EnemyDef:
  return _def(ALLY_ID, 'Fixture Ally', ALLY_HP)


static func _def(id: String, name_key: String, max_hp: float) -> EnemyDef:
  var d := EnemyDef.new()
  d.id = id
  d.name_key = name_key
  d.portrait = 'res://assets/portraits/enemies/goblin_01.png'
  d.max_hp = max_hp
  d.item_ids = [FixtureItems.enemy_attack().id]
  return d

class_name FixtureEnemies
## Plain enemy definitions for whole-run tests (docs/systems/testing.md). FixtureRun puts one in
## place of every authored enemy, under the authored id, so the map's encounters still find their
## enemies but tuning a real enemy cannot change what a test sees.
##
## Every enemy becomes the same fixture enemy, the boss included. Its numbers are fixture constants
## and must NOT be pulled from Balance, for the same reason as the ones in fixture_items.gd.

const HP: float = 20.0


## A fixture enemy under `id`: fixed health and one fixture claw.
static func enemy(id: String) -> EnemyDef:
  var d := EnemyDef.new()
  d.id = id
  d.name_key = 'Fixture Enemy'
  d.portrait = 'res://assets/portraits/enemies/goblin_01.png'
  d.max_hp = HP
  d.item_ids = [FixtureItems.enemy_attack().id]
  return d

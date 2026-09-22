class_name EnemyDef
extends ActorDef
## An authored enemy, ally or summon (docs/systems/enemy.md) — NOT a class, just data: the ActorDef
## fields plus an authored board of item ids. make_actor() builds the Actor and gives it Items from
## the ids. Tier / signature come later.

var item_ids: Array[String] = []     # Array[String] -> ItemCatalog ids, in board order


func _init() -> void:
  max_hp = Balance.ENEMY_PLACEHOLDER_HP


## What this enemy is worth in points (docs/design/item_heuristics.md): the health the player has
## to spend to kill it, plus what its items spend. A fight is assembled by drawing enemies until
## their points reach the beat's target.
func points() -> float:
  var total: float = max_hp
  for id: String in item_ids:
    total += ItemPoints.spend(ItemCatalog.get_def(id))
  return total


## The Actor at full health with its authored board.
func make_actor() -> Actor:
  var actor: Actor = super.make_actor()
  for item_id: String in item_ids:
    actor.board.append(Item.new(ItemCatalog.get_def(item_id), actor))
  return actor

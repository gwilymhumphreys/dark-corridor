class_name EnemyDef
extends ActorDef
## An authored enemy, ally or summon (docs/systems/enemy.md) — NOT a class, just data: the ActorDef
## fields plus an authored board of item ids. make_actor() builds the Actor and gives it Items from
## the ids. Tier / signature come later.

var item_ids: Array[String] = []     # Array[String] -> ItemCatalog ids, in board order
var item_levels: Array[int] = []     # the level of each item in item_ids, by index; 1 where missing (decision #61)
var relic_ids: Array[String] = []    # Array[String] -> RelicCatalog ids, built into Actor.relics


func _init() -> void:
  max_hp = Balance.ENEMY_PLACEHOLDER_HP


## What this enemy is worth in points (docs/design/item_heuristics.md): the health the player has
## to spend to kill it, plus what its items spend. A fight is assembled by drawing enemies until
## their points reach the beat's target. A levelled item spends its points times Item.level_scale,
## as its values are.
func points() -> float:
  var total: float = max_hp
  for i in item_ids.size():
    total += ItemPoints.spend(ItemCatalog.get_def(item_ids[i])) * Item.level_scale(item_level(i))
  return total


## The level of the item at `index` in item_ids: its item_levels entry, or 1 when there is none.
func item_level(index: int) -> int:
  return item_levels[index] if index < item_levels.size() else 1


## The Actor at full health with its authored board (each item at its level) and relics.
func make_actor() -> Actor:
  var actor: Actor = super.make_actor()
  for i in item_ids.size():
    var item := Item.new(ItemCatalog.get_def(item_ids[i]), actor)
    item.level = item_level(i)
    actor.board.append(item)
  for relic_id: String in relic_ids:
    actor.relics.append(Item.new(RelicCatalog.get_def(relic_id), actor))
  return actor

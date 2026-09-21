class_name EnemyDef
extends RefCounted
## An authored enemy (docs/systems/enemy.md) — NOT a class, just data: HP + an authored board
## of item ids (the per-enemy attack item + any shared utility). The Encounter
## instantiates an Actor from this and gives it Items from the ids. Tier /
## signature come later.

var id: String = ''
var name_key: String = ''
var portrait: String = ''            # res:// path of the portrait shown in an ally slot (assets/portraits/enemies/); empty = none
# The folder under assets/sound-effects/ whose recordings play when this enemy is hit
# (docs/systems/audio.md). Empty = the shared combat/hurt folder.
var hurt_sound: String = ''
var max_hp: float = Balance.ENEMY_PLACEHOLDER_HP
var item_ids: Array[String] = []     # Array[String] -> ItemCatalog ids, in board order


## What this enemy is worth in points (docs/design/item_heuristics.md): the health the player has
## to spend to kill it, plus what its items spend. A fight is assembled by drawing enemies until
## their points reach the beat's target.
func points() -> float:
  var total: float = max_hp
  for id: String in item_ids:
    total += ItemPoints.spend(ItemCatalog.get_def(id))
  return total

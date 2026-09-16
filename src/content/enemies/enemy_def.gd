class_name EnemyDef
extends RefCounted
## An authored enemy (docs/systems/enemy.md) — NOT a class, just data: HP + an authored board
## of item ids (the per-enemy attack item + any shared utility). The Encounter
## instantiates an Actor from this and gives it Items from the ids. Tier /
## signature come later.

var id: String = ''
var name_key: String = ''
var portrait: String = ''            # res:// path of the portrait shown in an ally slot (assets/portraits/enemies/); empty = none
var max_hp: float = Balance.ENEMY_PLACEHOLDER_HP
var item_ids: Array[String] = []     # Array[String] -> ItemCatalog ids, in board order

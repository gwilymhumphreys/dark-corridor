class_name EnemyDef
extends RefCounted
## An authored enemy (enemy_prd) — NOT a class, just data: HP + an authored board
## of item ids (the per-enemy attack item + any shared utility). The Encounter
## instantiates an Actor from this and gives it Items from the ids. Tier /
## signature come later.

var id: int = -1
var name_key: String = ''
var max_hp: float = Balance.ENEMY_PLACEHOLDER_HP
var item_ids: Array = []     # Array[int] -> ItemCatalog ids, in board order

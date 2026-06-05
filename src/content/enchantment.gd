class_name Enchantment
extends RefCounted
## An enchantment instance (content_prd) — attaches to a host Item (one per item),
## carries its def. The Item's fire pipeline reads it to scale payload values, and
## it's saved as part of the board snapshot (decision #26 — a permanent item
## modifier, not a combat-scoped status). Held by `Item.enchant`.

var def: EnchantDef


func _init(enchant_def: EnchantDef) -> void:
  def = enchant_def

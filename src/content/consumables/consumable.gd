class_name Consumable
extends RefCounted
## A consumable instance (docs/systems/content.md) — a potion in the player's run-state reserve.
## Carries its def; the Combat manager activates it on a throw-potion intent (driven
## by RunManager.throw_potion). No Ticker — it doesn't accrue toward firing. Saved
## as run-state (by id).

var def: ConsumableDef


func _init(consumable_def: ConsumableDef) -> void:
  def = consumable_def

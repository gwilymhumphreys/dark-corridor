class_name DecayStatus
extends StatusEffect
## Decay — the item-targeted use-status (docs/systems/item_creation_and_decay.md Cap 2). Block's
## structural twin: block is a pool of count on an ACTOR drained by incoming damage that removes
## ITSELF when empty; decay is a pool of count on an ITEM drained by that item FIRING that removes
## the ITEM when empty. State = `count` (activations remaining). Not time-driven (no ticker) and not
## damage-consumed (not block's absorb) — drained by the holder's fire. Reapply STACKS (adds charges
## — the base default = "top up"). Combat-scoped like every status (#26). Reads on flesh (rots away)
## and non-flesh (wears out) alike; flavour rides the ITEM name, not the keyword.

const ID := 'decay'


func _init() -> void:
  id = ID
  name_key = 'Decay'
  desc_key = 'The affected item is destroyed after a number of uses.'   # PLACEHOLDER desc — owner writes
  color = Colours.STATUS_DECAY


## The holder item just fired and resolved its payload (so the final activation still LANDED —
## "decay 2" = two full hits, then removal). Spend one activation; when none remain, ask the
## Combat manager (via ctx) to remove the host item — the individual-live-item removal path.
func on_holder_fired(item, ctx) -> void:
  count -= 1.0
  if count <= 0.0 and ctx != null:
    ctx.remove_item(item)

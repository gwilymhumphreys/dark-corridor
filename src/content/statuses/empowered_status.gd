class_name EmpoweredStatus
extends StatusEffect
## Empowered (PLACEHOLDER name — owner's to rename) — the Smith's Mighty Blow buff (docs/design/
## smith.md → The empower engine). A CONSUMED COUNTER (like Spores / shield — no timer, persists
## until spent): `count` is the stacks held, each of which raises the damage of one attack by
## `Balance.EMPOWER_MULT`. Any item's attack counts, whatever its type tags. The two hooks split by path:
##   - outgoing_bonus (PULL, PURE) — raises an attack while a stack is held. The item only asks for
##     it on an attack effect (Item._scaled_value). It runs on the read-only tooltip-preview path too
##     (Item.display_value), so it MUST NOT mutate state; one stack raises ONE attack, never count times.
##   - on_owner_item_fired (PUSH, real fire) — uses up exactly ONE stack when an item with an attack
##     fires, so holding N stacks raises the next N attacks.
## Reapply STACKS (the base additive default — adds another stack).

const ID := 'empowered'


func _init() -> void:
  id = ID
  name_key = 'Empowered'                          # PLACEHOLDER name — owner's to rename
  desc_key = 'Your next {0} gets +{1}% damage'
  color = Colours.STATUS_EMPOWERED
  icon = 'res://assets/icons/statuses/aura_flex_nb.png'


## The attack icon, then the bonus as a percentage (Balance.EMPOWER_MULT 1.5 reads "50").
func desc_args() -> Array:
  return [{'t': 'icon', 'id': AttackMechanic.ID}, TooltipContent.fmt((Balance.EMPOWER_MULT - 1.0) * 100.0)]


## Raise an attack's damage while a stack is held, as a positive percentage bonus
## (Balance.EMPOWER_MULT 1.5 = +50%). PURE — no mutation (this also runs in Item.display_value's
## tooltip preview; using up a stack lives on on_owner_item_fired).
func outgoing_bonus(target, item = null) -> Dictionary:
  if count > 0 and item != null:
    return {'percent': Balance.EMPOWER_MULT - 1.0}
  return {}


## An item of the holder's just fired (the real-fire path): use up exactly ONE stack if the item has
## an attack. An item with no attack spends nothing (it had no attack to raise). Returns true when
## drained to zero (the Combat manager removes it + runs on_expire).
func on_owner_item_fired(_actor, item, _ctx) -> bool:
  if count > 0 and item != null and _has_attack(item):
    count -= 1
    return count <= 0
  return false


func _has_attack(item) -> bool:
  for effect: ItemEffect in item.def.effects:
    if effect.mechanic == AttackMechanic.ID:
      return true
  return false

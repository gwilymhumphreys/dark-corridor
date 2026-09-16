class_name EmpoweredStatus
extends StatusEffect
## Empowered (PLACEHOLDER name — owner's to rename) — the Armourer's Mighty Blow buff (docs/design/
## armourer.md → The empower engine). A CONSUMED COUNTER (like Spores / block — no timer, persists
## until spent): `count` is the banked charges, each of which DOUBLES one WEAPON attack. The two hooks
## split by path:
##   - modify_outgoing (PULL, PURE) — doubles a weapon-typed DAMAGE payload while a charge is banked.
##     It runs on the read-only tooltip-preview path too (Item.display_value), so it MUST NOT mutate
##     state; one charge = x2 of ONE attack, never x2^count.
##   - on_owner_item_fired (PUSH, real fire) — spends exactly ONE charge per weapon attack, so banking
##     N charges doubles the next N weapon attacks (not all-on-one, which would be a spiky x2^N nuke).
## Both hooks scope on the firing item's `weapon` type tag, so a spell / skill attack is NOT doubled.
## Reapply STACKS (the base additive default — banks another charge). Assumption: weapons deal damage
## (the consume keys on a weapon firing; the double on a weapon DAMAGE payload).

const ID := 'empowered'


func _init() -> void:
  id = ID
  name_key = 'Empowered'                          # PLACEHOLDER name — owner's to rename
  desc_key = 'Doubles your next weapon attack.'   # PLACEHOLDER desc — owner writes
  color = Colours.STATUS_EMPOWERED
  icon = 'res://assets/icons/statuses/aura_flex_nb.png'


## Double a WEAPON attack's outgoing DAMAGE while a charge is banked. PURE — no mutation (this also
## runs in Item.display_value's tooltip preview; the charge-spend lives on on_owner_item_fired). Gated
## on the firing `item` being a weapon, so a spell / skill damage attack is left at its base value.
func modify_outgoing(amount: float, target, item = null, ctx = null) -> float:
  if count > 0.0 and item != null and item.def.types.has(ItemType.WEAPON):
    return amount * Balance.EMPOWER_MULT
  return amount


## A weapon of the holder's just fired (the real-fire path): spend exactly ONE charge. A non-weapon
## fire spends nothing (its attack was never doubled). Returns true when drained to zero (the Combat
## manager removes it + runs on_expire).
func on_owner_item_fired(_actor, item, _ctx) -> bool:
  if count > 0.0 and item != null and item.def.types.has(ItemType.WEAPON):
    count -= 1.0
    return count <= 0.0
  return false

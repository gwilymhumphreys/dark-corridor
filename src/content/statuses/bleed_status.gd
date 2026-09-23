class_name BleedStatus
extends StatusEffect
## Bleed — an enemy-applied wound that cashes out when the bleeding actor is HIT BY AN ATTACK
## (mechanic from grail; docs/design/mechanic_ideas.md). Each time the holder is hit by an attack,
## it takes `count` damage, then loses a stack (count -= 1); removed at zero. Not time-driven
## (no ticker) and not a pool absorb: triggered by the attack landing on the holder (the
## on_holder_attacked hook), so poison/burn ticks, bleed's own damage and outside-set damage
## never trigger it. Carries the applying flags, so an applier can make it UNBLOCKABLE (Bone
## Spear does — the holder's own shield then can't soak the wound; the per-effect lever, #5).
## Reapply STACKS.

const ID := 'bleed'


func _init() -> void:
  id = ID
  # Presentation is written once, in the mechanic (docs/systems/mechanics.md) — copy it here so the
  # combat log, status icons and combat summary keep reading the status's own fields.
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(ID)
  name_key = mechanic.name_key
  desc_key = mechanic.desc_key
  icon = mechanic.icon
  color = Colours.BLEED


## The holder was just hit by an attack: bite the holder for the current stack count, then lose a
## stack; return true when drained (the Combat manager removes it). Passes `flags`, so an
## unblockable bleed bypasses the holder's own shield per bite (#5). Actors only — items have no
## HP (a bleed authored onto an item ticks down harmlessly, cf. PeriodicStatus).
func on_holder_attacked(target, _ctx) -> bool:
  if target is Actor:
    target.take_damage(count, flags, id)
  count -= 1
  return count <= 0

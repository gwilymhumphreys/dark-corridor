class_name BleedStatus
extends StatusEffect
## Bleed — an enemy-applied wound that cashes out on the bleeding actor's OWN tempo (mechanic from
## grail; docs/design/mechanic_ideas.md). Each time one of the holder's items activates, the holder
## takes `count` damage, then loses a stack (count -= 1); removed at zero. Self-paying-down — a fixed
## TRIANGULAR total (bleed 3 = 3+2+1 over the holder's next three activations), so its RATE tracks the
## holder's item tempo while the TOTAL stays fixed. Not time-driven (no ticker) and not a pool absorb:
## drained by the holder FIRING — the actor-level twin of Decay's on_holder_fired (which drains on the
## item it sits on). Carries the applying flags, so an applier can make it UNBLOCKABLE (Bone Spear
## does — the holder's own block then can't soak the wound; the per-effect lever, #5). Reapply STACKS.

const ID := 'bleed'


func _init() -> void:
  id = ID
  name_key = 'Bleed'
  desc_key = 'Each time the bleeding side acts, it takes damage and loses a stack.'   # PLACEHOLDER desc — owner writes
  color = Colours.DAMAGE   # PLACEHOLDER tint — no dedicated bleed colour yet (owner's to add)


## One of the holder's items just fired: bite the holder for the current stack count, then lose a
## stack; return true when drained (the Combat manager removes it). Passes `flags`, so an unblockable
## bleed bypasses the holder's own block per bite (#5). Bites on ANY fire — it ignores the firing
## `item` (unlike the weapon-scoped empower). Actors only — items have no HP (a bleed authored onto an
## item ticks down harmlessly, cf. PeriodicStatus).
func on_owner_item_fired(actor, _item, _ctx) -> bool:
  if actor is Actor:
    actor.take_damage(count, flags)
  count -= 1.0
  return count <= 0.0

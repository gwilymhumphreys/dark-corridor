class_name CombatHooks
extends RefCounted
## The hook functions an actor's statuses and its relics' passives share (docs/systems/status_manager.md
## → Hooks). StatusEffect extends this; so does RelicPassive (docs/systems/content.md → Relic). The
## StatusManager and the Combat manager call these on every hook holder of an actor, relic passives
## first and then statuses (StatusManager.hooks_of), so a passive works the same way as a status
## without being one. Each subclass overrides only the hooks it needs.


## Called when one of the holder actor's items FIRES. Receives the firing `item`, so a hook can scope
## to a weapon attack (the Smith empower uses up a stack here). This is the REAL-fire path (not the
## tooltip preview), so consuming state belongs here, not in outgoing_bonus. Returns true when a
## status has expired (the Combat manager removes it + runs on_expire); a passive's return is
## ignored. Default no-op.
func on_owner_item_fired(_actor, _item, _ctx) -> bool:
  return false


## Called when an ATTACK delivery lands on the holder actor (after its damage resolves —
## docs/systems/mechanics.md → Bleed). Poison/burn ticks, a status's own damage and outside-set
## damage never call it, so a hook cannot repeat within a step. Returns true when a status has
## expired (the Combat manager removes it + runs on_expire); a passive's return is ignored. Default
## no-op.
func on_holder_attacked(_target, _ctx) -> bool:
  return false


# --- modifiers (PULL — the engine queries these at the pipeline stage, in hooks_of order, so
#     composition stays deterministic (#24) and amplify-before-absorb holds (#6)). ---

## This hook's bonus to an outgoing effect of `mechanic_id` at fire time, as
## `{'flat': float, 'percent': float}` (either key may be left out; `percent` is a signed fraction,
## +1.0 for double, -0.25 for a quarter less). `target` is the holder (the owner actor, or the item a
## status sits on); `item` is the firing item, so a hook can scope to a weapon attack. Each subclass
## decides which mechanics it raises. StatusManager.combine applies every bonus by the rule in
## docs/systems/mechanics.md → Combining bonuses. MUST stay PURE — it also runs on the read-only
## tooltip-preview path (Item.display_value), so nothing here may mutate state (using up an Empowered
## stack lives on on_owner_item_fired).
func outgoing_bonus(_target, _item = null, _mechanic_id: String = AttackMechanic.ID) -> Dictionary:
  return {}


func modify_incoming(amount: float, _target, _ctx) -> float:
  return amount


## Absorb from an incoming hit, returning the unabsorbed remainder (Shield overrides; mutates pool).
## `mechanic_id` names the mechanic that dealt the damage — the shield pool spends its multiplier
## against it (docs/systems/mechanics.md → Shield).
func absorb(amount: float, _incoming_flags: int, _target, _ctx, _mechanic_id: String = '') -> float:
  return amount


func causes_evasion() -> bool:
  return false

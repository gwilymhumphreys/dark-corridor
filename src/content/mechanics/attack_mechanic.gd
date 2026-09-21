class_name AttackMechanic
extends Mechanic
## Attack — the mechanic for a direct hit from an item or potion (docs/systems/mechanics.md).
## Deals damage to the target.

const ID := 'attack'


func _init() -> void:
  id = ID
  name_key = 'Attack'
  desc_key = 'Deals damage to the target.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = ''


func color() -> Color:
  return Colours.ATTACK


## The weapon layer of a hit (docs/systems/audio.md): the firing item's `attack_sound` picks
## the folder, and a shielded target adds `/shielded` below it, because a hit on a shielded
## target rings off metal and one on an unshielded target does not. A thrown consumable has no
## firing item and uses the plain folder. An empty folder falls back up its parents, so a
## weapon whose folder is not filled in still sounds.
##
## The shield is read now rather than when the hit landed, so a hit that emptied a shield plays
## the plain sound (docs/plans/sound_effect_organisation.md Section 5).
func sound_key(delivery: Delivery) -> String:
  var path: String = 'mechanics/attack'
  if delivery.source is Item and delivery.source.def != null and delivery.source.def.attack_sound != '':
    path += '/' + delivery.source.def.attack_sound
  if delivery.target is Actor and StatusManager.has_status(delivery.target, ShieldStatus.ID):
    path += '/shielded'
  return path


func land(delivery: Delivery, combat: CombatManager) -> void:
  if delivery.target is Actor:   # damage/heal are actor-targeted; item shapes carry statuses
    var dealt: float = delivery.target.take_damage(delivery.value, delivery.flags, AttackMechanic.ID)
    combat.bus.publish(EventBus.Event.APPLIED, AttackMechanic.ID, delivery.source_actor,
        combat._source_item_of(delivery))
    if combat.combat_log != null:
      # `delivery.value` is the GROSS hit (pre-shield); `dealt` is the NET HP lost — log both
      # (gross = the threat metric, survives a full shield; net = what HP actually did).
      combat.combat_log.on_damage(combat._delivery_source_name(delivery),
          combat._delivery_source_side(delivery), delivery.target.display_name,
          combat._side_of(delivery.target), dealt, combat.timekeeper.sim_time, delivery.value)
    # Bleed (and any other attack-triggered status) cashes out on the hit — after the damage
    # resolves, and only if the target survived it (docs/systems/mechanics.md → Bleed).
    if delivery.target.is_alive():
      combat._on_holder_attacked(delivery.target)

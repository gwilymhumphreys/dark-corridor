class_name DraftCard
extends Button
## One reward candidate in the draft overlay (draft_prd): the item's family-colour
## block + its value, the name, and rarity, with a hover tooltip. A themed Button with
## UIJuice; the overlay connects `pressed` to the pick index. Reads an ItemDef; writes
## nothing. Player-facing text is localized.

@onready var _color: ColorRect = $Color
@onready var _value: Label = $Value
@onready var _name: Label = $Name
@onready var _rarity: Label = $Rarity


func setup(def: ItemDef) -> void:
  var value: int = int(def.effects[0].value) if not def.effects.is_empty() else 0
  var rarity: String = _rarity_name(def.rarity)
  _color.color = def.panel_color
  _value.text = str(value)
  _name.text = tr(def.name_key)
  _rarity.text = rarity
  tooltip_text = tr('{0} — {1}\nvalue {2} · every {3}s').format(
    [tr(def.name_key), rarity, value, def.cooldown])


## The localized rarity label. tr() wraps the literals here (not the call sites) so
## they are POT-extractable — see docs/reference/localization.md.
func _rarity_name(rarity: int) -> String:
  match rarity:
    ItemDef.Rarity.UNCOMMON:
      return tr('Uncommon')
    ItemDef.Rarity.RARE:
      return tr('Rare')
    _:
      return tr('Common')

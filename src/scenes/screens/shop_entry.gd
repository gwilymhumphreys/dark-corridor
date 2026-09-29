class_name ShopEntry
extends VBoxContainer
## One of the goods in the shop panel (docs/systems/run_screen.md): the good as a `RewardOption`
## (the same cell and tooltip as the draft panel) with a buy button under it showing the price.
## Pressing either emits `buy_pressed`; ShopOverlay forwards it. Reads the good; writes nothing.

signal buy_pressed()

@onready var option: RewardOption = $Option
@onready var _buy: Button = $Buy


## Show `good` (ItemDef, RelicDef or ConsumableDef) and its `price`. Call after the entry is in the
## tree.
func setup(good: Variant, price: int) -> void:
  option.setup(Item.new(good))
  _buy.text = tr('{0} gold').format([price])
  option.pressed.connect(_on_pressed)
  _buy.pressed.connect(_on_pressed)


## A sold good reads "Sold"; a good the player cannot afford, or has bought, cannot be pressed.
func show_state(can_buy: bool, sold: bool) -> void:
  option.disabled = not can_buy
  _buy.disabled = not can_buy
  if sold:
    _buy.text = tr('Sold')


func _on_pressed() -> void:
  buy_pressed.emit()

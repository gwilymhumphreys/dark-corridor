class_name ShopEntry
extends VBoxContainer
## One of the goods in the shop panel (docs/systems/run_screen.md): the good as a `RewardOption`
## (the same cell and tooltip as the draft panel) with a buy button under it showing the price.
## Pressing either emits `buy_pressed`; ShopOverlay forwards it. While the good spins (RewardSpin)
## the buy button is blank, so the price gives no hint of the good; it shows when the good lands.
## Reads the good; writes nothing.

signal buy_pressed()

@onready var option: RewardOption = $Option
@onready var _buy: Button = $Buy

var _price_text: String = ''


## Show `good` (ItemDef, RelicDef or ConsumableDef) at `level` and its `price`. Call after the entry
## is in the tree.
func setup(good: Variant, price: int, level: int = 1) -> void:
  var item := Item.new(good)
  item.level = level
  option.setup(item)
  _price_text = tr('{0} gold').format([price])
  _buy.text = _price_text
  option.pressed.connect(_on_pressed)
  _buy.pressed.connect(_on_pressed)
  option.spin_started.connect(func() -> void: _buy.text = '')
  option.landed.connect(func() -> void: _buy.text = _price_text)


## A sold good reads "Sold"; a good the player cannot afford, or has bought, cannot be pressed.
func show_state(can_buy: bool, sold: bool) -> void:
  option.disabled = not can_buy
  _buy.disabled = not can_buy
  if sold:
    _price_text = tr('Sold')
    _buy.text = _price_text


func _on_pressed() -> void:
  buy_pressed.emit()

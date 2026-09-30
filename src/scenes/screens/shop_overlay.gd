class_name ShopOverlay
extends Control
## The shop panel (docs/systems/run_screen.md, docs/systems/encounter.md → Shops): the shop's goods as
## `ShopEntry`s, each with its price, the player's gold, and Reroll and Leave buttons, on a panel
## placed in the corridor area like the draft panel. Pressing a good emits `bought(index)` →
## RunManager.buy; the run screen then calls `refresh`. Reroll emits `rerolled` → RunManager.reroll_shop;
## the run screen then calls `show_goods`. Leave emits `left` → RunManager.leave_shop. Hovering a good
## shows its tooltip (the run screen asks inspectable_at each frame). Reads the run; writes nothing.

signal bought(index: int)
signal rerolled()
signal left()

const SHOP_ENTRY: PackedScene = preload('res://src/scenes/screens/shop_entry.tscn')

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Title
@onready var _gold: Label = $Panel/Gold
@onready var _cards: HBoxContainer = $Panel/Cards
@onready var _reroll: Button = $Panel/RerollButton

var _entries: Array[ShopEntry] = []


func _exit_tree() -> void:
  _entries.clear()


## Show the shop `title` and one entry per good on sale in `run` (RunManager.shop_goods).
func setup(title: String, run: RunManager) -> void:
  _title.text = title
  show_goods(run)


## Show one entry per good on sale in `run`, replacing the entries shown before (after a reroll).
func show_goods(run: RunManager) -> void:
  for entry: ShopEntry in _entries:
    entry.free()   # at once, not queued: never called from an entry's own signal
  _entries.clear()
  var goods: Array = run.shop_goods()
  for i in goods.size():
    var entry: ShopEntry = SHOP_ENTRY.instantiate()
    _cards.add_child(entry)
    entry.setup(goods[i], RunManager.price_of(goods[i]))
    entry.buy_pressed.connect(_on_buy_pressed.bind(i))
    _entries.append(entry)
  refresh(run)


## Show the player's gold, which goods can still be bought and what a reroll costs.
func refresh(run: RunManager) -> void:
  _gold.text = tr('Your gold: {0}').format([run.gold])
  _reroll.text = tr('Reroll ({0} gold)').format([run.reroll_price()])
  _reroll.disabled = not run.can_reroll()
  for i in _entries.size():
    _entries[i].show_state(run.can_buy(i), run.is_sold(i))


## The good's icon under `point` as {item, rect (global), side} for the tooltip cluster, or {}.
func inspectable_at(point: Vector2) -> Dictionary:
  for entry: ShopEntry in _entries:
    var option: RewardOption = entry.option
    if option.item() != null and option.get_global_rect().has_point(point):
      return {'item': option.item(), 'rect': option.get_global_rect(), 'side': TooltipCluster.Side.LEFT}
  return {}


## True when `point` is over the shop panel (board items hidden behind it must not show tooltips).
func covers(point: Vector2) -> bool:
  return _panel.get_global_rect().has_point(point)


func _on_buy_pressed(index: int) -> void:
  bought.emit(index)


func _on_reroll_pressed() -> void:
  rerolled.emit()


func _on_leave_pressed() -> void:
  left.emit()

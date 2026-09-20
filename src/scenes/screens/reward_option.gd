class_name RewardOption
extends Button
## One option in the reward overlay (docs/systems/draft.md): a button wrapping the same `ItemCell`
## the board uses, so a reward answers the pointer like every other control the player picks — the
## border on hover, the press squash, the release pulse and the click sound of `UIJuice`
## (docs/systems/control_feedback.md). The button itself draws nothing (`ButtonBare`); the juice
## draws the highlight on the cell's frame. Reads the Item it is handed; writes nothing.

@onready var cell: ItemCell = $Cell


## Bind the offered item. Call after the option is in the tree.
func setup(item: Item) -> void:
  cell.show_cooldown = false   # a reward is not in a fight, so no cooldown fill covers the icon
  cell.setup(item)


## The live Item this option offers — the tooltip reads it.
func item() -> Item:
  return cell.item

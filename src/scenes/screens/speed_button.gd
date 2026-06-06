class_name SpeedButton
extends Button
## The always-visible battle-speed dial on the run HUD (ui_layout_prd). One click
## cycles ×1 → ×2 → ×3 → ×1 via Game.cycle_battle_speed(); the label reflects the
## live Game.battle_speed. The dial is a session preference on Game and this button is
## thin glue — the run screen applies the speed to each fight's Timekeeper base scale.


func _ready() -> void:
  pressed.connect(Game.cycle_battle_speed)
  Game.battle_speed_changed.connect(_refresh)
  _refresh(Game.battle_speed)


# The multiplier glyph is digits + 'x' — locale-neutral, so no tr() (localization.md).
func _refresh(scale: float) -> void:
  text = '%dx' % roundi(scale)


func _exit_tree() -> void:
  if Game.battle_speed_changed.is_connected(_refresh):
    Game.battle_speed_changed.disconnect(_refresh)

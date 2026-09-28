class_name EnemyHud
extends CharacterPanel
## An enemy in the framed combat view, floating above the corridor occupant (docs/systems/ui_layout.md):
## a CharacterPanel with the portrait hidden (the enemy's sprite is right below it), so its name,
## HP bar, status row and board items. setup() builds the item row. The HUD is hidden through the
## approach and fade_in() brings it up when the fight starts. Reads the Actor; writes nothing. The
## VFX wall reads hud_centre / cell_centre.

const CELL_SEPARATION: float = 20.0   # the Items separation in enemy_hud.tscn

var _fade: Tween
var _max_width: float = 0.0


## `timekeeper` drives the cells' fire recoil on the combat clock; `max_width` (>0)
## budgets the item row — cells shrink so a big loadout fits its share of the panel.
func setup(target: Actor, timekeeper: Timekeeper = null, max_width: float = 0.0) -> void:
  set_actor(target)
  show_name(tr(target.display_name) if target.display_name != '' else '')
  _max_width = max_width
  build_items(timekeeper, _fit_cell_px(PrintLook.print_setting('medium_token_size')))


## Resize the item cells to `px` (the `medium_token_size` print setting), or smaller if the row would
## be too long for its width.
func set_item_size(px: float) -> void:
  resize_items(_fit_cell_px(px))


# `px`, or less so the whole item row fits `_max_width` (when set).
func _fit_cell_px(px: float) -> float:
  if _max_width <= 0.0 or actor == null or actor.board.size() + actor.relics.size() == 0:
    return px
  var n: float = float(actor.board.size() + actor.relics.size())
  return minf(px, (_max_width - CELL_SEPARATION * (n - 1.0)) / n)


func _exit_tree() -> void:
  if _fade != null:
    _fade.kill()
    _fade = null
  super()


## Show this HUD, fading it up over `duration` seconds — the fight starting (the HUDs are hidden
## through the approach) or a summon appearing mid-fight.
func fade_in(duration: float) -> void:
  if _fade != null:
    _fade.kill()
  visible = true
  modulate.a = 0.0
  _fade = create_tween()
  _fade.tween_property(self, 'modulate:a', 1.0, duration)


func hud_centre() -> Vector2:
  return global_position + size * 0.5

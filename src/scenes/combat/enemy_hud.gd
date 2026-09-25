class_name EnemyHud
extends CharacterPanel
## An enemy in the framed combat view, floating above the corridor occupant (docs/systems/ui_layout.md):
## a CharacterPanel with the portrait hidden (the enemy's sprite is right below it), so its name,
## HP bar, status row and board items. setup() builds the item row. The HUD is hidden through the
## approach and fade_in() brings it up when the fight starts. Reads the Actor; writes nothing. The
## VFX wall reads hud_centre / cell_centre.

const CELL_PX: float = 45.0   # smaller than the player's prominent board
const CELL_SEPARATION: float = 20.0   # the Items separation in enemy_hud.tscn

var _fade: Tween


## `timekeeper` drives the cells' fire recoil on the combat clock; `max_width` (>0)
## budgets the item row — cells shrink so a big loadout fits its share of the panel.
func setup(target: Actor, timekeeper: Timekeeper = null, max_width: float = 0.0) -> void:
  set_actor(target)
  show_name(tr(target.display_name) if target.display_name != '' else '')
  var cell_px: float = CELL_PX
  if max_width > 0.0 and not target.board.is_empty():
    var n: float = float(target.board.size())
    cell_px = minf(CELL_PX, (max_width - CELL_SEPARATION * (n - 1.0)) / n)
  build_items(timekeeper, cell_px)


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

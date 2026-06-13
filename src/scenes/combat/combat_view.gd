class_name CombatView
extends Control
## The swappable combat-view surface (docs/systems/ui_layout.md: framed vs full-screen is
## ONE swappable sub-scene — this base is that seam made real). The run screen and the
## VFX wall talk to THIS surface only, so a full-screen variant drops in by extending it.
## Every method is a no-op default; a variant overrides what it renders.

## Emitted when a potion slot is clicked — a throw-potion intent the run screen forwards
## to RunManager.throw_potion (which activates it through the Combat manager).
signal potion_thrown(index: int)


## Bind the live fight (the view reads the full rosters off the CombatManager).
func bind(_cm: CombatManager, _player_actor: Actor, _potions: Array) -> void:
  pass


## Stop reading the live fight before it is torn down (called right before the view frees).
func release() -> void:
  pass


## Approach controls — the run screen walks the enemies in from depth.
func set_enemy_depth(_depth_cells: float) -> void:
  pass


func set_gliding(_on: bool) -> void:
  pass


## The hover surface for the slow-mo intent.
func mouse_over_inspectable(_point: Vector2) -> bool:
  return false


func refresh_potions(_potions: Array) -> void:
  pass


# --- layout lookups the VFX wall reads (global / screen space) ---------------

func item_pos(_item: Item) -> Vector2:
  return Vector2.ZERO


## An actor's on-screen point. Untyped param: the wall passes whatever a Delivery holds.
func actor_pos(_actor) -> Vector2:
  return Vector2.ZERO


## A Delivery's landing point — an Actor OR an Item (item-targeting effects).
func target_pos(_target) -> Vector2:
  return Vector2.ZERO

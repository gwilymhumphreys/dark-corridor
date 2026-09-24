class_name StatusIcons
extends HBoxContainer
## A row of status icons for one actor (docs/systems/run_screen.md): one StatusIcon (the status's
## icon on its colour) per active OUTSIDE-set status. The mechanic statuses are shown by the health
## bar instead. Used by the enemy HUD and the player portrait. Rebuilt each frame since statuses
## accrue / expire during combat. Reads the actor; writes nothing.

const STATUS_ICON: PackedScene = preload('res://src/scenes/combat/status_icon.tscn')

var actor: Actor = null


func _process(_delta: float) -> void:
  refresh()


func refresh() -> void:
  var outside: Array[StatusEffect] = []
  if actor != null:
    for s in actor.statuses:
      if not MechanicRegistry.has(s.id):
        outside.append(s)
  var want: int = outside.size()
  visible = want > 0   # an empty row takes no room, so it adds no gap to the column it sits in
  while get_child_count() > want:
    # Deferred frees for nodes (CLAUDE.md) — but remove from the tree NOW so the
    # child count this loop reads actually shrinks.
    var status_icon: Node = get_child(get_child_count() - 1)
    remove_child(status_icon)
    status_icon.queue_free()
  while get_child_count() < want:
    add_child(STATUS_ICON.instantiate())
  for i in want:
    (get_child(i) as StatusIcon).show_status(outside[i])


func _exit_tree() -> void:
  actor = null

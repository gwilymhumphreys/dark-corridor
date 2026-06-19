extends Control
## Throwaway host (like combat_sandbox) to WATCH the tooltip cluster: builds one player Item,
## mounts an ItemCell near the right edge + a TooltipCluster, and force-shows the cluster over the
## cell every frame (so a hover isn't needed). The verification harness for the tooltip system —
## run it directly:
##   /c/projects/godot/godot --path . res://src/scenes/dev/tooltip_demo.tscn
## `--shot` captures a frame then quits. Excluded from extract_pot (dev host; text stays English).

const TOOLTIP_CLUSTER: PackedScene = preload('res://src/scenes/ui/tooltip/tooltip_cluster.tscn')
const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')

var _item: Item
var _cell: ItemCell
var _cluster: TooltipCluster


func _ready() -> void:
  # A multi-effect RARE (damage + Blind) so the cluster shows a value, a status chip, and a column.
  var actor := Actor.new(100.0)
  _item = Item.new(ItemCatalog.get_def(ItemCatalog.POCKET_SHROOMS), actor)
  actor.board.append(_item)
  # Apply Weak to the owner so the DAMAGE value renders a live (changed) number — the ▼ highlight.
  StatusManager.apply(actor, 'weak', 1.0)

  _cell = ITEM_CELL.instantiate()
  add_child(_cell)
  _cell.position = Vector2(2180, 620)   # near the right edge (2560 wide) → cluster flies left
  _cell.setup(_item)

  _cluster = TOOLTIP_CLUSTER.instantiate()
  add_child(_cluster)

  if '--shot' in OS.get_cmdline_args() or '--shot' in OS.get_cmdline_user_args():
    _auto_shot()


func _process(_delta: float) -> void:
  if _cell == null or _cluster == null:
    return
  # Force the cluster to track the cell (mouse = the cell centre, so the bridge holds it open).
  var rect: Rect2 = _cell.get_global_rect()
  _cluster.update_target({'item': _item, 'rect': rect, 'side': TooltipCluster.Side.LEFT}, rect.get_center())


func _auto_shot() -> void:
  await get_tree().create_timer(1.5).timeout
  await RenderingServer.frame_post_draw
  var img: Image = get_viewport().get_texture().get_image()
  var path: String = 'user://tooltip_shot.png'
  img.save_png(path)
  print('SHOT_SAVED:', ProjectSettings.globalize_path(path))
  get_tree().quit()

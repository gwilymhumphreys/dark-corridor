class_name PencilLine
extends ColorRect
## A pencil line along the bottom of this rectangle, drawn by the board grid material
## (`PrintLook.grid_material`, docs/systems/print_frame.md) so it matches the item grid and the allies
## box: the same colour, width, wobble and gaps. Used for the write-in lines under the character
## sheet's Name and Class fields. Leave some height above the line for its wobble.


func _ready() -> void:
  material = PrintLook.grid_material
  RenderingServer.canvas_item_set_instance_shader_parameter(get_canvas_item(), 'underline', true)
  resized.connect(_push_size)
  _push_size()


func _push_size() -> void:
  RenderingServer.canvas_item_set_instance_shader_parameter(get_canvas_item(), 'box_size', size)


func _exit_tree() -> void:
  if resized.is_connected(_push_size):
    resized.disconnect(_push_size)

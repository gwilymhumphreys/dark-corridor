class_name KeywordIcon
## The one rule for drawing a keyword's or an icon slot's icon (docs/systems/tooltips.md).
##
## Two kinds of icon want opposite treatment. An icon slot glyph (under `assets/icons/mechanics/`)
## is a white shape, so it is tinted with the keyword's colour and drawn through the element
## material, which keeps the effects that would move a pixel off its palette colour switched off.
## Every other icon is painted pack art with its own colours, so it keeps white modulate and the
## picture material.
##
## Shared by the keyword chip, the keyword card and the tooltip panel's inline icons. Static only:
## nothing here is a node.

## Icons under this folder are icon slot glyphs.
const GLYPH_DIR: String = 'res://assets/icons/mechanics/'


## Set `rect`'s modulate and material for the kind of icon `icon_path` is.
static func dress(rect: TextureRect, icon_path: String, colour: Color) -> void:
  if icon_path.begins_with(GLYPH_DIR):
    rect.modulate = colour
    rect.material = InterfaceLook.element_material
  else:
    rect.modulate = Color.WHITE
    rect.material = InterfaceLook.material


## A square TextureRect of `size` pixels showing `id`'s icon, dressed by kind. `id` is a keyword id
## (a mechanic, a status or a `kw:` id) when the catalog has an entry for it, otherwise an icon slot
## id such as `charge_time`, which has no keyword card and so is drawn in the dim interface text
## colour. An id that resolves to neither gives an empty rect rather than an error.
static func make(id: String, size: int) -> TextureRect:
  var rect: TextureRect = _blank(size)
  var entry: Dictionary = KeywordCatalog.get_entry(id)
  var path: String = entry['icon'] if not entry.is_empty() else IconSlots.icon_for(id)
  var colour: Color = entry['color'] if not entry.is_empty() else Colours.UI_TEXT_DIM
  if path != '':
    rect.texture = load(path) as Texture2D
  dress(rect, path, colour)
  return rect


static func _blank(size: int) -> TextureRect:
  var rect := TextureRect.new()
  rect.custom_minimum_size = Vector2(size, size)
  rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  return rect

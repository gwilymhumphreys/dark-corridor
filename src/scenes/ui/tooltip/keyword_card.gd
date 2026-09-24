class_name KeywordCard
extends VBoxContainer
## Frameless keyword content (docs/systems/tooltips.md): the keyword's icon and its tinted name on
## one row, with its description under them. Returned BARE by a keyword chip's _make_custom_tooltip
## (Godot wraps it in the theme's TooltipPanel — the only frame), and wrapped in a PanelContainer for
## the cluster's keyword column. Built from a KeywordCatalog entry; an unknown id renders the bare id
## with no icon and no description (never crash).
##
## NOTE: setup() reads node refs via get_node (NOT @onready) because _make_custom_tooltip calls it
## BEFORE the card is added to the tree — the children exist from instantiate(), but _ready has not run.

const CARD_WIDTH: float = 320.0


func setup(id: String) -> void:
  var icon_rect: TextureRect = $Header/Icon
  var name_label: Label = $Header/Name
  var desc_label: RichTextLabel = $Desc
  var entry: Dictionary = KeywordCatalog.get_entry(id)
  if entry.is_empty():
    icon_rect.visible = false
    name_label.text = id
    desc_label.text = ''
    desc_label.visible = false
    return
  var icon_path: String = entry['icon']
  icon_rect.texture = load(icon_path) as Texture2D if icon_path != '' else null
  icon_rect.visible = icon_rect.texture != null
  KeywordIcon.dress(icon_rect, icon_path, entry['color'])
  name_label.text = tr(entry['name_key'])
  name_label.add_theme_color_override('font_color', entry['color'])
  var desc: String = tr(entry['desc_key']) if entry['desc_key'] != '' else ''
  var desc_args: Array = entry.get('desc_args', [])
  if not desc_args.is_empty():
    desc = _rich_desc(TooltipContent.interpolate(desc, desc_args), desc_label)
  desc_label.text = desc
  desc_label.visible = desc != ''


## A description with placeholders, as BBCode: its text, with each icon as an image as tall as a
## line of the description's text.
func _rich_desc(segs: Array, desc_label: RichTextLabel) -> String:
  var font: Font = desc_label.get_theme_font('normal_font')
  var icon_size: int = roundi(font.get_height(desc_label.get_theme_font_size('normal_font_size')))
  var out: String = ''
  for seg: Dictionary in segs:
    if seg['t'] == 'icon':
      out += KeywordIcon.bbcode(seg['id'], icon_size)
    else:
      out += (seg['s'] as String).replace('[', '[lb]')
  return out

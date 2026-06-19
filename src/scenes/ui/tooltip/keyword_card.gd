class_name KeywordCard
extends VBoxContainer
## Frameless keyword content (docs/systems/tooltips.md): a tinted name + its description. Returned
## BARE by a keyword chip's _make_custom_tooltip (Godot wraps it in the theme's TooltipPanel — the
## only frame), and wrapped in a PanelContainer for the cluster's keyword column. Built from a
## KeywordCatalog entry; an unknown id renders the bare id and no description (never crash).
##
## NOTE: setup() reads node refs via get_node (NOT @onready) because _make_custom_tooltip calls it
## BEFORE the card is added to the tree — the children exist from instantiate(), but _ready has not run.

const CARD_WIDTH: float = 320.0


func setup(id: String) -> void:
  var name_label: Label = $Name
  var desc_label: RichTextLabel = $Desc
  var entry: Dictionary = KeywordCatalog.get_entry(id)
  if entry.is_empty():
    name_label.text = id
    desc_label.text = ''
    desc_label.visible = false
    return
  name_label.text = tr(entry['name_key'])
  name_label.add_theme_color_override('font_color', entry['color'])
  var desc: String = tr(entry['desc_key']) if entry['desc_key'] != '' else ''
  desc_label.text = desc
  desc_label.visible = desc != ''

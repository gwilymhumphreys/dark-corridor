extends Node
## Builds the item browser page (docs/systems/item_browser.md): every item in the catalog, with
## the tooltip text the game generates for it, its icons, its types and which characters' pools
## and enemy boards it is on. Run through the wrapper:
##
##   tools/item_browser.sh
##
## It runs as a scene (tools/item_browser.tscn) rather than with --script, because the tooltip code
## it reuses refers to autoloads, which only exist once the scene tree has started.
##
## Reads the page template at TEMPLATE_PATH, puts the item data in place of DATA_MARKER as JSON
## (icons embedded as data URIs so the page is one file), and writes OUT_PATH.

const TEMPLATE_PATH: String = 'res://tools/item_browser.html'
const OUT_PATH: String = 'res://_temp/item_browser.html'
const DATA_MARKER: String = '/*ITEM_DATA*/null'
const ICON_SIZE: int = 128

const RARITY_NAMES: Dictionary = {
  ItemDef.Rarity.COMMON: 'common',
  ItemDef.Rarity.UNCOMMON: 'uncommon',
  ItemDef.Rarity.RARE: 'rare',
}

var _icons: Dictionary = {}      # res:// path -> data URI
var _keywords: Dictionary = {}   # keyword or icon slot id -> {name, desc, icon, color, glyph}


func _ready() -> void:
  var template: String = FileAccess.get_file_as_string(TEMPLATE_PATH)
  if template == '' or not template.contains(DATA_MARKER):
    push_error('item_browser: template missing or has no %s marker: %s' % [DATA_MARKER, TEMPLATE_PATH])
    get_tree().quit(1)
    return
  var data: Dictionary = _build_data()
  if data.is_empty():
    push_error('item_browser: an item failed to build; the page was not written')
    get_tree().quit(1)
    return
  var page: String = template.replace(DATA_MARKER, JSON.stringify(data))
  var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
  if file == null:
    push_error('item_browser: cannot write %s' % OUT_PATH)
    get_tree().quit(1)
    return
  file.store_string(page)
  file.close()
  print('item_browser: wrote %d items to %s' % [(data['items'] as Array).size(),
      ProjectSettings.globalize_path(OUT_PATH)])
  get_tree().quit(0)


## The page data, or an empty Dictionary when an item cannot be built (a script error in the item
## code leaves its definition null), so a broken export never replaces a working page.
func _build_data() -> Dictionary:
  var characters: Array = []
  var pools: Dictionary = {}   # item id -> Array of character ids
  for character_id: String in CharacterCatalog.ids():
    var character: CharacterDef = CharacterCatalog.get_def(character_id)
    characters.append({
      'id': character_id,
      'name': tr(character.name_key),
      'subtitle': tr(character.subtitle_key) if character.subtitle_key != '' else '',
    })
    for item_id: String in character.item_pool:
      _append_to(pools, item_id, character_id)
  for item_id: String in ColorlessPool.ITEMS:
    for character_id: String in CharacterCatalog.ids():
      _append_to(pools, item_id, character_id)

  var enemy_boards: Dictionary = {}   # item id -> Array of enemy names
  for enemy_id: String in EnemyCatalog.all_ids():
    var enemy: EnemyDef = EnemyCatalog.get_def(enemy_id)
    for item_id: String in enemy.item_ids:
      var enemy_name: String = tr(enemy.name_key)
      if not enemy_boards.has(item_id) or not (enemy_boards[item_id] as Array).has(enemy_name):
        _append_to(enemy_boards, item_id, enemy_name)

  var items: Array = []
  var tooltip := TooltipContent.new()
  for item_id: String in ItemCatalog.all_ids():
    var def: ItemDef = ItemCatalog.get_def(item_id)
    if def == null:
      return {}
    var content: Dictionary = tooltip.build(Item.new(def))
    if not content.has('lines'):
      return {}
    _register_keyword(IconSlots.CHARGE_TIME)
    for line: Array in content['lines']:
      _register_line_icons(line)
    for keyword_id: String in content['keyword_ids']:
      _register_keyword(keyword_id)
    items.append({
      'id': item_id,
      'name': content['title'],
      'icon': _icon_uri(def.icon),
      'rarity': RARITY_NAMES.get(def.rarity, 'common'),
      'rarity_color': '#' + _rarity_colour(def.rarity).to_html(false),
      'types': def.types,
      'type_line': content['type_line'],
      'cooldown': def.cooldown,
      'charge_line': content['charge_line'],
      'lines': content['lines'],
      'flavor': content['flavor'],
      'keyword_ids': content['keyword_ids'],
      'mechanics': def.mechanics,
      'crit_chance': def.crit_chance,
      'starting_uses': def.starting_uses,
      'points': ItemPoints.spend(def),
      'budget': ItemPoints.budget(def.cooldown),
      'unpriced': _has_unpriced_effect(def),
      'pools': pools.get(item_id, []),
      'enemies': enemy_boards.get(item_id, []),
    })

  var type_names: Dictionary = {}
  for type_id: String in ItemType.DISPLAY_NAMES:
    type_names[type_id] = tr(ItemType.display_name(type_id))

  return {
    'generated': Time.get_datetime_string_from_system(false, true),
    'default_character': CharacterCatalog.DEFAULT,
    'characters': characters,
    'types': type_names,
    'keywords': _keywords,
    'icons': _icons,
    'items': items,
  }


## True when an effect adds nothing in ItemPoints.spend (a status, summon or created item, or an
## unpriced mechanic such as regen), so the item's points undercount it.
func _has_unpriced_effect(def: ItemDef) -> bool:
  for effect: ItemEffect in def.effects:
    if effect.kind != Delivery.Kind.MECHANIC or effect.mechanic == RegenMechanic.ID:
      return true
  return false


func _register_line_icons(line: Array) -> void:
  for segment: Dictionary in line:
    if segment.get('t', '') == 'icon':
      _register_keyword(segment['id'])


## Records a keyword's name, description and icon once. An id with no keyword entry is an icon
## slot (charge_time), drawn in the dim text colour, as KeywordIcon.make does in the game.
func _register_keyword(id: String) -> void:
  if _keywords.has(id):
    return
  var entry: Dictionary = KeywordCatalog.get_entry(id)
  var path: String = entry['icon'] if not entry.is_empty() else IconSlots.icon_for(id)
  var colour: Color = entry['color'] if not entry.is_empty() else Colours.UI_TEXT_DIM
  _keywords[id] = {
    'name': tr(entry['name_key']) if not entry.is_empty() else IconSlots.display_name(id),
    'desc': tr(entry['desc_key']) if not entry.is_empty() else '',
    'icon': _icon_uri(path),
    'color': '#' + colour.to_html(false),
    'glyph': path.begins_with(KeywordIcon.GLYPH_DIR),
  }


## The key the page looks an icon up by (its res:// path), embedding the file the first time.
## '' when there is no icon or the file cannot be read. Icons are shrunk to ICON_SIZE pixels on
## their longest side to keep the page small.
func _icon_uri(path: String) -> String:
  if path == '':
    return ''
  if not _icons.has(path):
    var image: Image = Image.load_from_file(path)
    if image == null or image.is_empty():
      push_warning('item_browser: cannot read icon %s' % path)
      return ''
    var longest: int = maxi(image.get_width(), image.get_height())
    if longest > ICON_SIZE:
      var scale: float = float(ICON_SIZE) / longest
      image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)),
          Image.INTERPOLATE_LANCZOS)
    _icons[path] = 'data:image/png;base64,' + Marshalls.raw_to_base64(image.save_png_to_buffer())
  return path


func _rarity_colour(rarity: int) -> Color:
  match rarity:
    ItemDef.Rarity.UNCOMMON:
      return Colours.RARITY_UNCOMMON
    ItemDef.Rarity.RARE:
      return Colours.RARITY_RARE
  return Colours.RARITY_COMMON


func _append_to(map: Dictionary, key: String, value: String) -> void:
  if not map.has(key):
    map[key] = []
  (map[key] as Array).append(value)

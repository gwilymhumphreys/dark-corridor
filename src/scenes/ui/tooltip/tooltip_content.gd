class_name TooltipContent
## The tooltip content builder (docs/systems/tooltips.md): turns an Item into the structured
## content the main panel renders — a title, generated effect LINES (each a list of segments:
## plain text, a live VALUE, or a keyword CHIP), an optional authored flavor line, a stat block,
## and the catalog-gated keyword id list for the column. Pure data: no nodes, no side effects
## (values come from Item.display_value / base_value, which never mutate). Copy here is the
## baseline — templates and shape phrases are the owner's to refine.
##
## A line is an Array of segment Dictionaries:
##   {'t': 'text',  's': String}                          — literal copy
##   {'t': 'value', 's': String, 'changed': bool, 'dir': int}  — a live number (dir: +1 up / -1 down)
##   {'t': 'chip',  'id': String}                         — a keyword reference (status or mechanic)


## Build the full content Dictionary for `item`:
##   {title, rarity, panel_color, lines: Array[Array], flavor: String, stat_lines: Array[String],
##    keyword_ids: Array[String]}
## INSTANCE method (call `TooltipContent.new().build(item)`) because tr() — used by the line
## templates — is an Object method unavailable from a static context.
func build(item: Item) -> Dictionary:
  return {
    'title': tr(item.def.name_key),
    'rarity': item.def.rarity,
    'panel_color': item.def.panel_color,
    'lines': _effect_lines(item),
    'flavor': tr(item.def.description_key) if item.def.description_key != '' else '',
    'stat_lines': _stat_lines(item),
    'keyword_ids': keyword_ids(item),
  }


func _effect_lines(item: Item) -> Array:
  var lines: Array = []
  for effect: ItemEffect in item.def.effects:
    lines.append(_effect_line(item, effect))
  for sub: Dictionary in item.def.trigger_subs:
    var line: Array = _trigger_line(sub)
    if not line.is_empty():
      lines.append(line)
  return lines


func _effect_line(item: Item, effect: ItemEffect) -> Array:
  var value_seg: Dictionary = _value_seg(item, effect)
  match effect.kind:
    Delivery.Kind.DAMAGE:
      if effect.shape == ItemEffect.Shape.ALL_OPPONENTS:
        return _interpolate(tr('Deal {0} damage to all enemies'), [value_seg])
      return _interpolate(tr('Deal {0} damage to {1}'), [value_seg, _shape_text(effect.shape)])
    Delivery.Kind.HEAL:
      return _interpolate(tr('Heal {0}'), [value_seg])
    Delivery.Kind.APPLY_STATUS:
      var chip: Dictionary = {'t': 'chip', 'id': effect.status_id}
      if effect.shape == ItemEffect.Shape.SELF:
        return _interpolate(tr('Gain {0} {1}'), [value_seg, chip])
      return _interpolate(tr('Apply {0} {1}'), [value_seg, chip])
    Delivery.Kind.SUMMON:
      return _interpolate(tr('Summon {0}'), [_summon_text(effect)])
  return []


func _trigger_line(sub: Dictionary) -> Array:
  var filter = sub.get('filter', null)
  if filter is String and filter != '':
    return _interpolate(tr('When {0} is applied'), [{'t': 'chip', 'id': filter}])
  return _interpolate(tr('On trigger'), [])


static func _value_seg(item: Item, effect: ItemEffect) -> Dictionary:
  var disp: float = item.display_value(effect)
  var base: float = item.base_value(effect)
  var changed: bool = not is_equal_approx(disp, base)
  var dir: int = 0
  if changed:
    dir = 1 if disp > base else -1
  return {'t': 'value', 's': _fmt(disp), 'changed': changed, 'dir': dir}


func _stat_lines(item: Item) -> Array:
  return [tr('Every {0}s').format([_fmt(item.def.cooldown)])]


## The single-target DAMAGE line's {1} target phrase. Baseline copy (owner refines). Literal tr()
## calls (not a lookup table) so each phrase is POT-extractable.
func _shape_text(shape: int) -> Dictionary:
  var phrase: String
  match shape:
    ItemEffect.Shape.SELF:
      phrase = tr('yourself')
    ItemEffect.Shape.ALL_OPPONENTS:
      phrase = tr('all enemies')
    ItemEffect.Shape.OPPONENT_ITEM_RANDOM:
      phrase = tr('a random enemy item')
    ItemEffect.Shape.ALL_OPPONENT_ITEMS:
      phrase = tr('all enemy items')
    _:
      phrase = tr('the enemy')
  return {'t': 'text', 's': phrase}


func _summon_text(effect: ItemEffect) -> Dictionary:
  if effect.summon_def_id != '':
    var enemy_def: EnemyDef = EnemyCatalog.get_def(effect.summon_def_id)
    if enemy_def != null:
      return {'t': 'text', 's': tr(enemy_def.name_key)}
  return {'t': 'text', 's': tr('an ally')}


# --- keyword extraction (catalog-gated) --------------------------------------

## The keyword ids referenced by `item`, deduped, statuses first (in effect order) then mechanics
## (fixed order), keeping only those present in KeywordCatalog (docs/systems/tooltips.md). An absent
## id is silently dropped — that is how a mechanic is enabled (by authoring its catalog entry).
static func keyword_ids(item: Item) -> Array[String]:
  var ids: Array[String] = []
  # Statuses first, in effect order: applied statuses, then consumed-fuel statuses.
  for effect: ItemEffect in item.def.effects:
    if effect.kind == Delivery.Kind.APPLY_STATUS:
      _add_keyword(ids, effect.status_id)
    if effect.consume_id != '':
      _add_keyword(ids, effect.consume_id)
  for sub: Dictionary in item.def.trigger_subs:
    var filter = sub.get('filter', null)
    if filter is String:
      _add_keyword(ids, filter)
  # Then mechanics, in the catalog's fixed order — only those this item actually references.
  for mech: String in KeywordCatalog.MECHANIC_ORDER:
    if _item_uses_mechanic(item, mech):
      _add_keyword(ids, mech)
  return ids


static func _item_uses_mechanic(item: Item, mech: String) -> bool:
  match mech:
    KeywordCatalog.FUEL:
      return _any_effect(item, func(e): return e.consume_id != '')
    KeywordCatalog.SUMMON:
      return _any_effect(item, func(e): return e.kind == Delivery.Kind.SUMMON)
    KeywordCatalog.AOE:
      return _any_effect(item, func(e): return e.shape == ItemEffect.Shape.ALL_OPPONENTS or e.shape == ItemEffect.Shape.ALL_OPPONENT_ITEMS)
    KeywordCatalog.ITEM_TARGET:
      return _any_effect(item, func(e): return e.shape == ItemEffect.Shape.OPPONENT_ITEM_RANDOM or e.shape == ItemEffect.Shape.ALL_OPPONENT_ITEMS)
    KeywordCatalog.UNBLOCKABLE:
      return _any_effect(item, func(e): return (e.flags & Delivery.Flag.UNBLOCKABLE) != 0)
    KeywordCatalog.TRIGGER:
      return not item.def.trigger_subs.is_empty()
    KeywordCatalog.ENCHANT:
      return item.enchant != null
  return false


static func _any_effect(item: Item, predicate: Callable) -> bool:
  for effect: ItemEffect in item.def.effects:
    if predicate.call(effect):
      return true
  return false


static func _add_keyword(ids: Array[String], id: String) -> void:
  if id != '' and id not in ids and KeywordCatalog.has(id):
    ids.append(id)


# --- helpers -----------------------------------------------------------------

## Replace {0}, {1}, … in a (translated) template with the supplied segments, splitting the literal
## text around them into 'text' segments. The translated template controls word order, so the value
## and chip land wherever the translator places their placeholder.
static func _interpolate(template: String, args: Array) -> Array:
  var segs: Array = []
  var buf: String = ''
  var i: int = 0
  var n: int = template.length()
  while i < n:
    if template[i] == '{':
      var close: int = template.find('}', i)
      if close > i:
        var idx_str: String = template.substr(i + 1, close - i - 1)
        if idx_str.is_valid_int() and int(idx_str) < args.size():
          if buf != '':
            segs.append({'t': 'text', 's': buf})
            buf = ''
          var arg = args[int(idx_str)]
          segs.append(arg if arg is Dictionary else {'t': 'text', 's': str(arg)})
          i = close + 1
          continue
    buf += template[i]
    i += 1
  if buf != '':
    segs.append({'t': 'text', 's': buf})
  return segs


## Format a number with no trailing zeros (8.0 → "8", 1.5 → "1.5").
static func _fmt(v: float) -> String:
  if is_equal_approx(v, roundf(v)):
    return str(int(roundf(v)))
  return str(snappedf(v, 0.1))

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
##   {'t': 'icon',  'id': String}                         — a mechanic glyph (an IconSlots id, e.g. attack / heal)


## Build the full content Dictionary for `item`:
##   {title, rarity, panel_color, type_line: String, lines: Array[Array], flavor: String,
##    stat_lines: Array[String], keyword_ids: Array[String]}
## INSTANCE method (call `TooltipContent.new().build(item)`) because tr() — used by the line
## templates and the type line — is an Object method unavailable from a static context.
func build(item: Item) -> Dictionary:
  return {
    'title': tr(item.def.name_key),
    'rarity': item.def.rarity,
    'panel_color': item.def.panel_color,
    'type_line': _type_line(item.def.types),
    'lines': _effect_lines(item),
    'flavor': tr(item.def.description_key) if item.def.description_key != '' else '',
    'stat_lines': _stat_lines(item),
    'keyword_ids': keyword_ids(item),
  }


## The type line: each of `types` as its singular display name (translated), joined. An item with
## no tags gives '' (the panel then hides the line).
func _type_line(types: Array[String]) -> String:
  var names: Array[String] = []
  for tag: String in types:
    var name: String = ItemType.display_name(tag)
    if name != '':
      names.append(tr(name))
  # PLACEHOLDER — the joining word is the owner's call (how several tags read together is undecided)
  return ', '.join(names)


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
    Delivery.Kind.MECHANIC:
      # Attack and heal carry their mechanic's inline glyph in place of the old word; the status
      # mechanics (shield, and later poison / burn / bleed / regen) use the status templates with
      # the mechanic id as the chip.
      if effect.mechanic == AttackMechanic.ID:
        var icon_seg: Dictionary = {'t': 'icon', 'id': effect.mechanic}
        if effect.shape == ItemEffect.Shape.ALL_OPPONENTS:
          return _interpolate(tr('{0} {1} to all enemies'), [value_seg, icon_seg])
        return _interpolate(tr('{0} {1} to {2}'), [value_seg, icon_seg, _shape_text(effect.shape, effect.target_filter)])
      if effect.mechanic == HealMechanic.ID:
        # No tr(): the line is a value and a glyph with no words, so there is nothing to
        # translate and "{0} {1}" would be a meaningless entry in the translation template.
        return _interpolate('{0} {1}', [value_seg, {'t': 'icon', 'id': effect.mechanic}])
      # Charge and decharge move an item's cooldown bar by seconds, so their line names the
      # target items and the seconds, not a stack count.
      if effect.mechanic == ChargeMechanic.ID or effect.mechanic == DechargeMechanic.ID:
        return _interpolate(tr('{0} {1} by {2}s'),
            [{'t': 'chip', 'id': effect.mechanic}, _shape_text(effect.shape, effect.target_filter), value_seg])
      var chip: Dictionary = {'t': 'chip', 'id': effect.mechanic}
      if effect.shape == ItemEffect.Shape.SELF:
        return _interpolate(tr('Gain {0} {1}'), [value_seg, chip])
      return _interpolate(tr('Apply {0} {1}'), [value_seg, chip])
    Delivery.Kind.APPLY_STATUS:
      var chip: Dictionary = {'t': 'chip', 'id': effect.status_id}
      if effect.shape == ItemEffect.Shape.SELF:
        return _interpolate(tr('Gain {0} {1}'), [value_seg, chip])
      return _interpolate(tr('Apply {0} {1}'), [value_seg, chip])
    Delivery.Kind.SUMMON:
      return _interpolate(tr('Summon {0}'), [_summon_text(effect)])
  return []


func _trigger_line(sub: Dictionary) -> Array:
  # An ITEM_DESTROYED trigger is the Reclaim keyword (the destroy-payoff; tooltips.md), not generic.
  if sub.get('event', -1) == EventBus.Event.ITEM_DESTROYED:
    return _interpolate(tr('{0} as your items are destroyed'), [{'t': 'chip', 'id': KeywordCatalog.RECLAIM}])
  var filter: Variant = sub.get('filter', null)
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
  return {'t': 'value', 's': fmt(disp), 'changed': changed, 'dir': dir}


func _stat_lines(item: Item) -> Array:
  var lines: Array = [tr('Every {0}s').format([fmt(item.def.cooldown)])]
  if item.def.crit_chance > 0.0:
    lines.append(tr('Crit chance: {0}%').format([fmt(item.def.crit_chance * 100.0)]))
  return lines


## The target phrase an effect line's {2} / {1} placeholder stands in for. The actor shapes (SELF,
## ALL_OPPONENTS, the default "the enemy") are baseline copy and ignore `filter` — a filter narrows
## an ITEM pool, not an actor. The four item shapes read differently when `filter` is non-empty: a
## template with the filter's term in the gap ("all your {0} items"). A null or empty filter, or one
## whose term resolves to nothing, falls back to the unfiltered baseline phrase. Baseline copy is the
## owner's — every unfiltered phrase is byte-for-byte unchanged; the literal tr() calls (not a lookup
## table) keep each phrase and template POT-extractable.
func _shape_text(shape: int, filter: TargetFilter = null) -> Dictionary:
  if filter != null and not filter.is_empty() and _shape_has_item_pool(shape):
    var term: String = _filter_term(filter)
    if term != '':
      var template: String = _filtered_template(shape)
      if template != '':
        return {'t': 'text', 's': template.format([term])}
  # Actor shapes, an empty/null filter, or an unresolvable filter term: the unfiltered phrase.
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
    ItemEffect.Shape.OWN_ITEM_RANDOM:
      phrase = tr('a random item of yours')
    ItemEffect.Shape.ALL_OWN_ITEMS:
      phrase = tr('all your items')
    _:
      phrase = tr('the enemy')
  return {'t': 'text', 's': phrase}


## True when the shape targets an item pool (a filter can narrow it), false for actor shapes.
func _shape_has_item_pool(shape: int) -> bool:
  match shape:
    ItemEffect.Shape.OPPONENT_ITEM_RANDOM, ItemEffect.Shape.ALL_OPPONENT_ITEMS, \
    ItemEffect.Shape.OWN_ITEM_RANDOM, ItemEffect.Shape.ALL_OWN_ITEMS:
      return true
  return false


## The filtered-template literal for an item shape (owner's copy; '' for a shape with no filter form).
func _filtered_template(shape: int) -> String:
  match shape:
    ItemEffect.Shape.OPPONENT_ITEM_RANDOM:
      return tr('a random enemy {0} item')
    ItemEffect.Shape.ALL_OPPONENT_ITEMS:
      return tr('all enemy {0} items')
    ItemEffect.Shape.OWN_ITEM_RANDOM:
      return tr('a random {0} item of yours')
    ItemEffect.Shape.ALL_OWN_ITEMS:
      return tr('all your {0} items')
  return ''


## The word or words a filter's conditions resolve to — the term that fills {0} in an item shape's
## filtered template. A TYPE condition is its singular display name; a MECHANIC condition is the
## mechanic's name (an id that does not resolve is skipped, so a bad id cannot crash a tooltip).
## Several terms join with the mode's translated joining word. '' when no condition resolves —
## the caller then falls back to the unfiltered phrase rather than emit an empty {0}.
func _filter_term(filter: TargetFilter) -> String:
  var terms: Array[String] = []
  for condition: Dictionary in filter.conditions:
    var term: String = _condition_term(condition)
    if term != '':
      terms.append(term)
  if terms.is_empty():
    return ''
  if terms.size() == 1:
    return terms[0]
  return _join_terms(terms, filter.mode)


## The translated joining word for several filter terms, by mode (' and ' / ' or ').
func _join_terms(terms: Array[String], mode: int) -> String:
  # PLACEHOLDER — the joining word is the owner's call
  var joiner: String = tr(' and ') if mode == TargetFilter.Mode.ALL else tr(' or ')
  return joiner.join(terms)


## The term one condition resolves to: a TYPE id's lowercased singular display name, or a MECHANIC
## id's lowercased mechanic name ('' when the id does not resolve).
func _condition_term(condition: Dictionary) -> String:
  var id: String = condition.get('id', '')
  match condition.get('kind', TargetFilter.Kind.TYPE):
    TargetFilter.Kind.TYPE:
      var name: String = ItemType.display_name(id)
      return tr(name).to_lower() if name != '' else ''
    TargetFilter.Kind.MECHANIC:
      if not MechanicRegistry.has(id):
        return ''
      return tr(MechanicRegistry.get_mechanic(id).name_key).to_lower()
  return ''


func _summon_text(effect: ItemEffect) -> Dictionary:
  if effect.summon_def_id != '':
    var enemy_def: EnemyDef = EnemyCatalog.get_def(effect.summon_def_id)
    if enemy_def != null:
      return {'t': 'text', 's': tr(enemy_def.name_key)}
  return {'t': 'text', 's': tr('an ally')}


# --- keyword extraction (catalog-gated) --------------------------------------

## The keyword ids referenced by `item`, deduped (docs/systems/tooltips.md), built in three parts in
## this order, keeping only those present in KeywordCatalog (an absent id is silently dropped — that
## is how a mechanic keyword is gated off):
##   1. the authored `mechanics` list, in its own (alphabetical) order;
##   2. the derived non-mechanic ids, in effect order — an `APPLY_STATUS` effect's `status_id`, then
##      its `consume_id`, then each trigger subscription's `filter` when it is a String (statuses such
##      as weak, vulnerable, blind and spores);
##   3. the structural keywords, in `KeywordCatalog.MECHANIC_ORDER` (only those this item references).
## `_add_keyword` dedupes and gates every addition, so an id appearing in more than one part is added once.
static func keyword_ids(item: Item) -> Array[String]:
  var ids: Array[String] = []
  # 1. The authored mechanics list, in its own order (authored alphabetically; not re-sorted here).
  for mechanic_id: String in item.def.mechanics:
    _add_keyword(ids, mechanic_id)
  # 2. The derived non-mechanic ids, in effect order: applied statuses, consumed-fuel statuses, then
  #    trigger filters. Dropping this would remove those keyword cards from every status-applier.
  for effect: ItemEffect in item.def.effects:
    if effect.kind == Delivery.Kind.APPLY_STATUS:
      _add_keyword(ids, effect.status_id)
    if effect.consume_id != '':
      _add_keyword(ids, effect.consume_id)
  for sub: Dictionary in item.def.trigger_subs:
    var filter: Variant = sub.get('filter', null)
    if filter is String:
      _add_keyword(ids, filter)
  # 3. The structural keywords, in the catalog's fixed order — only those this item references.
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
      return _any_effect(item, func(e): return e.shape == ItemEffect.Shape.OPPONENT_ITEM_RANDOM \
          or e.shape == ItemEffect.Shape.ALL_OPPONENT_ITEMS \
          or e.shape == ItemEffect.Shape.OWN_ITEM_RANDOM or e.shape == ItemEffect.Shape.ALL_OWN_ITEMS)
    KeywordCatalog.UNBLOCKABLE:
      return _any_effect(item, func(e): return (e.flags & Delivery.Flag.UNBLOCKABLE) != 0)
    KeywordCatalog.TRIGGER:
      # Generic trigger — but an ITEM_DESTROYED sub surfaces Reclaim instead (below), not Trigger.
      for sub: Dictionary in item.def.trigger_subs:
        if sub.get('event', -1) != EventBus.Event.ITEM_DESTROYED:
          return true
      return false
    KeywordCatalog.RECLAIM:
      for sub: Dictionary in item.def.trigger_subs:
        if sub.get('event', -1) == EventBus.Event.ITEM_DESTROYED:
          return true
      return false
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
          var arg: Variant = args[int(idx_str)]
          segs.append(arg if arg is Dictionary else {'t': 'text', 's': str(arg)})
          i = close + 1
          continue
    buf += template[i]
    i += 1
  if buf != '':
    segs.append({'t': 'text', 's': buf})
  return segs


## Format a number with no trailing zeros (8.0 → "8", 1.5 → "1.5"). Public + static so other
## presentation (e.g. ItemCell's value pills) shares the one formatting rule.
static func fmt(v: float) -> String:
  if is_equal_approx(v, roundf(v)):
    return str(int(roundf(v)))
  return str(snappedf(v, 0.1))

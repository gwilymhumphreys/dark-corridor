extends GutTest
## Every item, potion, status and mechanic keyword names an icon file, and every character and enemy
## names a portrait file, that loads as a texture, so a renamed or missing picture fails here instead
## of showing an empty cell.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_every_item_has_an_icon() -> void:
  ItemCatalog.get_def(ItemCatalog.WEAPON)   # builds the catalog
  for id: String in ItemCatalog._defs:
    _assert_icon((ItemCatalog._defs[id] as ItemDef).icon, 'item %s' % id)


func test_every_potion_has_an_icon() -> void:
  ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT)   # builds the catalog
  for id: String in ConsumableCatalog._defs:
    _assert_icon((ConsumableCatalog._defs[id] as ConsumableDef).icon, 'potion %s' % id)


func test_every_status_has_an_icon() -> void:
  StatusRegistry.has(ShieldStatus.ID)   # builds the registry
  for id: String in StatusRegistry._creators:
    _assert_icon(StatusRegistry.create(id).icon, 'status %s' % id)


func test_every_mechanic_keyword_has_an_icon() -> void:
  for id: String in KeywordCatalog.MECHANIC_ORDER:
    _assert_icon(KeywordCatalog.get_entry(id)['icon'], 'keyword %s' % id)


func test_every_character_has_a_portrait() -> void:
  CharacterCatalog.has(CharacterCatalog.DEFAULT)   # builds the catalog
  for id: String in CharacterCatalog._defs:
    _assert_icon((CharacterCatalog._defs[id] as CharacterDef).portrait, 'character %s portrait' % id)


func test_every_enemy_has_a_portrait() -> void:
  EnemyCatalog.get_def(EnemyCatalog.GRUNT)   # builds the catalog
  for id: String in EnemyCatalog._defs:
    _assert_icon((EnemyCatalog._defs[id] as EnemyDef).portrait, 'enemy %s portrait' % id)


func _assert_icon(path: String, what: String) -> void:
  assert_ne(path, '', '%s names an icon' % what)
  if path == '':
    return
  assert_true(ResourceLoader.exists(path, 'Texture2D'), '%s icon exists: %s' % [what, path])
  assert_not_null(load(path) as Texture2D, '%s icon loads as a texture' % what)

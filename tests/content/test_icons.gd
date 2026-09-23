extends GutTest
## Every item, potion, status and mechanic keyword names an icon file, every character names a
## portrait file, and every enemy names a portrait or a corridor image, that loads as a texture, so a
## renamed or missing picture fails here instead of showing an empty cell.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_every_item_has_an_icon() -> void:
  ItemCatalog.get_def('claw')   # builds the catalog
  for id: String in ItemCatalog._defs:
    _assert_icon((ItemCatalog._defs[id] as ItemDef).icon, 'item %s' % id)


func test_every_potion_has_an_icon() -> void:
  ConsumableCatalog.get_def('healing_draught')   # builds the catalog
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


func test_every_enemy_has_a_portrait_or_an_image() -> void:
  # An ally slot shows the portrait, or the image when there is no portrait (ActorDef.make_actor).
  EnemyCatalog.get_def('grunt')   # builds the catalog
  for id: String in EnemyCatalog._defs:
    var def: EnemyDef = EnemyCatalog._defs[id]
    assert_true(def.portrait != '' or def.image != '', 'enemy %s names a portrait or an image' % id)
    if def.portrait != '':
      _assert_icon(def.portrait, 'enemy %s portrait' % id)
    if def.image != '':
      _assert_icon(def.image, 'enemy %s image' % id)


func _assert_icon(path: String, what: String) -> void:
  assert_ne(path, '', '%s names an icon' % what)
  if path == '':
    return
  assert_true(ResourceLoader.exists(path, 'Texture2D'), '%s icon exists: %s' % [what, path])
  assert_not_null(load(path) as Texture2D, '%s icon loads as a texture' % what)

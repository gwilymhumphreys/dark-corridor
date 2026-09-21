class_name FixtureRun
## Puts the test fixtures into the content catalogs so a whole run can be played on them
## (docs/systems/testing.md). A test that starts a run calls install() in before_each and passes
## FixtureCharacter.ID as the character. TestCleanup.reset_all_managers() calls uninstall(), so the
## fixtures never leak into the next test.
##
## The catalogs are written to directly rather than through a registration call, so the game has
## no test-only code. Each catalog is built before it is written to, because the catalogs build on
## first access only while they are empty.

static var _installed: bool = false


## Add the fixture items and the fixture character, and replace every authored enemy with the
## fixture enemy under the same id. Enemies are replaced rather than added because the map's
## encounters name them by id; replacing every id keeps this working as enemies are authored.
static func install() -> void:
  ItemCatalog.all_ids()
  for def: ItemDef in [
    FixtureItems.attack(),
    FixtureItems.enemy_attack(),
    FixtureItems.shield(),
    FixtureItems.poison(),
    FixtureItems.charge_your_weapons(),
    FixtureItems.silence_enemy_poison_item(),
  ]:
    ItemCatalog._defs[def.id] = def
  CharacterCatalog.has(FixtureCharacter.ID)
  CharacterCatalog._defs[FixtureCharacter.ID] = FixtureCharacter.def()
  EnemyCatalog.has(EnemyCatalog.GRUNT)
  for id: String in EnemyCatalog._defs.keys():
    EnemyCatalog._defs[id] = FixtureEnemies.enemy(id)
  _installed = true


## Empty the catalogs so the next access rebuilds them from the authored content.
static func uninstall() -> void:
  if not _installed:
    return
  ItemCatalog._defs.clear()
  CharacterCatalog._defs.clear()
  EnemyCatalog._defs.clear()
  _installed = false

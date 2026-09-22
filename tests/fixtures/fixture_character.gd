class_name FixtureCharacter
## A character for whole-run tests (docs/systems/testing.md), so a test that plays a run does not
## depend on which real character is the default or how its items are tuned. Its starting board is
## fixed rather than drawn, its pool holds only fixture items, and it has no starting relic, potion
## or enchant. FixtureContent.install() adds it to CharacterCatalog.
##
## Its board has to beat the fixture enemies by a wide margin, because the run around it (events,
## rests, relic rewards) is still real content, and the margin keeps that from changing a result.

const ID: String = 'fixture_character'


static func def() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = ID
  d.name_key = 'Fixture Character'
  d.item_pool = [
    FixtureItems.attack().id,
    FixtureItems.shield().id,
    FixtureItems.poison().id,
  ]
  d.starting_item_ids = [
    FixtureItems.attack().id,
    FixtureItems.attack().id,
    FixtureItems.shield().id,
  ]
  return d

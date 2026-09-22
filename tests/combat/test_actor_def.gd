extends GutTest
## ActorDef.make_actor() builds an Actor from a character or enemy definition (docs/systems/enemy.md):
## health and presentation fields, the portrait falling back to the image, an enemy's board, and the
## player's empty display name.

const IMAGE: String = 'res://fixture/image.png'
const PORTRAIT: String = 'res://fixture/portrait.png'


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_an_enemy_actor_copies_its_definition() -> void:
  var def: EnemyDef = FixtureEnemies.big_enemy()
  def.image = IMAGE
  def.portrait = PORTRAIT
  def.hurt_sound = 'fixture/hurt'
  var actor: Actor = def.make_actor()
  assert_almost_eq(actor.max_hp, FixtureEnemies.BIG_HP, 0.0001, 'max health')
  assert_almost_eq(actor.hp, FixtureEnemies.BIG_HP, 0.0001, 'at full health')
  assert_eq(actor.display_name, def.name_key, 'name')
  assert_eq(actor.image, IMAGE, 'image')
  assert_eq(actor.portrait, PORTRAIT, 'portrait')
  assert_eq(actor.hurt_sound, 'fixture/hurt', 'hurt sound')
  assert_eq(actor.board.size(), def.item_ids.size(), 'one item per board id')
  assert_eq(actor.board[0].def.id, def.item_ids[0], 'in board order')
  actor.dissolve()


func test_the_portrait_falls_back_to_the_image() -> void:
  var def: EnemyDef = FixtureEnemies.enemy()
  def.portrait = ''
  def.image = IMAGE
  var actor: Actor = def.make_actor()
  assert_eq(actor.portrait, IMAGE, 'no portrait shows the image')
  actor.dissolve()


func test_a_character_actor_has_no_board_and_no_name() -> void:
  var def: CharacterDef = CharacterCatalog.get_def(FixtureCharacter.ID)
  var actor: Actor = def.make_actor()
  assert_almost_eq(actor.max_hp, def.max_hp, 0.0001, 'the character max health')
  assert_eq(actor.board.size(), 0, 'the RunManager adds the board')
  assert_eq(actor.display_name, '', 'an empty name reads as the player in the combat summary')

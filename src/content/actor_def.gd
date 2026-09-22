class_name ActorDef
extends RefCounted
## The fields every authored Actor shares, whether it is a playable character (CharacterDef) or an
## enemy, ally or summon (EnemyDef) — docs/systems/enemy.md. make_actor() builds the Actor from them.

var id: String = ''
var name_key: String = ''            # source English, displayed via tr()
var max_hp: float = Balance.PLAYER_START_HP
# res:// path of the cut-out monster image the corridor shows (assets/monsters/cut_out/). Empty = a
# random one (MonsterImages).
var image: String = ''
# res:// path of the portrait shown in an ally slot or the player frame. Empty = the image.
var portrait: String = ''
# The folder under assets/sound-effects/ whose recordings play when this actor is hit
# (docs/systems/audio.md). Empty = the shared combat/hurt folder.
var hurt_sound: String = ''


## A new Actor at full health carrying this definition's presentation fields. A subclass adds its
## board.
func make_actor() -> Actor:
  var actor := Actor.new(max_hp)
  actor.display_name = name_key
  actor.image = image
  actor.portrait = portrait if portrait != '' else image
  actor.hurt_sound = hurt_sound
  return actor

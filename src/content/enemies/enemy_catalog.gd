class_name EnemyCatalog
## The enemy definitions (decision #23 — GDScript, keyed by Id). Phase 1: one
## grunt with a one-item authored board (its own attack item, separate from the
## player pool — design). Lazily built once.

const GRUNT := 'grunt'
const BRUTE := 'brute'
const BOSS := 'boss'
const SPORE_THRALL := 'spore_thrall'

static var _defs: Dictionary = {}


static func get_def(id: String) -> EnemyDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('EnemyCatalog: unknown enemy id "%s"' % id)
  return _defs[id]


static func _build() -> void:
  var grunt := EnemyDef.new()
  grunt.id = GRUNT
  grunt.name_key = 'Corridor Grunt'
  grunt.max_hp = Balance.ENEMY_PLACEHOLDER_HP
  grunt.item_ids = [ItemCatalog.ENEMY_CLAW]
  _defs[grunt.id] = grunt

  # Placeholder tougher regular (#1) — a beefier claw fighter for the choice pool.
  var brute := EnemyDef.new()
  brute.id = BRUTE
  brute.name_key = 'Corridor Brute'
  brute.max_hp = Balance.ENEMY_BRUTE_HP
  brute.item_ids = [ItemCatalog.ENEMY_CLAW]
  _defs[brute.id] = brute

  # Placeholder boss (#1) — tankier, two items. No signature mechanic (that's the owner's
  # content); the final-act boss is the run's ending (decided by position, not this def).
  var boss := EnemyDef.new()
  boss.id = BOSS
  boss.name_key = 'Corridor Warden'
  boss.max_hp = Balance.ENEMY_BOSS_HP
  boss.item_ids = [ItemCatalog.ENEMY_CLAW, ItemCatalog.ENEMY_CLAW]
  _defs[boss.id] = boss

  # A summon/token actor (docs/systems/spore_engine.md Cap 3): low HP, one weak attack. Usable as a
  # boss add, a player-side summon, OR (Stage B) a draftable persistent ally. Placeholder.
  var thrall := EnemyDef.new()
  thrall.id = SPORE_THRALL
  thrall.name_key = 'Spore Thrall'
  thrall.max_hp = Balance.ENEMY_SPORE_THRALL_HP
  thrall.item_ids = [ItemCatalog.ENEMY_CLAW]
  _defs[thrall.id] = thrall

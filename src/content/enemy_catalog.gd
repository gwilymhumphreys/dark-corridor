class_name EnemyCatalog
## The enemy definitions (decision #23 — GDScript, keyed by Id). Phase 1: one
## grunt with a one-item authored board (its own attack item, separate from the
## player pool — design). Lazily built once.

enum Id { GRUNT }

static var _defs: Dictionary = {}


static func get_def(id: int) -> EnemyDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  var grunt := EnemyDef.new()
  grunt.id = Id.GRUNT
  grunt.name_key = 'Corridor Grunt'
  grunt.max_hp = Balance.ENEMY_PLACEHOLDER_HP
  grunt.item_ids = [ItemCatalog.Id.ENEMY_CLAW]
  _defs[grunt.id] = grunt

extends GutTest
## The Armourer empower engine (docs/design/armourer.md → The empower engine) + its fire-pipeline seam
## (the firing item is threaded into modify_outgoing / on_owner_item_fired so a status can scope to a
## WEAPON attack). Proves: the double is weapon-scoped (not spells/skills), one charge is spent per
## weapon attack (2 charges → 2 doubled → expires), modify_outgoing stays PURE on the preview path,
## Mighty Blow banks a self charge (and stacks), the three big weapons are authored correctly, and
## Weak + Empower compose without error.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


# --- helpers (not test_*; GUT ignores them) ---

func _damage_def(dmg: float, type_tag: String) -> ItemDef:
  var d := ItemDef.new()
  d.types = [type_tag]
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = dmg
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  d.effects = [hit]
  return d


func _find(a: Actor, id: String) -> StatusEffect:
  for s in a.statuses:
    if s.id == id:
      return s
  return null


# --- the double: weapon yes, spell/skill no ---

func test_empower_doubles_a_weapon_attack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  assert_almost_eq(it.fire()[0].value, 40.0 * Balance.EMPOWER_MULT, 0.0001,
    'a banked charge doubles a WEAPON attack at fire time')


func test_empower_does_not_double_a_spell_attack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.SPELL), a)
  assert_almost_eq(it.fire()[0].value, 40.0, 0.0001,
    'a spell damage attack is NOT doubled — the empower is weapon-scoped')


func test_empower_does_not_double_a_skill_attack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.SKILL), a)
  assert_almost_eq(it.fire()[0].value, 40.0, 0.0001,
    'a skill damage attack is NOT doubled — the empower is weapon-scoped')


# --- one charge per weapon attack (consume on the real-fire hook) ---

func test_one_charge_per_weapon_attack_then_expires() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 2.0)   # bank two charges
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  var emp := _find(a, 'empowered')

  # Attack 1: modify_outgoing doubles (during fire), then on_owner_item_fired spends one charge (after).
  assert_almost_eq(it.fire()[0].value, 80.0, 0.0001, 'attack 1 is doubled (2 charges banked)')
  assert_false(emp.on_owner_item_fired(a, it, null), 'a charge remains after the first weapon attack')
  assert_almost_eq(emp.count, 1.0, 0.0001, 'spent exactly one charge')

  # Attack 2: still doubled (1 charge left), then the last charge is spent → expired.
  assert_almost_eq(it.fire()[0].value, 80.0, 0.0001, 'attack 2 is still doubled (1 charge left)')
  assert_true(emp.on_owner_item_fired(a, it, null), 'the last charge is spent → the empower expires')
  assert_almost_eq(emp.count, 0.0, 0.0001, 'drained to zero')

  # The Combat manager removes an expired status; attack 3 is then a normal hit.
  a.statuses.erase(emp)
  assert_almost_eq(it.fire()[0].value, 40.0, 0.0001, 'attack 3 is a normal hit (no charges banked)')


func test_a_non_weapon_fire_spends_no_charge() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var skill := Item.new(_damage_def(40.0, ItemType.SKILL), a)
  var emp := _find(a, 'empowered')
  assert_false(emp.on_owner_item_fired(a, skill, null), 'a skill fire never spends an empower charge')
  assert_almost_eq(emp.count, 1.0, 0.0001, 'the charge is banked until a WEAPON attack')


# --- purity: the tooltip preview must not spend a charge ---

func test_display_value_preview_is_pure() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  var emp := _find(a, 'empowered')
  assert_almost_eq(it.display_value(it.def.effects[0]), 80.0, 0.0001,
    'the read-only preview SHOWS the doubled value')
  assert_almost_eq(emp.count, 1.0, 0.0001,
    'but modify_outgoing is PURE — the preview spent no charge')


# --- Mighty Blow (the empower applier) ---

func test_mighty_blow_applies_empowered_to_self() -> void:
  var p: Payload = Item.new(ItemCatalog.get_def(ItemCatalog.MIGHTY_BLOW), Actor.new()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS, 'Mighty Blow is a status applier')
  assert_eq(p.status_id, 'empowered', 'it applies the empower buff')
  assert_eq(p.shape, ItemEffect.Shape.SELF, 'to the firer (self)')
  assert_almost_eq(p.value, Balance.MIGHTY_BLOW_CHARGES, 0.0001, 'banking one charge per fire')


func test_mighty_blow_is_a_skill_on_a_cooldown() -> void:
  var d := ItemCatalog.get_def(ItemCatalog.MIGHTY_BLOW)
  assert_true(d.types.has(ItemType.SKILL), 'Mighty Blow is a skill')
  assert_almost_eq(d.cooldown, Balance.MIGHTY_BLOW_COOLDOWN, 0.0001, 'a plain-cooldown metronome')


func test_mighty_blow_charges_stack_on_repeat() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', Balance.MIGHTY_BLOW_CHARGES)
  StatusManager.apply(a, 'empowered', Balance.MIGHTY_BLOW_CHARGES)
  assert_almost_eq(_find(a, 'empowered').count, 2.0 * Balance.MIGHTY_BLOW_CHARGES, 0.0001,
    'repeated Mighty Blow fires stack charges (reapply is additive)')


# --- the three big weapons ---

func test_the_three_big_weapons_are_authored_correctly() -> void:
  var specs := [
    [ItemCatalog.ARMOURER_BROADAXE, Balance.ARMOURER_BROADAXE_COOLDOWN, Balance.ARMOURER_BROADAXE_DAMAGE],
    [ItemCatalog.ARMOURER_WARHAMMER, Balance.ARMOURER_WARHAMMER_COOLDOWN, Balance.ARMOURER_WARHAMMER_DAMAGE],
    [ItemCatalog.ARMOURER_GREATSWORD, Balance.ARMOURER_GREATSWORD_COOLDOWN, Balance.ARMOURER_GREATSWORD_DAMAGE],
  ]
  for spec in specs:
    var d: ItemDef = ItemCatalog.get_def(spec[0])
    assert_true(d.types.has(ItemType.WEAPON), '%s is a weapon' % spec[0])
    assert_almost_eq(d.cooldown, spec[1], 0.0001, '%s cooldown' % spec[0])
    assert_eq(d.effects.size(), 1, '%s is a single-effect weapon' % spec[0])
    assert_eq(d.effects[0].kind, Delivery.Kind.DAMAGE, '%s deals damage' % spec[0])
    assert_almost_eq(d.effects[0].value, spec[2], 0.0001, '%s damage' % spec[0])
    assert_eq(d.effects[0].shape, ItemEffect.Shape.OPPONENT_LEFTMOST, '%s is single-target' % spec[0])


# --- composition: Weak + Empower both fold in modify_outgoing ---

func test_weak_and_empower_compose() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  StatusManager.apply(a, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  var expected: float = 40.0 * Balance.EMPOWER_MULT * Balance.STATUS_WEAK_DAMAGE_MULT
  assert_almost_eq(it.fire()[0].value, expected, 0.0001,
    'Weak and Empower both fold in modify_outgoing without error (the product)')

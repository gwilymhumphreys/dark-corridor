extends GutTest
## The Smith empower engine (docs/design/smith.md → The empower engine) + its fire-pipeline seam
## (the firing item is threaded into outgoing_bonus / on_owner_item_fired so a status can scope to a
## WEAPON attack). Proves: the double is weapon-scoped (not spells/skills), one charge is spent per
## weapon attack (2 charges → 2 doubled → expires), outgoing_bonus stays PURE on the preview path,
## an empower applier banks a self charge (and stacks), and Weak + Empower compose without error.
## The authored cards (Mighty Blow, the three big weapons) are checked in
## tests/content/test_authored_content.gd.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


# --- helpers (not test_*; GUT ignores them) ---

func _damage_def(dmg: float, type_tag: String) -> ItemDef:
  var d := ItemDef.new()
  d.types = [type_tag]
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
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

  # Attack 1: outgoing_bonus doubles (during fire), then on_owner_item_fired spends one charge (after).
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
    'but outgoing_bonus is PURE — the preview spent no charge')


# --- an empower applier ---

func test_an_empower_applier_applies_empowered_to_self() -> void:
  var p: Payload = Item.new(FixtureItems.empower(), Actor.new()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS, 'the applier fires a status')
  assert_eq(p.status_id, 'empowered', 'it applies the empower buff')
  assert_eq(p.shape, ItemEffect.Shape.SELF, 'to the firer (self)')
  assert_almost_eq(p.value, FixtureItems.EMPOWER_CHARGES, 0.0001, 'banking its charges per fire')


func test_empower_charges_stack_on_repeat() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', FixtureItems.EMPOWER_CHARGES)
  StatusManager.apply(a, 'empowered', FixtureItems.EMPOWER_CHARGES)
  assert_almost_eq(_find(a, 'empowered').count, 2.0 * FixtureItems.EMPOWER_CHARGES, 0.0001,
    'repeated empower fires stack charges (reapply is additive)')


# --- composition: Weak + Empower both fold in outgoing_bonus ---

func test_weak_and_empower_compose() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  StatusManager.apply(a, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  # Empower is a positive percentage and Weak a negative one; the two groups apply separately.
  var expected: float = 40.0 * Balance.EMPOWER_MULT * Balance.STATUS_WEAK_DAMAGE_MULT
  assert_almost_eq(it.fire()[0].value, expected, 0.0001,
    'Weak and Empower both apply (one positive and one negative percentage multiply)')

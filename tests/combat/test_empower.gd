extends GutTest
## The Smith empower engine (docs/design/smith.md → The empower engine) + its fire-pipeline seam
## (the firing item is threaded into outgoing_bonus / on_owner_item_fired). Proves: any item's
## attack is raised whatever its type tags, one stack is used up per attack (2 stacks → 2 raised →
## expires), an item with no attack uses none, outgoing_bonus stays PURE on the preview path,
## an empower applier adds a stack to itself (and they add up), and Weak + Empower compose without error.
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


# --- the raise: any attack, whatever the item's type tags ---

func test_empower_raises_a_weapon_attack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  assert_almost_eq(it.fire()[0].value, 40.0 * Balance.EMPOWER_MULT, 0.0001,
    'a held stack raises a weapon attack at fire time')


func test_empower_raises_a_spell_attack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.SPELL), a)
  assert_almost_eq(it.fire()[0].value, 40.0 * Balance.EMPOWER_MULT, 0.0001,
    'a spell attack is raised too')


func test_empower_raises_a_skill_attack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.SKILL), a)
  assert_almost_eq(it.fire()[0].value, 40.0 * Balance.EMPOWER_MULT, 0.0001,
    'a skill attack is raised too')


# --- one stack per attack (consume on the real-fire hook) ---

func test_one_stack_per_attack_then_expires() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 2.0)   # hold two stacks
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  var emp := _find(a, 'empowered')

  # Attack 1: outgoing_bonus raises it (during fire), then on_owner_item_fired uses up one stack (after).
  assert_almost_eq(it.fire()[0].value, 40.0 * Balance.EMPOWER_MULT, 0.0001, 'attack 1 is raised (2 stacks held)')
  assert_false(emp.on_owner_item_fired(a, it, null), 'a stack remains after the first attack')
  assert_eq(emp.count, 1, 'used up exactly one stack')

  # Attack 2: still raised (1 stack left), then the last stack is used up → expired.
  assert_almost_eq(it.fire()[0].value, 40.0 * Balance.EMPOWER_MULT, 0.0001, 'attack 2 is still raised (1 stack left)')
  assert_true(emp.on_owner_item_fired(a, it, null), 'the last stack is used up → the empower expires')
  assert_eq(emp.count, 0, 'drained to zero')

  # The Combat manager removes an expired status; attack 3 is then a normal hit.
  a.statuses.erase(emp)
  assert_almost_eq(it.fire()[0].value, 40.0, 0.0001, 'attack 3 is a normal hit (no stacks held)')


func test_an_item_with_no_attack_uses_no_stack() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var applier := Item.new(FixtureItems.empower(), a)
  var emp := _find(a, 'empowered')
  assert_false(emp.on_owner_item_fired(a, applier, null), 'an item with no attack uses no stack')
  assert_eq(emp.count, 1, 'the stack is held until an attack')


# --- purity: the tooltip preview must not use up a stack ---

func test_display_value_preview_is_pure() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(_damage_def(40.0, ItemType.WEAPON), a)
  var emp := _find(a, 'empowered')
  assert_almost_eq(it.display_value(it.def.effects[0]), 40.0 * Balance.EMPOWER_MULT, 0.0001,
    'the read-only preview SHOWS the raised value')
  assert_eq(emp.count, 1,
    'but outgoing_bonus is PURE — the preview used up no stack')


# --- an empower applier ---

func test_an_empower_applier_applies_empowered_to_self() -> void:
  var p: Payload = Item.new(FixtureItems.empower(), Actor.new()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS, 'the applier fires a status')
  assert_eq(p.status_id, 'empowered', 'it applies the empower buff')
  assert_eq(p.shape, ItemEffect.Shape.SELF, 'to the firer (self)')
  assert_almost_eq(p.value, FixtureItems.EMPOWER_STACKS, 0.0001, 'adding its stacks per fire')


func test_empower_stacks_add_up_on_repeat() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', FixtureItems.EMPOWER_STACKS)
  StatusManager.apply(a, 'empowered', FixtureItems.EMPOWER_STACKS)
  assert_eq(_find(a, 'empowered').count, roundi(2.0 * FixtureItems.EMPOWER_STACKS),
    'repeated empower fires add up stacks (reapply is additive)')


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

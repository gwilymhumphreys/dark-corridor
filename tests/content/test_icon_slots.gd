extends GutTest
## The icon slots (docs/plans/mechanic_icons.md): a name that owns one icon, the icon chosen for
## each, and the file the choices are saved to. Nothing else uses it yet.
##
## The tests write `CHOSEN_PATH`, so they put the file back as they found it (or delete the one
## they created) in `after_each`, through `TestCleanup` — per docs/systems/testing.md.


func before_each() -> void:
  TestCleanup.reset_all_managers()
  IconSlots.reset()
  TestCleanup.snapshot_chosen_icons()


func after_each() -> void:
  TestCleanup.reset_all_managers()
  TestCleanup.restore_chosen_icons()


func test_icon_for_returns_the_default_when_nothing_is_chosen() -> void:
  # The developer may have chosen icons in the Icons tab, which leaves `CHOSEN_PATH` on disk, so
  # clear it first rather than assuming there is none. `after_each` puts the file back.
  TestCleanup.clear_chosen_icons()
  assert_eq(IconSlots.icon_for('attack'), IconSlots.DEFAULTS['attack'], 'an unset slot is its default')
  assert_eq(IconSlots.icon_for('heal'), IconSlots.DEFAULTS['heal'], 'an unset slot is its default')
  assert_eq(IconSlots.icon_for('card'), IconSlots.DEFAULTS['card'], 'an unset slot is its default')


func test_icon_for_is_empty_for_an_unknown_slot() -> void:
  assert_eq(IconSlots.icon_for('nonsense'), '', 'an unknown slot gives an empty path')


func test_icon_for_returns_the_choice_after_set_icon() -> void:
  var other: String = 'res://assets/icons/mechanics/attack/broadsword.png'
  IconSlots.set_icon('attack', other)
  assert_eq(IconSlots.icon_for('attack'), other, 'the chosen path wins over the default')
  assert_eq(IconSlots.icon_for('shield'), IconSlots.DEFAULTS['shield'], 'an unset slot is still its default')


func test_set_icon_on_an_unknown_slot_changes_nothing() -> void:
  var attack_before: String = IconSlots.icon_for('attack')
  IconSlots.set_icon('nonsense', 'res://somewhere.png')
  assert_eq(IconSlots.icon_for('attack'), attack_before, 'an unknown slot leaves the choices untouched')
  assert_eq(IconSlots.candidates('nonsense'), [], 'an unknown slot has no candidates')


func test_candidates_lists_the_pngs_in_the_slot_folder() -> void:
  var paths: Array[String] = IconSlots.candidates('attack')
  assert_eq(paths.size(), 12, 'the attack folder holds twelve candidates')
  for path: String in paths:
    assert_true(path.ends_with('.png'), '%s is a png' % path)
    assert_true(path.begins_with('res://assets/icons/mechanics/attack/'), '%s is in the slot folder' % path)


func test_display_name_spells_the_slot() -> void:
  assert_eq(IconSlots.display_name('charge_time'), 'Charge time', 'underscores become spaces, first letter capitals')
  assert_eq(IconSlots.display_name('attack'), 'Attack', 'a single word is capitalised')

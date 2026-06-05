extends GutTest
## Step 3 — the authored enemy is just data (HP + a board of item ids). Spawning
## it as an Actor end-to-end is exercised in Step 4.


func test_grunt_has_authored_board() -> void:
  var ed := EnemyCatalog.get_def(EnemyCatalog.Id.GRUNT)
  assert_gt(ed.max_hp, 0.0, 'grunt has HP')
  assert_eq(ed.item_ids.size(), 1, 'grunt has a one-item authored board')
  assert_eq(ed.item_ids[0], ItemCatalog.Id.ENEMY_CLAW, 'its attack item is from the enemy pool')

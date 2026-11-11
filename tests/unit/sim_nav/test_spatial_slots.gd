extends GdUnitTestSuite
## SpatialHash and AttackSlots (ARCH 6.6).


func _store_with(points: Array[Vector3]) -> EnemyStore:
	## Each Vector3 is (id, x, z); stored in the given order.
	var s: EnemyStore = EnemyStore.new(64)
	for p: Vector3 in points:
		var i: int = s.alloc()
		s.id[i] = roundi(p.x)
		s.x[i] = p.y
		s.z[i] = p.z
	return s


func test_spatial_query_returns_the_enemies_in_range_sorted_by_id() -> void:
	var s: EnemyStore = _store_with([Vector3(9, 1.0, 1.0), Vector3(3, 1.5, 1.0), Vector3(7, 0.5, 1.2), Vector3(5, 6.0, 6.0), Vector3(4, 3.0, 1.0)])
	var h: SpatialHash = SpatialHash.new()
	h.rebuild(s)
	var out: PackedInt32Array = PackedInt32Array()
	var n: int = h.query(1.0, 1.0, 1.0, out)
	assert_int(n).is_equal(3)
	assert_int(out.size()).is_equal(3)
	assert_int(s.id[out[0]]).is_equal(3)
	assert_int(s.id[out[1]]).is_equal(7)
	assert_int(s.id[out[2]]).is_equal(9)


func test_spatial_query_matches_brute_force() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var pts: Array[Vector3] = []
	for k: int in 50:
		pts.append(Vector3(float(1 + (k * 37) % 101), rng.randf_range(-12.0, 12.0), rng.randf_range(-18.0, 14.0)))
	var s: EnemyStore = _store_with(pts)
	var h: SpatialHash = SpatialHash.new()
	h.rebuild(s)
	var out: PackedInt32Array = PackedInt32Array()
	for q: int in 30:
		var qx: float = rng.randf_range(-14.0, 14.0)
		var qz: float = rng.randf_range(-20.0, 16.0)
		var radius: float = rng.randf_range(0.2, 4.0)
		var expected: Array[int] = []
		for i: int in s.high_water:
			if Vector2(s.x[i] - qx, s.z[i] - qz).length() <= radius:
				expected.append(s.id[i])
		expected.sort()
		var n: int = h.query(qx, qz, radius, out)
		assert_int(n).is_equal(expected.size())
		for k: int in n:
			assert_int(s.id[out[k]]).is_equal(expected[k])


func test_spatial_query_on_an_empty_store_and_a_cleared_output() -> void:
	var h: SpatialHash = SpatialHash.new()
	var s: EnemyStore = EnemyStore.new(8)
	h.rebuild(s)
	var out: PackedInt32Array = PackedInt32Array([5, 6, 7])
	assert_int(h.query(0.0, 0.0, 5.0, out)).is_equal(0)
	assert_int(out.size()).is_equal(0)
	var i: int = s.alloc()
	s.id[i] = 1
	h.rebuild(s)
	assert_int(h.query(0.0, 0.0, 1.0, out)).is_equal(1)
	assert_int(h.query(50.0, 50.0, 1.0, out)).is_equal(0)
	assert_int(out.size()).is_equal(0)


func test_spatial_query_ignores_dead_slots_and_far_positions() -> void:
	var s: EnemyStore = _store_with([Vector3(1, 0.0, 0.0), Vector3(2, 0.5, 0.0), Vector3(3, 1.0, 0.0), Vector3(4, 90.0, -90.0)])
	s.free_index(1)
	var h: SpatialHash = SpatialHash.new()
	h.rebuild(s)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(h.query(0.0, 0.0, 2.0, out)).is_equal(2)
	assert_int(s.id[out[0]]).is_equal(1)
	assert_int(s.id[out[1]]).is_equal(3)
	assert_int(h.query(90.0, -90.0, 1.0, out)).is_equal(1)
	assert_int(s.id[out[0]]).is_equal(4)
	assert_int(h.query(-90.0, 90.0, 1.0, out)).is_equal(0)


func test_fifty_enemies_get_fifty_distinct_slots() -> void:
	var w: SimWorld = NavTestUtil.world()
	var seen: Dictionary = {}
	for k: int in 50:
		var type_index: int = Ids.EN_SKITTER if k % 5 != 0 else Ids.EN_HOLLOW
		var i: int = w.spawn_enemy(type_index, -1.0 + float(k) * 0.1, 2.0 + float(k % 7))
		var slot: int = w.nav.slots.claim(w, i)
		assert_int(slot).is_greater_equal(0)
		assert_bool(seen.has(slot)).is_false()
		seen[slot] = true
		assert_int(w.nav.slots.occupant(slot)).is_equal(w.enemies.id[i])
		assert_int(w.enemies.slot[i]).is_equal(slot)
	assert_int(seen.size()).is_equal(50)


func test_claim_takes_the_nearest_slot_of_the_lowest_ring() -> void:
	var w: SimWorld = NavTestUtil.world()
	var arena: ArenaDef = w.content.arena
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, -3.0, -2.0)
	var best: int = -1
	var best_d: float = INF
	for k: int in arena.slot_positions.size():
		if arena.slot_ring[k] != 0:
			continue
		var d: float = Vector2(arena.slot_positions[k].x + 3.0, arena.slot_positions[k].y + 2.0).length()
		if d < best_d:
			best_d = d
			best = k
	assert_int(w.nav.slots.claim(w, i)).is_equal(best)
	assert_int(arena.slot_ring[best]).is_equal(0)


func test_a_ring_fills_before_the_next_ring_opens() -> void:
	var w: SimWorld = NavTestUtil.world()
	var arena: ArenaDef = w.content.arena
	var rings: Array[int] = []
	for k: int in 25:
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, 1.0, 3.0 + float(k) * 0.01)
		rings.append(arena.slot_ring[w.nav.slots.claim(w, i)])
	for k: int in 25:
		var expected: int = 0 if k < 10 else (1 if k < 24 else 2)
		assert_int(rings[k]).is_equal(expected)


func test_the_hulk_holds_three_adjacent_slots_in_one_ring() -> void:
	var w: SimWorld = NavTestUtil.world()
	var arena: ArenaDef = w.content.arena
	var i: int = w.spawn_enemy(Ids.EN_HULK, 1.0, 3.0)
	var slot: int = w.nav.slots.claim(w, i)
	var hulk_id: int = w.enemies.id[i]
	assert_int(w.nav.slots.occupant(slot - 1)).is_equal(hulk_id)
	assert_int(w.nav.slots.occupant(slot)).is_equal(hulk_id)
	assert_int(w.nav.slots.occupant(slot + 1)).is_equal(hulk_id)
	assert_int(w.nav.slots.occupant(slot - 2)).is_equal(0)
	assert_int(w.nav.slots.occupant(slot + 2)).is_equal(0)
	assert_int(arena.slot_ring[slot - 1]).is_equal(arena.slot_ring[slot + 1])
	var held: int = 0
	for k: int in arena.slot_positions.size():
		if w.nav.slots.occupant(k) == hulk_id:
			held += 1
	assert_int(held).is_equal(3)


func test_the_hulk_skips_a_ring_without_a_free_run() -> void:
	var w: SimWorld = NavTestUtil.world()
	var arena: ArenaDef = w.content.arena
	for k: int in 10:
		w.nav.slots.claim(w, w.spawn_enemy(Ids.EN_SKITTER, 1.0, 3.0))
	for s: int in [1, 3, 5, 7, 9]:
		w.kill_enemy(w.enemies.index_of(w.nav.slots.occupant(s)), DamageSource.Id.WARDEN)
	var holes: int = 0
	for k: int in 10:
		if w.nav.slots.occupant(k) == 0:
			holes += 1
	assert_int(holes).is_equal(5)
	var hulk: int = w.spawn_enemy(Ids.EN_HULK, 1.0, 3.0)
	var slot: int = w.nav.slots.claim(w, hulk)
	assert_int(arena.slot_ring[slot]).is_equal(1)
	var single: int = w.spawn_enemy(Ids.EN_SKITTER, 1.0, 3.0)
	assert_int(arena.slot_ring[w.nav.slots.claim(w, single)]).is_equal(0)


func test_a_killed_enemys_slot_is_free_the_same_tick() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 1.0, 3.0)
	var slot: int = w.nav.slots.claim(w, i)
	assert_int(w.nav.slots.occupant(slot)).is_equal(w.enemies.id[i])
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	assert_int(w.nav.slots.occupant(slot)).is_equal(0)
	var j: int = w.spawn_enemy(Ids.EN_SKITTER, 1.0, 3.0)
	assert_int(w.nav.slots.claim(w, j)).is_equal(slot)


func test_killing_the_hulk_frees_all_three_slots() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_HULK, 1.0, 3.0)
	var slot: int = w.nav.slots.claim(w, i)
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	for k: int in range(slot - 1, slot + 2):
		assert_int(w.nav.slots.occupant(k)).is_equal(0)


func test_claim_is_idempotent_and_release_without_a_slot_is_harmless() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 1.0, 3.0)
	w.nav.slots.release(w, i)
	var a: int = w.nav.slots.claim(w, i)
	assert_int(w.nav.slots.claim(w, i)).is_equal(a)
	w.nav.slots.release(w, i)
	assert_int(w.enemies.slot[i]).is_equal(-1)
	assert_int(w.nav.slots.occupant(a)).is_equal(0)
	assert_int(w.nav.slots.occupant(-1)).is_equal(0)
	assert_int(w.nav.slots.occupant(64)).is_equal(0)
	assert_int(w.nav.slots.occupant(999)).is_equal(0)
	assert_int(w.nav.slots.slot_count()).is_equal(64)

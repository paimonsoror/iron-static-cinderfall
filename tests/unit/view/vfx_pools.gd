extends GdUnitTestSuite
## VfxPool, FloatingTexts, ScreenFlash and the effect meshes: fixed pools, fixed lifetimes, drop-the-oldest.

const BOUNDS: AABB = AABB(Vector3(-50.0, -5.0, -50.0), Vector3(100.0, 40.0, 100.0))


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func _pool(cap: int, mode: int) -> VfxPool:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	auto_free(parent)
	var pool: VfxPool = VfxPool.new()
	pool.setup(parent, "TestPool", VfxMeshes.streak(&"add_amber"), cap, mode, BOUNDS)
	return pool


func test_pool_recycles_the_oldest_slot_when_full() -> void:
	var pool: VfxPool = _pool(4, VfxPool.Mode.FLAT)
	var slots: Array[int] = []
	for n: int in 6:
		slots.append(pool.spawn(Vector3(float(n), 0.0, 0.0), Vector3.ZERO, 1.0, 1.0, 1.0))
	assert_int(pool.live_count()).is_equal(4)
	assert_int(pool.capacity).is_equal(4)
	assert_int(slots[4]).is_equal(slots[0])  # the oldest slot was overwritten
	assert_int(slots[5]).is_equal(slots[1])


func test_pool_effects_expire_after_their_lifetime() -> void:
	var pool: VfxPool = _pool(8, VfxPool.Mode.SEGMENT)
	var _a: int = pool.spawn(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 0.1, 0.05, 0.12)
	var _b: int = pool.spawn(Vector3.ZERO, Vector3(5.0, 0.0, 2.0), 0.1, 0.05, 0.3)
	pool.step(0.0)  # first draw
	pool.step(0.05)
	assert_int(pool.live_count()).is_equal(2)
	pool.step(0.1)
	assert_int(pool.live_count()).is_equal(1)
	pool.step(0.5)
	assert_int(pool.live_count()).is_equal(0)
	assert_int(pool.node.multimesh.visible_instance_count).is_equal(0)


func test_pool_draws_live_effects_through_visible_instance_count() -> void:
	var pool: VfxPool = _pool(16, VfxPool.Mode.BILLBOARD)
	for n: int in 5:
		var _s: int = pool.spawn(Vector3(float(n), 1.0, 0.0), Vector3.ZERO, 0.5, 0.1, 1.0)
	pool.step(0.016)
	assert_int(pool.node.multimesh.visible_instance_count).is_equal(5)
	assert_int(pool.node.multimesh.transform_format).is_equal(MultiMesh.TRANSFORM_3D)
	assert_bool(pool.node.multimesh.use_colors).is_false()
	assert_bool(pool.node.multimesh.use_custom_data).is_false()


func test_tracer_segment_runs_from_the_muzzle_to_the_target() -> void:
	var pool: VfxPool = _pool(4, VfxPool.Mode.SEGMENT)
	var slot: int = pool.spawn(Vector3(0.0, 1.0, 0.0), Vector3(10.0, 1.0, 0.0), 0.12, 0.04, 0.2)
	pool.step(0.0)
	pool.step(0.1)  # half way through its life: the line has reached the target and the tail follows
	var t: Transform3D = pool.slot_transform(slot)
	assert_float(t.basis.z.length()).is_greater(1.0)  # stretched along the shot
	assert_float(absf(t.basis.z.normalized().x)).is_greater(0.99)  # pointing along +X
	assert_float(t.basis.x.length()).is_less(0.13)  # thin


func test_debris_flies_up_then_rests_on_the_ground() -> void:
	var pool: VfxPool = _pool(4, VfxPool.Mode.DEBRIS)
	var slot: int = pool.spawn(Vector3(0.0, 0.5, 0.0), Vector3(2.0, 4.0, 0.0), 0.2, 0.2, 5.0, 3.0)
	pool.step(0.0)
	pool.step(0.2)
	var rising: Vector3 = pool.slot_transform(slot).origin
	assert_float(rising.y).is_greater(0.5)
	pool.step(2.0)
	var landed: Vector3 = pool.slot_transform(slot).origin
	assert_float(landed.y).is_less(0.1)
	assert_float(landed.x).is_greater(0.5)
	pool.step(1.0)
	assert_float(pool.slot_transform(slot).origin.x).is_equal_approx(landed.x, 0.0001)


func test_floating_texts_rise_fade_and_expire() -> void:
	var texts: FloatingTexts = FloatingTexts.new()
	add_child(texts)
	auto_free(texts)
	texts.setup()
	texts.spawn("+20", Vector3(1.0, 1.0, 1.0), 1.0, Color.WHITE)
	assert_int(texts.live_count()).is_equal(1)
	assert_array(texts.texts()).contains(["+20"])
	texts.step(FloatingTexts.LIFE_S * 0.5)
	var label: Label3D = texts.get_child(0) as Label3D
	assert_float(label.position.y).is_greater(1.5)
	assert_float(label.modulate.a).is_less(1.0)
	texts.step(FloatingTexts.LIFE_S)
	assert_int(texts.live_count()).is_equal(0)
	assert_bool(label.visible).is_false()


func test_floating_texts_never_exceed_the_cap_and_drop_the_oldest() -> void:
	var texts: FloatingTexts = FloatingTexts.new()
	add_child(texts)
	auto_free(texts)
	texts.setup()
	texts.set_cap(8)
	for n: int in 40:
		texts.spawn("+%d" % n, Vector3.ZERO, 1.0, Color.WHITE)
		texts.step(0.01)
	assert_int(texts.live_count()).is_equal(8)
	assert_array(texts.texts()).contains(["+39"])
	assert_array(texts.texts()).not_contains(["+0"])
	texts.set_cap(1000)
	for n: int in 60:
		texts.spawn("x", Vector3.ZERO, 1.0, Color.WHITE)
	assert_int(texts.live_count()).is_equal(FloatingTexts.CAPACITY)


func test_screen_flash_triggers_fades_and_reduced_mode_removes_it() -> void:
	var flash: ScreenFlash = ScreenFlash.new()
	add_child(flash)
	auto_free(flash)
	flash.setup()
	assert_bool(flash.is_flash_visible()).is_false()
	flash.trigger(Color.WHITE, 0.3, 0.2)
	assert_bool(flash.is_flash_visible()).is_true()
	flash.step(0.1)
	assert_float(flash.rect.color.a).is_between(0.05, 0.25)
	flash.step(0.2)
	assert_bool(flash.is_flash_visible()).is_false()
	flash.set_reduced(true)
	flash.trigger(Color.WHITE, 0.3, 0.2)
	assert_bool(flash.is_flash_visible()).is_false()


func test_effect_meshes_are_tiny_and_use_palette_materials() -> void:
	var meshes: Array[ArrayMesh] = [
		VfxMeshes.streak(&"add_amber"), VfxMeshes.star(&"add_amber", &"add_white"), VfxMeshes.disc(1.0, 12, &"add_white"),
		VfxMeshes.puff(&"add_white"),
		VfxMeshes.ring(0.9, 40, &"add_cyan", &"add_white"), VfxMeshes.cube(&"gunmetal"),
	]
	for m: ArrayMesh in meshes:
		assert_int(VfxMeshes.triangles(m)).is_between(2, 200)
		for s: int in m.get_surface_count():
			assert_object(m.surface_get_material(s)).is_not_null()
	assert_int(VfxMeshes.triangles(VfxMeshes.dome(&"add_cyan", 14))).is_less(400)
	var ring: ArrayMesh = VfxMeshes.ring(0.9, 40, &"add_cyan", &"add_white")
	assert_object(ring.surface_get_material(0)).is_same(MatLib.mat(&"add_cyan"))
	assert_object(ring.surface_get_material(1)).is_same(MatLib.mat(&"add_white"))


func test_dimmed_materials_are_shared_copies_with_a_lower_alpha() -> void:
	var lit: StandardMaterial3D = VfxMeshes.material(&"add_amber")
	var dim: StandardMaterial3D = VfxMeshes.material(&"add_amber", 0.4)
	assert_object(lit).is_same(MatLib.mat(&"add_amber"))
	assert_object(dim).is_not_same(lit)
	assert_float(dim.albedo_color.a).is_equal_approx(lit.albedo_color.a * 0.4, 0.001)
	assert_object(VfxMeshes.material(&"add_amber", 0.4)).is_same(dim)
	assert_int(dim.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)

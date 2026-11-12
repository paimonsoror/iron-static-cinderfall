extends GdUnitTestSuite
## V2-D: WorldSnapshot (VARIETY_SPEC 2.8, 9.6): a world that went through the JSON text of its snapshot has the same
## state hash, and goes on exactly as the original does (same hash, same events), at every wave boundary, for three
## seeds, on the legacy fixture and on the variety fixture.

const SEEDS: Array[int] = [1, 2, 3]
const MAX_TICKS: int = 40000
const SHADOW_TICKS: int = 150  ## how far a restored world is played next to the original after each boundary


func _boosted(content: ContentSet, run_seed: int) -> SimWorld:
	return SimWorld.new(VarietyDKit.config(content, run_seed))


## One step with the scripted player: CONTINUE from the sixth tick of an intermission on.
func _step(w: SimWorld) -> void:
	if w.phase == GameState.Id.INTERMISSION and w.content.mission.intermission_ticks - w.phase_ticks_left >= 5:
		w.submit(SimCommand.skip(500000 + w.tick))
	w.step()
	w.events.drain()


func _assert_boundaries(content_maker: Callable, label: String) -> void:
	for run_seed: int in SEEDS:
		var content: ContentSet = content_maker.call()
		var world: SimWorld = _boosted(content, run_seed)
		var waves: int = world.plan.wave_count() if world.plan != null else content.waves.size()
		var boundaries: int = 0
		var shadow: SimWorld = null  # restored at the last boundary, played next to the original for a while
		var shadow_left: int = 0
		for i: int in MAX_TICKS:
			if world.is_over():
				break
			var cleared: int = world.waves_completed
			_step(world)
			if shadow != null:
				_step(shadow)
				shadow_left -= 1
				if shadow_left == 0 or world.is_over():
					var where: String = "%s seed %d after wave %d" % [label, run_seed, boundaries]
					assert_str(shadow.state_hash()).override_failure_message(where + ": the restored world drifted").is_equal(world.state_hash())
					assert_int(shadow.events.event_hash).override_failure_message(where + ": event hash").is_equal(world.events.event_hash)
					shadow = null
			if world.waves_completed != cleared and not world.is_over():
				boundaries += 1
				var at: String = "%s seed %d wave %d" % [label, run_seed, world.waves_completed]
				assert_int(world.alive_count()).is_equal(0)  # a boundary: the wave is cleared
				shadow = VarietyDKit.through_json(world)
				shadow_left = SHADOW_TICKS
				assert_object(shadow).override_failure_message(at + ": restore failed").is_not_null()
				assert_str(shadow.state_hash()).override_failure_message(at + ": state hash").is_equal(world.state_hash())
		assert_bool(world.is_over()).is_true()
		assert_int(boundaries).is_equal(waves - 1)  # every wave clear but the last, which ends the run


func test_snapshot_restore_hash_is_equal_at_every_boundary_on_the_legacy_fixture() -> void:
	_assert_boundaries(TestContent.baseline, "legacy")


func test_snapshot_restore_hash_is_equal_at_every_boundary_on_the_variety_fixture() -> void:
	_assert_boundaries(TestContent.variety, "variety")


func test_a_snapshot_in_the_middle_of_a_wave_is_complete_too() -> void:
	# The game only takes snapshots at a wave clear, but the capture leaves nothing out: live enemies, attack slots,
	# the spawn schedule, the steering caches, cooldowns and the RNG streams all come back.
	var world: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 7))
	for i: int in world.content.mission.prepare_ticks + 900:
		world.step()
		world.events.drain()
	assert_int(world.alive_count()).is_greater(3)
	world.submit(SimCommand.ability(9, Ids.AB_EMP))
	world.step()
	world.events.drain()
	var back: SimWorld = VarietyDKit.through_json(world)
	assert_object(back).is_not_null()
	assert_str(back.state_hash()).is_equal(world.state_hash())
	assert_int(back.alive_count()).is_equal(world.alive_count())
	for i: int in 900:
		_step(world)
		_step(back)
	assert_str(back.state_hash()).is_equal(world.state_hash())
	assert_int(back.events.event_hash).is_equal(world.events.event_hash)
	assert_int(back.events.total).is_equal(world.events.total)
	var s1: RunSummary = world.summary("r")
	var s2: RunSummary = back.summary("r")  # the unhashed counters came back too
	assert_array(Array(s2.kills_by_type)).is_equal(Array(s1.kills_by_type))
	assert_array(Array(s2.peak_alive_by_wave)).is_equal(Array(s1.peak_alive_by_wave))
	assert_int(s2.scrap_earned).is_equal(s1.scrap_earned)
	assert_int(s2.combat_ticks).is_equal(s1.combat_ticks)
	assert_array(Array(s2.damage_by_source)).is_equal(Array(s1.damage_by_source))


func test_the_rng_streams_and_the_seen_command_ids_come_back() -> void:
	var world: SimWorld = _boosted(TestContent.baseline(), 4)
	for i: int in 400:
		world.step()
	world.submit(SimCommand.ability(31, Ids.AB_SHIELD))
	world.submit(SimCommand.ability(32, Ids.AB_EMP))
	world.step()
	world.events.drain()
	world.rng.stream(&"draft:3").randi()  # a stream the fresh world does not have
	var back: SimWorld = VarietyDKit.through_json(world)
	assert_str(back.state_hash()).is_equal(world.state_hash())
	for stream_name: StringName in [&"spawn", &"steer", &"draft:3"]:
		assert_int(back.rng.stream(stream_name).randi()).is_equal(world.rng.stream(stream_name).randi())
	assert_array(back.phase_state.seen_command_ids.keys()).is_equal([31, 32])
	# a repeated id is still a duplicate after the restore, a new one is not
	back.scrap = 5000
	back.submit(SimCommand.purchase(31, Ids.UP_DAMAGE))
	back.step()
	assert_int(back.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
	back.submit(SimCommand.purchase(777777, Ids.UP_DAMAGE))
	back.step()
	assert_int(back.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)


func test_restoring_draws_from_no_stream_and_keeps_64_bit_values() -> void:
	var world: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 2))
	for i: int in world.content.mission.prepare_ticks + 300:
		world.step()
		world.events.drain()
	world.events.event_hash = -8070450532247928833  # beyond 2^53: a JSON number would lose it
	var doc: Dictionary = WorldSnapshot.capture(world)
	var rows: Array = doc["rng"]
	assert_int(rows.size()).is_greater(0)
	var back: SimWorld = VarietyDKit.through_json(world)
	assert_int(back.events.event_hash).is_equal(-8070450532247928833)
	assert_array(WorldSnapshot.capture(back)["rng"]).is_equal(rows)
	for row: Array in rows:
		assert_int(typeof(row[1])).is_equal(TYPE_STRING)  # the 64-bit state travels as text


func test_floats_come_back_bit_for_bit() -> void:
	# The engine's JSON writer rounds some doubles and turns -0.0 into 0.0; the snapshot must not.
	var world: SimWorld = TestContent.variety_world(1)
	var nasty: Array[float] = [
		0.1, -0.0, 1.0 / 3.0, 10.761666666666667, -1.3384174592533107, 5e-324, 1.7976931348623157e308, INF, -INF,
		123456789.123456789, 4.0,
	]
	for i: int in nasty.size():
		world.enemies.x[i] = nasty[i]
		world.hazards.q_x.append(nasty[i])
	world.core_hp = 0.30000000000000004
	world.mods.w_dmg_mul = 1.1 * 1.1 * 1.1
	var back: SimWorld = VarietyDKit.through_json(world)
	assert_str(back.state_hash()).is_equal(world.state_hash())
	assert_bool(var_to_bytes(back.enemies.x) == var_to_bytes(world.enemies.x)).is_true()
	assert_bool(var_to_bytes(back.hazards.q_x) == var_to_bytes(world.hazards.q_x)).is_true()
	assert_bool(var_to_bytes(back.core_hp) == var_to_bytes(world.core_hp)).is_true()
	assert_bool(var_to_bytes(back.mods.w_dmg_mul) == var_to_bytes(world.mods.w_dmg_mul)).is_true()


## The saved field names of one section object.
func _fields(key: String, part: Object) -> PackedStringArray:
	if key == "world":
		return WorldSnapshot.WORLD_FIELDS
	if key == "nav":
		return WorldSnapshot.NAV_FIELDS
	if key == "slots":
		return WorldSnapshot.SLOT_FIELDS
	var script: Script = part.get_script()
	var consts: Dictionary = script.get_script_constant_map()
	if consts.has("FIELDS"):
		var listed: PackedStringArray = consts["FIELDS"]
		return listed
	return WorldSnapshot.fields_of(part)


## Changes the value of one field so that it differs from what a fresh world holds.
func _mutate(o: Object, field: String, salt: int) -> void:
	var v: Variant = o.get(field)
	match typeof(v):
		TYPE_INT:
			var i: int = v
			o.set(field, i + 1 + salt % 3)
		TYPE_BOOL:
			var b: bool = v
			o.set(field, not b)
		TYPE_FLOAT:
			var f: float = v
			o.set(field, f + 0.1 + float(salt) * 0.01)
		TYPE_PACKED_INT32_ARRAY:
			var ia: PackedInt32Array = v
			if ia.is_empty():
				ia.append(0)
			ia[ia.size() - 1] += 2 + salt % 5
			o.set(field, ia)
		TYPE_PACKED_FLOAT64_ARRAY:
			var fa: PackedFloat64Array = v
			if fa.is_empty():
				fa.append(0.0)
			fa[fa.size() - 1] += 0.3 + float(salt) * 0.01
			o.set(field, fa)
		TYPE_PACKED_BYTE_ARRAY:
			var ba: PackedByteArray = v
			if ba.is_empty():
				ba.append(0)
			ba[ba.size() - 1] = (ba[ba.size() - 1] + 1 + salt % 7) % 200
			o.set(field, ba)


func _sections(world: SimWorld) -> Dictionary:
	var out: Dictionary = {"world": world, "nav": world.nav, "slots": world.nav.slots, "phase_state": world.phase_state}
	for key: String in WorldSnapshot.DUMPED + WorldSnapshot.VARIETY:
		out[key] = world.get(key)
	return out


func test_every_saved_field_of_every_section_comes_back() -> void:
	# Change every field of every state object, save, restore into a fresh world: every field must hold the changed
	# value again (so no field is saved but not restored, and none is left out of the capture).
	var world: SimWorld = TestContent.variety_world(3)
	var sections: Dictionary = _sections(world)
	var salt: int = 0
	for key: String in sections:
		var part: Object = sections[key]
		var names: PackedStringArray = _fields(key, part)
		assert_int(names.size()).override_failure_message(key).is_greater(0)
		for field: String in names:
			salt += 1
			_mutate(part, field, salt)
	var back: SimWorld = VarietyDKit.through_json(world)
	assert_object(back).is_not_null()
	var back_sections: Dictionary = _sections(back)
	var checked: int = 0
	for key: String in sections:
		var part: Object = sections[key]
		var twin: Object = back_sections[key]
		for field: String in _fields(key, part):
			checked += 1
			var same: bool = var_to_bytes(twin.get(field)) == var_to_bytes(part.get(field))
			assert_bool(same).override_failure_message("%s.%s did not come back" % [key, field]).is_true()
	assert_int(checked).is_greater(200)
	assert_str(back.state_hash()).is_equal(world.state_hash())


func test_every_script_variable_of_the_frozen_classes_is_a_saved_field() -> void:
	var world: SimWorld = TestContent.variety_world(1)
	var doc: Dictionary = WorldSnapshot.capture(world)
	for key: String in WorldSnapshot.DUMPED:
		var part: Object = world.get(key)
		var section: Dictionary = doc[key]
		var script: Script = part.get_script()
		for p: Dictionary in script.get_script_property_list():
			var field: String = p["name"]
			var usage: int = p["usage"]
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				assert_bool(section.has(field)).override_failure_message("%s.%s is not captured" % [key, field]).is_true()
	var phase_doc: Dictionary = doc["phase_state"]
	for field: String in ["force_wave_spawned", "run_finished", "awaiting", "act", "breather", "seen_command_ids"]:
		assert_bool(phase_doc.has(field)).is_true()
	for key: String in WorldSnapshot.VARIETY:
		assert_bool(doc.has(key)).is_true()


func test_restore_refuses_another_version_and_a_missing_section() -> void:
	var world: SimWorld = TestContent.world(1)
	var doc: Dictionary = WorldSnapshot.capture(world)
	var fresh: SimWorld = TestContent.world(1)
	assert_bool(WorldSnapshot.restore(fresh, {"version": 1})).is_false()
	assert_bool(WorldSnapshot.restore(fresh, {})).is_false()
	for key: String in ["world", "enemies", "nav", "rng", "phase_state", "mods", "plan"]:
		var broken: Dictionary = doc.duplicate()
		broken.erase(key)
		assert_bool(WorldSnapshot.restore(fresh, broken)).override_failure_message(key).is_false()
	assert_bool(WorldSnapshot.restore(fresh, doc)).is_true()
	assert_str(fresh.state_hash()).is_equal(world.state_hash())

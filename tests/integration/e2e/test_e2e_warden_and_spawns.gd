extends GdUnitTestSuite
## A03 and A05 through Game: the Warden is fixed and cannot be aimed or moved by the player (taps, drags, mouse and keys
## on the battlefield change nothing), it picks its own targets in range and turns toward them; hostiles appear in the
## spawn regions on the right and walk toward the core.

var _h: GameHarness


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--scenario=hold16", "--seed=8"]), IntegrationKit.short_prepare)
	_h.boot()


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


## Touches, drags, mouse buttons and keys over the whole window, through the viewport like the engine would.
func _hammer_the_screen() -> void:
	var vp: Viewport = get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	for k: int in 12:
		var at: Vector2 = Vector2(size.x * (0.1 + 0.07 * float(k)), size.y * (0.2 + 0.05 * float(k)))
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = true
		vp.push_input(touch)
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = 0
		drag.position = at + Vector2(40.0, -30.0)
		drag.relative = Vector2(40.0, -30.0)
		vp.push_input(drag)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.pressed = true
		vp.push_input(click)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = at + Vector2(10.0, 10.0)
		motion.relative = Vector2(10.0, 10.0)
		vp.push_input(motion)
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_LEFT if k % 2 == 0 else KEY_D
		key.pressed = true
		vp.push_input(key)
		touch.pressed = false
		vp.push_input(touch)


func test_nothing_the_player_does_on_the_battlefield_moves_or_aims_the_warden() -> void:
	var w: WardenState = _h.rc().sim.warden
	var home: Vector2 = Vector2(w.x, w.z)
	for round_index: int in 5:
		_hammer_the_screen()
		_h.frames(60)
		assert_vector(Vector2(w.x, w.z)).is_equal(home)  # fixed in place
	# the aim is whatever the targeting says: toward the locked enemy, or untouched while there is none
	var target_index: int = _h.rc().sim.enemies.index_of(w.target_id)
	assert_int(target_index).is_greater_equal(0)
	var to_target: Vector2 = Vector2(
		_h.rc().sim.enemies.x[target_index] - w.x, _h.rc().sim.enemies.z[target_index] - w.z
	).normalized()
	var aim: Vector2 = Vector2(w.aim_x - w.x, w.aim_z - w.z).normalized()
	assert_float(aim.dot(to_target)).is_greater(0.99)


func test_the_warden_only_ever_locks_enemies_inside_its_range_and_turns_to_them() -> void:
	var sim: SimWorld = _h.rc().sim
	var w: WardenState = sim.warden
	var reach: float = sim.content.weapons[w.weapon_index].range_m
	var locked_frames: int = 0
	for i: int in 900:
		_h.frames(1)
		if w.target_id == 0:
			continue
		locked_frames += 1
		var e: int = sim.enemies.index_of(w.target_id)
		assert_int(e).is_greater_equal(0)  # a lock is always a living enemy
		var dx: float = sim.enemies.x[e] - w.x
		var dz: float = sim.enemies.z[e] - w.z
		assert_float(sqrt(dx * dx + dz * dz)).is_less_equal(reach + 0.5)  # a step of movement after the pick, at most
	assert_int(locked_frames).is_greater(400)
	assert_int(sim.warden.shots_fired).is_greater(15)


func test_the_warden_is_silent_until_hostiles_appear_and_then_shoots_without_any_input() -> void:
	var sim: SimWorld = _h.rc().sim
	_h.frames(_h.content.mission.prepare_ticks - 1)  # still PREPARING: nobody has spawned yet
	assert_int(sim.alive_count()).is_equal(0)
	assert_int(sim.warden.shots_fired).is_equal(0)
	assert_int(sim.warden.target_id).is_equal(0)
	_h.frames(240)  # the crowd arrives; nobody touches the screen
	assert_int(sim.warden.shots_fired).is_greater(0)
	assert_int(_h.events_log.count(&"shot_fired")).is_equal(sim.warden.shots_fired + sim.combat.shots_by_source[1] + sim.combat.shots_by_source[2])

func test_hostiles_spawn_on_the_right_and_walk_toward_the_core() -> void:
	var sim: SimWorld = _h.rc().sim
	var arena: ArenaDef = _h.content.arena
	var seen: Dictionary[int, float] = {}  # enemy id -> distance to the core at first sight
	var checked: int = 0
	var closer: int = 0
	for i: int in 900:
		_h.frames(1)
		for s: int in sim.enemies.high_water:
			if sim.enemies.alive[s] == 0:
				continue
			var id: int = sim.enemies.id[s]
			var dist: float = Vector2(sim.enemies.x[s] - arena.core_x, sim.enemies.z[s] - arena.core_z).length()
			if not seen.has(id):
				seen[id] = dist
				if sim.enemies.spawn_tick[s] >= sim.tick - 1:  # first sight right after it appeared: still inside a region
					var on_region: bool = false
					for r: SpawnRegionDef in arena.spawn_regions:
						if sim.enemies.x[s] >= minf(r.x0, r.x1) - 0.3 and sim.enemies.x[s] <= maxf(r.x0, r.x1) + 0.3 \
								and sim.enemies.z[s] >= minf(r.z0, r.z1) - 0.3 and sim.enemies.z[s] <= maxf(r.z0, r.z1) + 0.3:
							on_region = true
					assert_bool(on_region).is_true()
					assert_float(sim.enemies.x[s]).is_greater(arena.core_x + 5.0)  # the right edge or the top edge, far from the core on the left
					checked += 1
			elif dist < seen[id] - 3.0:
				closer += 1
				seen[id] = -1000.0  # count each enemy once
	assert_int(checked).is_greater(15)
	assert_int(closer).is_greater(10)  # most of them are well on the way to the core after 15 seconds

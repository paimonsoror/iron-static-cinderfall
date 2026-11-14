extends GdUnitTestSuite
## V5-A: the turret types of the Archive's field options (CONTENT 8 and 12; TurretTypes). Which type stands on a pad
## follows the run's unlocks; the arc turret ignores armor and chains to 2 enemies within 2.5 m at 70% a jump; the mortar
## turret lobs a 2 m blast at the densest cluster between 8 and 22 m, 0.8 s in the air; the plain gun is unchanged.

const ARC_DAMAGE: float = 16.0
const MORTAR_DAMAGE: float = 70.0  # V5-C: was 45
const GUN_DAMAGE: float = 15.0  # V5-C: was 12


func _world(unlocks: PackedStringArray) -> SimWorld:
	var cfg: SimConfig = SimConfig.create(TestContent.variety(), 1)
	cfg.unlocked = unlocks
	var w: SimWorld = SimWorld.new(cfg)
	w.phase = GameState.Id.SPAWNING
	VarietyVKit.begin_wave(w, 4)
	VarietyVKit.clear_plan(w)
	return w


func _foe(w: SimWorld, type_index: int, x: float, z: float) -> int:
	var i: int = VarietyVKit.place(w, type_index, x, z)
	VarietyVKit.tough(w, i)
	return i


func _shots(w: SimWorld, pad: int) -> int:
	return w.combat.shots_by_source[DamageSource.Id.TURRET_0 + pad]


func _run_until_shots(w: SimWorld, pad: int, shots: int, limit: int = 600) -> void:
	for _n: int in limit:
		if _shots(w, pad) >= shots:
			return
		VarietyVKit.tick(w)


func test_the_unlocks_decide_the_type_of_each_pad() -> void:
	var none: SimWorld = _world(PackedStringArray())
	assert_array([TurretTypes.id_of(none, 0), TurretTypes.id_of(none, 1)]).is_equal([TurretTypes.GUN, TurretTypes.GUN])
	assert_object(TurretTypes.special_of(none, 1)).is_null()
	var arc: SimWorld = _world(PackedStringArray(["u_f_turret_arc"]))
	assert_array([TurretTypes.id_of(arc, 0), TurretTypes.id_of(arc, 1)]).is_equal([TurretTypes.GUN, TurretTypes.ARC])
	var mortar: SimWorld = _world(PackedStringArray(["u_f_turret_mortar"]))
	assert_array([TurretTypes.id_of(mortar, 0), TurretTypes.id_of(mortar, 1)]).is_equal([TurretTypes.GUN, TurretTypes.MORTAR])
	var both: SimWorld = _world(PackedStringArray(["u_f_turret_arc", "u_f_turret_mortar"]))
	assert_array([TurretTypes.id_of(both, 0), TurretTypes.id_of(both, 1)]).is_equal([TurretTypes.ARC, TurretTypes.MORTAR])
	assert_str(String(TurretTypes.special_of(both, 0).id)).is_equal("turret_arc")
	assert_float(TurretTypes.special_of(both, 1).damage).is_equal(MORTAR_DAMAGE)
	assert_str(String(TurretTypes.id_of(TestContent.world(), 1))).is_equal("turret_gun")  # the legacy content


func test_the_arc_turret_ignores_armor_and_chains_to_two_neighbours() -> void:
	var w: SimWorld = _world(PackedStringArray(["u_f_turret_arc"]))
	w.turrets.active[1] = 1
	var tx: float = w.turrets.x[1]
	var tz: float = w.turrets.z[1]
	var target: int = _foe(w, Ids.EN_HOLLOW, tx + 4.0, tz)  # armor 8: the arc does not care
	w.enemies.path_dist[target] = 1.0
	var second: int = _foe(w, Ids.EN_SKITTER, tx + 6.0, tz)  # 2 m from the target
	var third: int = _foe(w, Ids.EN_SKITTER, tx + 8.0, tz)  # 2 m from the second
	var far: int = _foe(w, Ids.EN_SKITTER, tx + 11.5, tz)  # 3.5 m from the third: out of the chain's reach
	w.enemies.path_dist[far] = 500.0
	_run_until_shots(w, 1, 1)
	assert_int(_shots(w, 1)).is_equal(1)
	assert_float(VarietyVKit.taken(w, target)).is_equal_approx(ARC_DAMAGE, 1e-5)
	assert_float(VarietyVKit.taken(w, second)).is_equal_approx(ARC_DAMAGE * 0.7, 1e-5)
	assert_float(VarietyVKit.taken(w, third)).is_equal_approx(ARC_DAMAGE * 0.49, 1e-5)
	assert_float(VarietyVKit.taken(w, far)).is_equal(0.0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(2)
	# 1.2 shots a second: the second shot comes 50 ticks after the first
	var first_tick: int = w.tick
	_run_until_shots(w, 1, 2)
	assert_int(w.tick - first_tick).is_equal(50)


func test_the_arc_turret_holds_its_fire_beyond_fourteen_metres() -> void:
	var w: SimWorld = _world(PackedStringArray(["u_f_turret_arc"]))
	w.turrets.active[1] = 1
	_foe(w, Ids.EN_SKITTER, w.turrets.x[1] + 15.0, w.turrets.z[1])
	VarietyVKit.run(w, 200)
	assert_int(_shots(w, 1)).is_equal(0)


func test_the_gun_on_the_first_pad_is_the_turret_it_always_was() -> void:
	var w: SimWorld = _world(PackedStringArray(["u_f_turret_arc"]))
	w.turrets.active[0] = 1
	var target: int = _foe(w, Ids.EN_SKITTER, w.turrets.x[0] + 4.0, w.turrets.z[0])
	var near: int = _foe(w, Ids.EN_SKITTER, w.turrets.x[0] + 5.5, w.turrets.z[0])
	w.enemies.path_dist[target] = 1.0
	_run_until_shots(w, 0, 2)
	assert_float(VarietyVKit.taken(w, target)).is_equal(2.0 * GUN_DAMAGE)
	assert_float(VarietyVKit.taken(w, near)).is_equal(0.0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(0)


func test_the_mortar_turret_lobs_a_blast_at_the_densest_cluster_in_its_band() -> void:
	var w: SimWorld = _world(PackedStringArray(["u_f_turret_mortar"]))
	w.turrets.active[1] = 1
	var tx: float = w.turrets.x[1]
	var tz: float = w.turrets.z[1]
	var close: int = _foe(w, Ids.EN_SKITTER, tx + 5.0, tz)  # inside the 8 m minimum: never the target
	var centre: int = _foe(w, Ids.EN_SKITTER, tx + 12.0, tz)
	var beside: int = _foe(w, Ids.EN_SKITTER, tx + 13.0, tz)
	var edge: int = _foe(w, Ids.EN_SKITTER, tx + 12.0, tz + 2.0)
	_run_until_shots(w, 1, 1)
	assert_int(_shots(w, 1)).is_equal(1)
	var launched: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)
	assert_int(launched.size()).is_equal(1)
	assert_int(launched[0].a).is_equal(HazardState.K_SHELL)
	assert_int(launched[0].b).is_equal(48)  # 0.8 s in the air
	assert_float(VarietyVKit.taken(w, centre)).is_equal(0.0)  # still flying
	assert_int(w.turrets.target_id[1]).is_equal(0)  # the mortar keeps no lock
	VarietyVKit.run(w, 48)
	var at_centre: float = maxf(VarietyVKit.taken(w, centre), VarietyVKit.taken(w, beside))
	assert_float(at_centre).is_equal_approx(MORTAR_DAMAGE, 1e-5)  # full damage where it lands
	assert_float(VarietyVKit.taken(w, centre)).is_greater(MORTAR_DAMAGE * 0.5 - 1e-5)
	assert_float(VarietyVKit.taken(w, beside)).is_greater(MORTAR_DAMAGE * 0.5 - 1e-5)
	assert_float(VarietyVKit.taken(w, edge)).is_greater(0.0)
	assert_float(VarietyVKit.taken(w, close)).is_equal(0.0)
	assert_int(w.hazards.pool_count()).is_equal(0)  # a turret shell leaves no slag pool


func test_the_mortar_turret_waits_while_nothing_stands_in_its_band() -> void:
	var w: SimWorld = _world(PackedStringArray(["u_f_turret_mortar"]))
	w.turrets.active[1] = 1
	_foe(w, Ids.EN_SKITTER, w.turrets.x[1] + 5.0, w.turrets.z[1])  # too close
	VarietyVKit.run(w, 400)
	assert_int(_shots(w, 1)).is_equal(0)
	assert_int(w.turrets.fire_acc_milli[1]).is_equal(TurretTypes.MILLI_PER_SHOT)  # a shot is banked, no more
	_foe(w, Ids.EN_SKITTER, w.turrets.x[1] + 10.0, w.turrets.z[1])
	VarietyVKit.tick(w)
	assert_int(_shots(w, 1)).is_equal(1)  # and goes the moment a target is there


func test_the_turret_types_take_the_turret_directives() -> void:
	var w: SimWorld = _world(PackedStringArray(["u_f_turret_arc"]))
	w.mods.t_dmg_mul = 1.5
	var arc: TurretTypeDef = TurretTypes.special_of(w, 1)
	assert_float(TurretTypes.damage_of(w, arc, -1, false)).is_equal_approx(ARC_DAMAGE * 1.5, 1e-5)
	w.mods.range_mul = 0.7  # the Rain Squall
	assert_float(TurretTypes.range_of(w, arc)).is_equal_approx(14.0 * 0.7, 1e-5)

extends GdUnitTestSuite
## V5-A: the call points the V4 tasks left for the integration (v4 reports, "needs owner"): the ModRules factors in the
## arsenal and the damage path, the Core Surge and bottomless rules of the magazine, strays on fuel drums, shards inside
## the blast that broke their splitter, the two new sim events, the defeat check and the wave-clear effects.

const PISTOL_DAMAGE: float = 30.0
const PISTOL_RELOAD_TICKS: int = 75


func _pistol(w: SimWorld) -> WeaponDef:
	return w.content.weapons[Ids.WP_PISTOL]


func _events(w: SimWorld, kind: int) -> Array[SimEvent]:
	return VarietyCKit.events_of(w, kind)


# --- ModRules factors ---


func test_static_pact_doubles_the_fire_rate_during_a_static_front() -> void:
	var w: SimWorld = DirectiveKit.world()
	var base: int = ArsenalSystem.sps_milli(w, _pistol(w))
	DirectiveKit.give(w, &"static_pact")
	assert_int(ArsenalSystem.sps_milli(w, _pistol(w))).is_equal(base)  # no front, no bonus
	w.events_state.ability_lock_ticks = 300
	assert_int(ArsenalSystem.sps_milli(w, _pistol(w))).is_equal(base * 2)
	w.events_state.ability_lock_ticks = 0
	assert_int(ArsenalSystem.sps_milli(w, _pistol(w))).is_equal(base)


func test_scrap_rounds_and_the_tally_multiply_the_warden_damage() -> void:
	var w: SimWorld = DirectiveKit.world()
	var i: int = DirectiveKit.place(w, Ids.EN_HOLLOW, 0.0, 0.0)
	DirectiveKit.set_hp(w, i, w.enemies.max_hp[i] * 0.5)  # neither full nor low: no conditional multiplier
	assert_float(DamageResolver.warden_amount(w, i, _pistol(w), 1)).is_equal_approx(PISTOL_DAMAGE, 1e-6)
	DirectiveKit.give(w, &"scrap_rounds")
	w.scrap = 400  # +1% per 40 Scrap
	assert_float(DamageResolver.warden_amount(w, i, _pistol(w), 1)).is_equal_approx(PISTOL_DAMAGE * 1.10, 1e-6)
	w.scrap = 40000
	assert_float(DamageResolver.warden_amount(w, i, _pistol(w), 1)).is_equal_approx(PISTOL_DAMAGE * 1.60, 1e-6)  # the cap
	w.scrap = 0
	DirectiveKit.give(w, &"the_tally")
	HookMemory.set_tally(w, 25, 0)
	assert_float(DamageResolver.warden_amount(w, i, _pistol(w), 1)).is_equal_approx(PISTOL_DAMAGE * 1.25, 1e-6)
	# the legacy content has no such rule
	var legacy: SimWorld = TestContent.world()
	var j: int = legacy.spawn_enemy(Ids.EN_HOLLOW, 5.0, 0.0)
	legacy.enemies.hp[j] *= 0.5
	assert_float(DamageResolver.warden_amount(legacy, j, legacy.content.weapons[0], 1)).is_equal(legacy.content.weapons[0].damage)


func test_last_stand_halves_the_reload_below_35_percent_core() -> void:
	var w: SimWorld = DirectiveKit.world()
	assert_int(ArsenalSystem.reload_ticks_of(w, _pistol(w))).is_equal(PISTOL_RELOAD_TICKS)
	DirectiveKit.give(w, &"last_stand_protocol")
	assert_int(ArsenalSystem.reload_ticks_of(w, _pistol(w))).is_equal(PISTOL_RELOAD_TICKS)  # the core is whole
	w.set_core_hp(w.core_max_hp * 0.30)
	assert_int(ArsenalSystem.reload_ticks_of(w, _pistol(w))).is_equal(roundi(float(PISTOL_RELOAD_TICKS) * 0.5))
	w.set_core_hp(w.core_max_hp * 0.40)
	assert_int(ArsenalSystem.reload_ticks_of(w, _pistol(w))).is_equal(PISTOL_RELOAD_TICKS)


# --- the Core Surge and bottomless ---


func test_a_core_surge_makes_reload_and_vent_instant_and_ends_a_running_reload() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_PISTOL)
	var arc: WeaponDef = w.content.weapons[Ids.WP_ARC_PROJECTOR]
	assert_int(ArsenalSystem.vent_ticks_of(w, arc)).is_greater(1)
	w.arsenal.slot_magazine[0] = 0
	w.arsenal.slot_reload_left[0] = 60
	ArsenalSystem.give_weapon(w, 1, Ids.WP_SMG)
	w.arsenal.slot_magazine[1] = 0
	w.arsenal.slot_reload_left[1] = 90  # the holstered weapon reloads too
	VarietyCKit.weapon_tick(w)
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(59)  # no surge: the reload counts down as ever
	w.events_state.turret_rate_ticks = 600  # the 10 s of a Core Surge
	w.events_state.turret_rate_milli = 2000
	assert_bool(EventRates.surge_active(w)).is_true()
	assert_int(ArsenalSystem.reload_ticks_of(w, _pistol(w))).is_equal(1)
	assert_int(ArsenalSystem.vent_ticks_of(w, arc)).is_equal(1)
	VarietyCKit.weapon_tick(w)
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(_pistol(w).magazine)
	assert_int(w.arsenal.slot_reload_left[1]).is_equal(0)
	assert_int(w.arsenal.slot_magazine[1]).is_equal(w.content.weapons[Ids.WP_SMG].magazine)


func test_bottomless_shots_cost_no_round_while_overdrive_runs() -> void:
	var w: SimWorld = DirectiveKit.world()
	ArsenalWKit.arm(w, Ids.WP_PISTOL)
	DirectiveKit.give(w, &"bottomless")
	assert_bool(w.mods.has_flag(&"od_free_ammo")).is_true()
	ArsenalWKit.foe(w, Ids.EN_HOLLOW, 6.0, 0.0, true)
	var full: int = w.arsenal.slot_magazine[0]
	assert_bool(ArsenalFire.free_ammo(w)).is_false()
	VarietyCKit.run_weapon(w, 60)
	var spent: int = full - w.arsenal.slot_magazine[0]
	assert_int(spent).is_greater(0)  # without Overdrive a shot takes a round
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 600
	assert_bool(ArsenalFire.free_ammo(w)).is_true()
	var shots: int = w.warden.shots_fired
	var left: int = w.arsenal.slot_magazine[0]
	VarietyCKit.run_weapon(w, 60)
	assert_int(w.warden.shots_fired).is_greater(shots)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(left)


# --- strays, shards, the new events ---


func test_an_lmg_stray_can_hit_a_fuel_drum_next_to_the_target() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	w.wave = 1
	HazardDrums.place(w, 1)
	assert_int(HazardDrums.alive_count(w)).is_equal(3)
	var p: Vector2 = HazardDrums.position_of(w, 0)
	var target: int = VarietyCKit.place(w, Ids.EN_HOLLOW, p.x + 0.5, p.y)
	VarietyCKit.tough(w, target)
	w.enemies.path_dist[target] = 1.0
	w.arsenal.slot_magazine[0] = 100000
	for _n: int in 1200:
		ArsenalWKit.both_tick(w)
		if HazardDrums.alive_count(w) < 3:
			break
	# a quarter of the rounds stray, and the only thing within 1.5 m of the target is the drum: 80 damage light it
	assert_int(HazardDrums.alive_count(w)).is_less(3)
	assert_int(w.warden.shots_fired).is_less(200)


func test_the_shards_of_a_splitter_killed_by_a_blast_die_in_the_same_blast() -> void:
	var w: SimWorld = VarietyCKit.world()
	var splitter: int = VarietyCKit.place(w, Ids.EN_SPLITTER, 6.0, 0.0)
	var bystander: int = VarietyCKit.place(w, Ids.EN_SKITTER, 6.5, 0.5)
	assert_bool(w.enemies.alive[bystander] == 1).is_true()
	var hit: int = AreaDamage.blast(w, 6.0, 0.0, 3.0, 500.0, 1.0, DamageResolver.F_AREA, DamageSource.Id.HAZARD)
	assert_int(w.enemies.alive[splitter]).is_equal(0)
	assert_int(w.stats.kills_by_type[Ids.EN_SPLITTER]).is_equal(1)
	assert_int(w.stats.kills_by_type[Ids.EN_SHARD]).is_equal(3)  # GDD 6.3: area damage kills the shards with their splitter
	assert_int(w.alive_count()).is_equal(0)
	assert_int(hit).is_equal(2 + 3)
	# a blast too weak for the shards leaves them standing, hurt
	var weak: SimWorld = VarietyCKit.world()
	var second: int = VarietyCKit.place(weak, Ids.EN_SPLITTER, 6.0, 0.0)
	weak.enemies.hp[second] = 5.0
	AreaDamage.blast(weak, 6.0, 0.0, 3.0, 10.0, 1.0, DamageResolver.F_AREA, DamageSource.Id.HAZARD)
	assert_int(weak.alive_count()).is_equal(3)
	for i: int in weak.enemies.high_water:
		if weak.enemies.alive[i] == 1:
			assert_float(weak.enemies.hp[i]).is_less(weak.enemies.max_hp[i])


func test_the_rail_lance_announces_its_charge() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_RAIL_LANCE)
	ArsenalWKit.foe(w, Ids.EN_HOLLOW, 10.0, 0.0, true)
	for _n: int in 400:
		VarietyCKit.weapon_tick(w)
		if w.warden.shots_fired >= 1:
			break
	var charging: Array[SimEvent] = _events(w, SimEventKind.Id.WEAPON_CHARGING)
	assert_int(charging.size()).is_equal(1)  # one wind-up per shot
	assert_int(charging[0].a).is_equal(0)  # the slot
	assert_int(charging[0].b).is_equal(w.content.weapons[Ids.WP_RAIL_LANCE].charge_ticks)
	assert_float(charging[0].f).is_equal(w.arsenal.charge_x)
	var shots: Array[SimEvent] = _events(w, SimEventKind.Id.SHOT_FIRED)
	assert_int(shots.size()).is_equal(1)
	assert_int(shots[0].tick - charging[0].tick).is_greater_equal(w.content.weapons[Ids.WP_RAIL_LANCE].charge_ticks)


func test_single_point_announces_every_turret_it_takes_away() -> void:
	var w: SimWorld = DirectiveKit.world()
	DirectiveKit.give(w, &"turret_deploy", 2)
	assert_int(w.turrets.active_count()).is_equal(2)
	DirectiveKit.give(w, &"single_point")
	assert_int(w.turrets.active_count()).is_equal(0)
	var removed: Array[SimEvent] = DirectiveKit.events_of(w, SimEventKind.Id.TURRET_REMOVED)
	assert_int(removed.size()).is_equal(2)
	assert_array([removed[0].a, removed[1].a]).is_equal([0, 1])
	ModSystem.recompute(w)
	assert_int(DirectiveKit.events_of(w, SimEventKind.Id.TURRET_REMOVED).size()).is_equal(2)  # nothing stood: nothing more is said


# --- the defeat check and the wave clear ---


func test_the_defeat_check_asks_the_dead_mans_switch_whatever_emptied_the_core() -> void:
	var w: SimWorld = DirectiveKit.world()
	DirectiveKit.give(w, &"dead_mans_switch")
	w.set_core_hp(0.0)  # not an enemy hit: a blast near the cage, a beam, a debug write
	PhaseSystem.post_step(w)
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)  # saved, once
	assert_float(w.core_hp).is_equal_approx(w.core_max_hp * 0.2, 1e-6)
	w.set_core_hp(0.0)
	PhaseSystem.post_step(w)
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	var plain: SimWorld = DirectiveKit.world()
	plain.set_core_hp(0.0)
	PhaseSystem.post_step(plain)
	assert_int(plain.phase).is_equal(GameState.Id.DEFEAT)


func test_the_wave_clear_effects_run_once_before_the_first_await_and_not_again_at_the_draft() -> void:
	var w: SimWorld = TestContent.variety_world(3)
	var interest: int = w.content.directive_index(&"compound_interest")
	assert_bool(DraftSystem.grant_stack(w, interest)).is_true()
	w.scrap = 1000
	assert_bool(VarietyAKit.run_to_await(w)).is_true()  # wave 1 cleared: +10% of the banked Scrap, at most 150
	assert_int(w.waves_completed).is_equal(1)
	var after_clear: int = w.scrap
	assert_int(after_clear).is_greater_equal(1100)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	DraftSystem.open(w)  # opening a draft pays nothing: the hook has its own call point now
	assert_int(w.scrap).is_equal(after_clear)


func test_a_double_pick_and_a_rare_draft_reward_arm_the_draft_of_that_intermission() -> void:
	for reward_id: StringName in [&"rw_double_pick", &"rw_rare_draft"]:
		var w: SimWorld = TestContent.variety_world(3)
		assert_bool(VarietyAKit.run_to_await(w)).is_true()
		VarietyAKit.close_choice(w)  # the draft after wave 1
		w.plan.wave(2).options[0].reward_index = w.content.run.reward_index(reward_id)
		VarietyAKit.answer(w, 1, 0)  # route A into wave 2
		assert_bool(VarietyAKit.run_to_await(w)).is_true()
		if w.phase_state.awaiting == PhaseState.Await.SALVAGE:
			VarietyAKit.close_choice(w)  # the guaranteed crate
		assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
		if reward_id == &"rw_double_pick":
			assert_int(w.draft.picks_left).is_equal(2)
		else:
			var first: DirectiveDef = w.content.directives[w.draft.offer[0]]
			assert_int(first.rarity).is_greater_equal(DirectiveDef.RARITY_NAMES.find("rare"))

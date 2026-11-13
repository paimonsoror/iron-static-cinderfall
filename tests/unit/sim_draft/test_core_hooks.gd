extends GdUnitTestSuite
## V4-C: the hook directives of CoreHooks (CONTENT 3.3 and 3.4), each called at its hook point with exact numbers. Core at
## (-7.5, 3.0), cage radius 2.0, 1000 hp, shield 100. Enemies that must survive get a huge hp so damage can be counted.

const TOUGH: float = 1.0e9

var w: SimWorld


func before_test() -> void:
	w = DirectiveKit.world()


## A tough skitter `dx` metres from the core centre along +x.
func _dummy(dx: float) -> int:
	var i: int = DirectiveKit.place(w, Ids.EN_SKITTER, DirectiveKit.CORE_X + dx, DirectiveKit.CORE_Z)
	DirectiveKit.set_hp(w, i, TOUGH)
	return i


func _taken(i: int) -> float:
	return w.enemies.max_hp[i] - w.enemies.hp[i]


func test_reactive_plating_hits_the_attacker_back_for_25_per_stack_ignoring_armor() -> void:
	DirectiveKit.give(w, &"reactive_plating", 2)
	var hollow: int = DirectiveKit.attacker(w, Ids.EN_HOLLOW)  # armor 8, hp 150
	CoreHooks.on_core_hit(w, hollow, 12.0, 0.0)
	assert_float(w.enemies.hp[hollow]).is_equal(100.0)  # 50, not 42
	assert_float(w.combat.damage_by_source[DamageSource.Id.CORE]).is_equal(50.0)
	var skitter: int = DirectiveKit.attacker(w)  # hp 45: dies
	CoreHooks.on_core_hit(w, skitter, 12.0, 0.0)
	assert_int(w.enemies.alive[skitter]).is_equal(0)
	assert_int(w.combat.kills_by_source[DamageSource.Id.CORE]).is_equal(1)
	assert_int(w.scrap).is_equal(5)


func test_without_the_directive_a_core_hit_hurts_nobody() -> void:
	var hollow: int = DirectiveKit.attacker(w, Ids.EN_HOLLOW)
	CoreHooks.on_core_hit(w, hollow, 30.0, 0.0)
	assert_float(w.enemies.hp[hollow]).is_equal(150.0)
	assert_int(DirectiveKit.events_of(w, SimEventKind.Id.AREA_BLAST).size()).is_equal(0)


func test_ember_vent_fires_on_every_tenth_core_hit_in_a_five_metre_ring() -> void:
	DirectiveKit.give(w, &"ember_vent")
	var near: int = _dummy(4.0)
	var far: int = _dummy(6.0)
	w.combat.core_hits = 9
	CoreHooks.on_core_hit(w, -1, 0.0, 0.0)
	assert_float(_taken(near)).is_equal(0.0)
	w.combat.core_hits = 10
	CoreHooks.on_core_hit(w, -1, 0.0, 0.0)
	assert_float(_taken(near)).is_equal(120.0)
	assert_float(_taken(far)).is_equal(0.0)
	var blasts: Array[SimEvent] = DirectiveKit.events_of(w, SimEventKind.Id.AREA_BLAST)
	assert_int(blasts.size()).is_equal(1)
	assert_int(blasts[0].b).is_equal(500)
	DirectiveKit.give(w, &"overpressure")  # 5 m x 1.35 = 6.75 m
	w.combat.core_hits = 20
	CoreHooks.on_core_hit(w, -1, 0.0, 0.0)
	assert_float(_taken(near)).is_equal(240.0)
	assert_float(_taken(far)).is_equal(120.0)


func test_amber_surge_starts_a_free_shield_when_the_core_drops_below_half() -> void:
	DirectiveKit.give(w, &"amber_surge")
	CoreHooks.on_core_changed(w, 900.0, 600.0)
	assert_float(w.shield_hp).is_equal(0.0)
	CoreHooks.on_core_changed(w, 600.0, 450.0)
	assert_float(w.shield_hp).is_equal(100.0)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(0)  # no cooldown change
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(480)  # the ability is active: 8 s
	var changed: Array[SimEvent] = DirectiveKit.events_of(w, SimEventKind.Id.SHIELD_CHANGED)
	assert_float(changed[changed.size() - 1].f).is_equal(100.0)
	var started: Array[SimEvent] = DirectiveKit.events_of(w, SimEventKind.Id.ABILITY_ACTIVATED)
	assert_int(started.size()).is_equal(1)
	assert_int(started[0].a).is_equal(Ids.AB_SHIELD)
	w.shield_hp = 30.0
	CoreHooks.on_core_changed(w, 500.0, 499.0)  # a shield is up: nothing starts
	assert_float(w.shield_hp).is_equal(30.0)
	w.shield_hp = 0.0
	w.abilities.active_left[Ids.AB_SHIELD] = 0
	CoreHooks.on_core_changed(w, 450.0, 300.0)  # already below the line
	assert_float(w.shield_hp).is_equal(0.0)
	CoreHooks.on_core_changed(w, 500.0, 0.0)  # a lethal drop is the switch's business, not the surge's
	assert_float(w.shield_hp).is_equal(0.0)


func test_a_free_shield_gives_the_shield_cooldown_back_when_it_ends() -> void:
	DirectiveKit.give(w, &"amber_surge")
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 1234  # the real Shield is cooling down
	CoreHooks.on_core_changed(w, 600.0, 450.0)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(1234)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(480)
	assert_int(HookMemory.free_shield_cooldown(w)).is_equal(1234)
	assert_int(ModRules.held(w, &"amber_surge")).is_equal(1)  # the memory is not a stack
	# what AbilitySystem._end does when a shield ends: the cooldown starts
	w.abilities.active_left[Ids.AB_SHIELD] = 0
	w.shield_hp = 0.0
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 3000
	CoreHooks.on_shield_end(w)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(1234)
	assert_int(HookMemory.free_shield_cooldown(w)).is_equal(-1)
	assert_int(DirectiveKit.held(w, &"amber_surge")).is_equal(1)  # armed again for the next wave
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 3000  # a shield the player started: its cooldown stands
	CoreHooks.on_shield_end(w)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(3000)


func test_amber_surge_through_a_core_hit_and_with_shield_lattice() -> void:
	DirectiveKit.give(w, &"amber_surge")
	DirectiveKit.give(w, &"shield_lattice")
	w.set_core_hp(450.0)
	CoreHooks.on_core_hit(w, -1, 150.0, 0.0)  # it was 600 before this hit
	assert_float(w.shield_hp).is_equal(160.0)  # 100 + 60
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(600)  # 8 s + 2 s
	var other: SimWorld = DirectiveKit.world()
	other.set_core_hp(450.0)
	CoreHooks.on_core_hit(other, -1, 150.0, 0.0)  # without the directive nothing happens
	assert_float(other.shield_hp).is_equal(0.0)


func test_dead_mans_switch_saves_the_core_once_and_blasts_600_within_8_metres() -> void:
	DirectiveKit.give(w, &"dead_mans_switch")
	var near: int = _dummy(7.0)
	var far: int = _dummy(9.0)
	assert_bool(CoreHooks.allow_defeat(w)).is_true()  # the core still stands: nothing to save
	assert_bool(HookMemory.switch_armed(w)).is_true()
	w.set_core_hp(0.0)
	CoreHooks.on_core_hit(w, -1, 25.0, 0.0)
	assert_float(w.core_hp).is_equal(200.0)  # 20% of 1000
	assert_float(_taken(near)).is_equal(600.0)
	assert_float(_taken(far)).is_equal(0.0)
	assert_bool(HookMemory.switch_armed(w)).is_false()
	assert_int(DirectiveKit.held(w, &"dead_mans_switch")).is_equal(2)
	w.set_core_hp(0.0)
	assert_bool(CoreHooks.allow_defeat(w)).is_true()  # spent: the run is lost
	assert_float(w.core_hp).is_equal(0.0)
	assert_bool(DraftOffer.candidates(w).has(w.content.directive_index(&"dead_mans_switch"))).is_false()


func test_a_spent_switch_does_not_lean_the_draft_toward_fortress() -> void:
	DirectiveKit.give(w, &"dead_mans_switch")
	w.set_core_hp(0.0)
	var _lost: bool = CoreHooks.allow_defeat(w)
	var tags: Dictionary[StringName, int] = DraftSystem.build_tags(w)
	assert_int(tags.get(&"fortress", 0)).is_equal(1)  # one directive, not its spent marker


func test_the_tally_halves_through_an_empty_shield_at_most_once_per_five_seconds() -> void:
	w.combat.kills_by_source[DamageSource.Id.WARDEN] = 237
	DirectiveKit.give(w, &"the_tally")
	assert_int(HookMemory.tally_pct(w)).is_equal(23)  # the kills so far are credited
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.23, 0.00001)
	w.tick = 1000
	CoreHooks.on_core_hit(w, -1, 12.0, 0.0)
	assert_int(HookMemory.tally_pct(w)).is_equal(11)  # floor(23 / 2)
	assert_int(HookMemory.tally_last_tick(w)).is_equal(1000)
	w.tick = 1299
	CoreHooks.on_core_hit(w, -1, 12.0, 0.0)
	assert_int(HookMemory.tally_pct(w)).is_equal(11)  # inside the 5 s guard
	w.tick = 1300
	CoreHooks.on_core_hit(w, -1, 12.0, 0.0)
	assert_int(HookMemory.tally_pct(w)).is_equal(5)
	w.tick = 5000
	CoreHooks.on_core_hit(w, -1, 0.0, 12.0)  # the shield took it: no halving
	assert_int(HookMemory.tally_pct(w)).is_equal(5)
	assert_int(DirectiveKit.held(w, &"the_tally")).is_greater(1)  # the count is memory, not stacks
	assert_int(ModRules.held(w, &"the_tally")).is_equal(1)


func test_field_weld_and_compound_interest_at_wave_clear() -> void:
	DirectiveKit.give(w, &"field_weld", 2)
	DirectiveKit.give(w, &"compound_interest")
	w.set_core_hp(500.0)
	w.add_scrap(1000)
	CoreHooks.on_wave_cleared(w)
	assert_float(w.core_hp).is_equal_approx(540.0, 0.001)  # 2 x 2% of 1000
	assert_int(w.scrap).is_equal(1100)  # +10%
	w.add_scrap(5000 - w.scrap)
	CoreHooks.on_wave_cleared(w)
	assert_int(w.scrap).is_equal(5150)  # capped at +150
	w.set_core_hp(1000.0)
	CoreHooks.on_wave_cleared(w)
	assert_float(w.core_hp).is_equal(1000.0)  # never above the maximum


func test_no_breather_wave_brings_no_core_repair() -> void:
	DirectiveKit.give(w, &"field_weld")
	w.set_core_hp(500.0)
	w.plan.option(w.wave).modifier_index = -1  # whatever the plan rolled for this wave
	ModSystem.set_wave_modifier(w, w.content.run.modifier_index(&"mod_no_breather"))
	CoreHooks.on_wave_cleared(w)
	assert_float(w.core_hp).is_equal(500.0)
	ModSystem.set_wave_modifier(w, -1)
	CoreHooks.on_wave_cleared(w)
	assert_float(w.core_hp).is_equal_approx(520.0, 0.001)


func test_borrowed_time_takes_5_percent_of_the_core_after_every_wave() -> void:
	DirectiveKit.give(w, &"borrowed_time")
	var prototypes: int = 0  # stacks of prototype directives
	for d: DirectiveDef in w.content.directives:
		if d.rarity == DirectiveDef.Rarity.PROTOTYPE:
			prototypes += w.draft.stacks_of(d.index)
	assert_int(prototypes).is_equal(2)  # "2 random prototype directives now"
	assert_int(HookMemory.borrowed_waves(w)).is_equal(0)
	assert_float(w.core_max_hp).is_equal(1000.0)
	for n: int in 3:
		CoreHooks.on_wave_cleared(w)
		assert_int(HookMemory.borrowed_waves(w)).is_equal(n + 1)
	assert_float(w.mods.core_max_mul).is_equal_approx(0.85, 0.00001)
	assert_float(w.core_max_hp).is_equal(850.0)
	assert_float(w.core_hp).is_equal(850.0)  # a full core stays full
	assert_bool(DraftOffer.candidates(w).has(w.content.directive_index(&"borrowed_time"))).is_false()


func test_cascade_takes_six_seconds_off_the_other_cooldowns() -> void:
	DirectiveKit.give(w, &"cascade")
	w.abilities.cooldown_left[Ids.AB_EMP] = 2100
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 3000
	w.abilities.cooldown_left[Ids.AB_OVERDRIVE] = 200
	CoreHooks.on_ability(w, Ids.AB_EMP)
	assert_array(Array(w.abilities.cooldown_left)).is_equal([2100, 2640, 0])


func test_overclocked_core_costs_25_core_but_never_the_last_25() -> void:
	DirectiveKit.give(w, &"overclocked_core")
	CoreHooks.on_ability(w, Ids.AB_SHIELD)
	assert_float(w.core_hp).is_equal(975.0)
	w.set_core_hp(40.0)
	CoreHooks.on_ability(w, Ids.AB_SHIELD)
	assert_float(w.core_hp).is_equal(25.0)  # 40 - 25 = 15 would be below the last 25
	CoreHooks.on_ability(w, Ids.AB_SHIELD)
	assert_float(w.core_hp).is_equal(25.0)


func test_emp_overload_hits_only_the_stunned_for_60_per_stack_and_breaks_wards() -> void:
	DirectiveKit.give(w, &"emp_overload", 2)
	var stunned: int = _dummy(5.0)
	var free: int = _dummy(6.0)
	w.enemies.stun_ticks[stunned] = 180
	w.ext.ward_milli[stunned] = 80000
	CoreHooks.on_emp(w)
	assert_float(_taken(stunned)).is_equal(120.0)
	assert_float(_taken(free)).is_equal(0.0)
	assert_int(w.ext.ward_milli[stunned]).is_equal(0)
	assert_int(DirectiveKit.events_of(w, SimEventKind.Id.WARD_BROKEN).size()).is_equal(1)


func test_shield_burst_deals_150_within_6_metres_of_the_core() -> void:
	DirectiveKit.give(w, &"shield_burst")
	var near: int = _dummy(5.5)
	var far: int = _dummy(6.5)
	CoreHooks.on_shield_end(w)
	assert_float(_taken(near)).is_equal(150.0)
	assert_float(_taken(far)).is_equal(0.0)


func test_core_lash_fires_a_40_bolt_every_1_5_seconds_at_the_best_attacker() -> void:
	DirectiveKit.give(w, &"core_lash")
	var first: int = DirectiveKit.attacker(w)
	var second: int = DirectiveKit.place(w, Ids.EN_SKITTER, DirectiveKit.CORE_X + 5.0, DirectiveKit.CORE_Z, EnemyStore.ST_ATTACKING)
	var walker: int = DirectiveKit.place(w, Ids.EN_SKITTER, DirectiveKit.CORE_X + 1.0, DirectiveKit.CORE_Z)  # not attacking
	for i: int in [first, second, walker]:
		DirectiveKit.set_hp(w, i, TOUGH)
	w.tick = 89
	CoreHooks.step(w)
	assert_float(_taken(first)).is_equal(0.0)
	w.tick = 90
	CoreHooks.step(w)
	assert_float(_taken(first)).is_equal(40.0)  # the closest attacker
	assert_float(_taken(second)).is_equal(0.0)
	assert_float(_taken(walker)).is_equal(0.0)
	DirectiveKit.give(w, &"core_lash", 2)
	w.tick = 54  # stack 3: every 0.9 s
	CoreHooks.step(w)
	assert_float(_taken(first)).is_equal(80.0)
	w.tick = 90
	CoreHooks.step(w)
	assert_float(_taken(first)).is_equal(80.0)  # 90 is no multiple of 54


func test_the_hooks_do_nothing_on_the_legacy_content() -> void:
	var legacy: SimWorld = TestContent.world(3)
	var before: String = legacy.state_hash()
	CoreHooks.on_core_hit(legacy, 0, 10.0, 0.0)
	CoreHooks.on_core_changed(legacy, 600.0, 400.0)
	assert_bool(CoreHooks.allow_defeat(legacy)).is_true()
	CoreHooks.on_wave_cleared(legacy)
	CoreHooks.on_ability(legacy, Ids.AB_EMP)
	CoreHooks.on_emp(legacy)
	CoreHooks.on_shield_end(legacy)
	CoreHooks.step(legacy)
	assert_str(legacy.state_hash()).is_equal(before)

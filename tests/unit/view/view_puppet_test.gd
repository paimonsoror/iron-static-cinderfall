extends GdUnitTestSuite
## W2-E: SimPuppet runs scenarios on the real sim systems and forwards every sim event to `Events`, so the view and the
## HUD see shots, damage, core hits, abilities, turrets, the SMG, reloads and stuck enemies in the sandbox.
## Also DebugArgs: the sandbox flags and the single-argument form capture.ps1 delivers.

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)


func _run(p: SimPuppet, ticks: int) -> void:
	for _t: int in ticks:
		p.step_once()


func test_scenarios_hold_their_crowd() -> void:
	var counts: Dictionary[String, int] = {"hold10": 10, "hold28": 28, "hold50": 50}
	for scenario_name: String in counts:
		var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, scenario_name)
		assert_int(p.world.alive_count()).is_equal(counts[scenario_name])
		assert_bool(p.boss_mode).is_equal(false)
		_run(p, 240)
		assert_int(p.world.alive_count()).is_equal(counts[scenario_name])  # kills are replaced
	var cap: Dictionary[String, Variant] = SimPuppet.parse("hold999", _content.mission.enemy_cap)
	var held: int = cap["hold"]
	assert_int(held).is_equal(_content.mission.enemy_cap)
	var junk: Dictionary[String, Variant] = SimPuppet.parse("nonsense", _content.mission.enemy_cap)
	var junk_hold: int = junk["hold"]
	assert_int(junk_hold).is_equal(50)


func test_fifty_and_boss_have_a_siege_hulk_and_hold10_does_not() -> void:
	var big: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold50")
	assert_int(big.world.boss_store_index()).is_greater_equal(0)
	var small: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold10")
	assert_int(small.world.boss_store_index()).is_equal(-1)
	var boss: SimPuppet = ViewIntegrationKit.puppet(self, _content, "boss")
	assert_bool(boss.boss_mode).is_true()
	assert_int(boss.world.boss_store_index()).is_greater_equal(0)
	assert_int(boss.world.alive_count()).is_equal(SimPuppet.BOSS_ESCORT + 1)
	assert_float(boss.world.core_hp / boss.world.core_max_hp).is_less(0.35)  # the low-core look
	_run(boss, 600)
	assert_int(boss.world.boss_store_index()).is_greater_equal(0)  # the puppet never kills the boss
	var i: int = boss.world.boss_store_index()
	assert_float(boss.world.enemies.hp[i]).is_greater(0.0)


func test_enemies_follow_the_real_flow_field_and_reach_attack_slots() -> void:
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold28")
	_run(p, 900)
	var attacking: int = 0
	var st: EnemyStore = p.world.enemies
	for i: int in st.high_water:
		if st.alive[i] == 1 and st.state[i] == EnemyStore.ST_ATTACKING:
			attacking += 1
			assert_int(st.slot[i]).is_greater_equal(0)  # attackers hold real slots
	assert_int(attacking).is_greater(3)
	assert_int(p.events.count_of(SimEventKind.Id.CORE_HIT)).is_greater(0)


func test_the_script_buys_turrets_and_the_smg_and_fires_abilities_through_real_commands() -> void:
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold28")
	var deployed: Array[int] = []
	var weapons: Array[StringName] = []
	var activated: Array[StringName] = []
	var on_deploy: Callable = func(pad: int) -> void: deployed.append(pad)
	var on_weapon: Callable = func(id: StringName) -> void: weapons.append(id)
	var on_ability: Callable = func(id: StringName) -> void: activated.append(id)
	Events.turret_deployed.connect(on_deploy)
	Events.weapon_changed.connect(on_weapon)
	Events.ability_activated.connect(on_ability)
	var shield_seen: bool = false
	var overdrive_seen: bool = false
	for _t: int in 720:  # twelve seconds: EMP is due at 8 s
		p.step_once()
		shield_seen = shield_seen or p.world.shield_hp > 0.0
		overdrive_seen = overdrive_seen or p.world.abilities.is_active(Ids.AB_OVERDRIVE)
	Events.turret_deployed.disconnect(on_deploy)
	Events.weapon_changed.disconnect(on_weapon)
	Events.ability_activated.disconnect(on_ability)
	assert_array(deployed).contains_exactly([0, 1])
	assert_array(weapons).contains_exactly([&"smg"])
	assert_int(p.world.turrets.active_count()).is_equal(2)
	assert_int(p.world.warden.weapon_index).is_equal(Ids.WEAPONS.find(&"smg"))
	assert_bool(activated.has(&"shield")).is_true()
	assert_bool(activated.has(&"overdrive")).is_true()
	assert_bool(activated.has(&"emp")).is_true()
	assert_bool(shield_seen).is_true()
	assert_bool(overdrive_seen).is_true()


func test_every_effect_event_reaches_the_bus() -> void:
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold28")
	_run(p, 780)
	var needed: Array[int] = [
		SimEventKind.Id.SHOT_FIRED, SimEventKind.Id.ENEMY_DAMAGED, SimEventKind.Id.ENEMY_KILLED,
		SimEventKind.Id.CORE_HIT, SimEventKind.Id.TURRET_DEPLOYED, SimEventKind.Id.WEAPON_CHANGED,
		SimEventKind.Id.ABILITY_ACTIVATED, SimEventKind.Id.ENEMY_STUNNED, SimEventKind.Id.ENEMY_STUCK,
		SimEventKind.Id.SHIELD_CHANGED, SimEventKind.Id.RELOAD_STARTED, SimEventKind.Id.RELOAD_FINISHED,
		SimEventKind.Id.UPGRADE_LEVEL_CHANGED, SimEventKind.Id.SCRAP_CHANGED,
	]
	for kind: int in needed:
		assert_int(p.events.count_of(kind)).is_greater(0)


func test_the_view_reacts_to_the_puppets_effects() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold28")
	view.bind(p.world)
	var tracers: int = 0
	var texts: int = 0
	var shield_dome: bool = false
	for _t: int in 300:
		p.step_once()
		view.render(1.0, SimPuppet.TICK_DT)
		tracers = maxi(tracers, view.vfx_layer.tracer_count())
		texts = maxi(texts, view.vfx_layer.text_count())
		shield_dome = shield_dome or view.vfx_layer.auras().dome_visible()
	assert_int(tracers).is_greater(0)
	assert_int(texts).is_greater(0)
	assert_bool(shield_dome).is_true()
	assert_bool(view.arena_view.pad_is_lit(0)).is_true()


func test_boss_marker_follows_the_hulk_and_hides_without_one() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	var boss: SimPuppet = ViewIntegrationKit.puppet(self, _content, "boss")
	view.bind(boss.world)
	view.render(1.0, 0.016)
	var marker: BossMarker = view.actor_layer.boss_marker
	assert_bool(marker.is_tracking()).is_true()
	var i: int = boss.world.boss_store_index()
	assert_float(marker.position.x).is_equal_approx(boss.world.enemies.x[i], 0.01)
	assert_float(marker.position.z).is_equal_approx(boss.world.enemies.z[i], 0.01)
	var small: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold10")
	view.bind(small.world)
	view.render(1.0, 0.016)
	assert_bool(marker.is_tracking()).is_false()
	assert_bool(marker.visible).is_false()


func test_debug_args_parse_the_sandbox_flags() -> void:
	var a: DebugArgs = DebugArgs.parse(PackedStringArray([
		"--scenario=boss", "--quality=2", "--debug-overlay=flow,slots", "--high-contrast", "--reduced-flash",
		"--hud-step=3", "--debug-perf", "--seed=7",
	]))
	assert_str(a.scenario).is_equal("boss")
	assert_int(a.quality).is_equal(2)
	assert_str(a.debug_overlay).is_equal("flow,slots")
	assert_bool(a.high_contrast).is_true()
	assert_bool(a.reduced_flash).is_true()
	assert_int(a.hud_step).is_equal(3)
	assert_bool(a.debug_perf).is_true()
	assert_int(a.run_seed).is_equal(7)
	var h: DebugArgs = DebugArgs.parse(PackedStringArray(["--scenario=hold28", "--debug-overlay"]))
	assert_int(h.scenario_n).is_equal(28)
	assert_str(h.debug_overlay).is_equal("all")
	assert_int(h.quality).is_equal(-1)
	assert_int(h.hud_step).is_equal(-1)


func test_one_argument_carrying_several_flags_is_split() -> void:
	# `capture.ps1 -Scene "res://src/debug/view_sandbox.tscn --scenario=boss --quality=0"` reaches Godot as ONE argument
	var a: DebugArgs = DebugArgs.parse(PackedStringArray([
		"--capture-scene=res://src/debug/view_sandbox.tscn --scenario=boss --quality=0", "--capture-out=C:/x/y.png",
	]))
	assert_str(a.capture_scene).is_equal("res://src/debug/view_sandbox.tscn")
	assert_str(a.scenario).is_equal("boss")
	assert_int(a.quality).is_equal(0)
	assert_bool(a.wants_capture()).is_true()

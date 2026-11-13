class_name DebugStart
extends RefCounted
## The debug starts of ARCH 11 (`--wave=<n>`, `--scenario=boss:<id>`): a run that begins at a later wave with a scripted
## build, or at the boss wave of a chosen boss. SimWorld._init calls `apply` after the plan is built; it does nothing
## unless SimConfig.debug_start_wave or debug_boss is set, so a normal run never comes here.
##
## `debug_boss` is a BossDef id (the boss replaces the plan's pick for its act and the run starts at that act's boss
## wave) or a Node 9 variant id of `hulk_variants` (the Siege Hulk with that variant). `debug_start_wave` n > 1 counts
## waves 1 to n - 1 as cleared: the first wave played is wave n, after the usual PREPARING countdown.
## The scripted build stands in for the drafts and crates of the skipped waves: one base-pool directive per skipped wave
## (BUILD, in order; a directive the content lacks or that is at its maximum is passed over) and a second weapon from
## wave 3 on. It draws from no random stream. Such a run is a debug run: the game layer records nothing of it in the
## Archive (GameRewards.launch_of).

const BUILD: Array[StringName] = [
	&"hot_loads", &"turret_deploy", &"cyclic_tuning", &"reinforced_cage", &"penetrator_cores", &"turret_deploy", &"hot_loads",
	&"emp_capacitor", &"cyclic_tuning", &"incendiary_tips", &"hot_loads", &"penetrator_cores", &"cyclic_tuning",
	&"reinforced_cage",
]
const SECOND_WEAPON_FROM_WAVE: int = 3
const ACT_ONE_WEAPON: int = Ids.WP_SMG
const LATER_WEAPON: int = Ids.WP_ASSAULT_RIFLE


static func apply(world: SimWorld) -> void:
	if world.plan == null:
		return
	var start: int = world.config.debug_start_wave
	if world.config.debug_boss != &"":
		start = maxi(start, force_boss(world, world.config.debug_boss))
	start = mini(start, world.plan.wave_count())
	if start <= 1:
		return
	world.wave = start - 1
	world.waves_completed = start - 1
	for n: int in start - 1:
		var index: int = world.content.directive_index(BUILD[n % BUILD.size()])
		var _granted: bool = DraftSystem.grant_stack(world, index)
	if start >= SECOND_WEAPON_FROM_WAVE and world.arsenal.slot_weapon[1] < 0:
		var first: PlannedWave = world.plan.wave(start)
		var weapon_index: int = LATER_WEAPON if first != null and first.act > 1 else ACT_ONE_WEAPON
		if weapon_index < world.content.weapons.size():
			ArsenalSystem.give_weapon(world, 1, weapon_index)


## Makes `boss_id` (a BossDef id or a Node 9 variant id) the boss of its act and rebuilds that boss wave. Returns the
## number of the boss wave, or 0 when the id is unknown or its act has no boss wave.
static func force_boss(world: SimWorld, boss_id: StringName) -> int:
	var content: ContentSet = world.content
	var run: RunDef = content.run
	var wanted: StringName = boss_id
	var variant: int = run.hulk_variants.find(boss_id)
	if variant >= 0:
		wanted = Ids.ENEMIES[Ids.EN_HULK]
	for b: BossDef in content.bosses:
		if b.id != wanted:
			continue
		for slot: WaveSlotDef in run.waves:
			if slot.kind == WaveSlotDef.Kind.BOSS and slot.act == b.pool_act:
				if variant >= 0:
					world.plan.boss_variant = variant
				RunPlanSystem.set_boss(world, slot, b.enemy_index)
				return slot.index
	return 0

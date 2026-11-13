class_name ShotHooks
extends RefCounted
## The shot-side hook points of directives (CONTENT 3.1, 3.2): one function per hook, called by ArsenalSystem, the fire
## files, DamageResolver.warden_hit and TurretSystem. A directive is found by its id in `data/directives.json`; a content
## that does not list it never triggers it (stacks are 0). The numbers below are those of CONTENT 3; the ops grammar has
## no place for them, so they live here as named constants.
##
## on_warden_shot   shock_rounds (every 7 - stacks shots: the shot's target arcs on to 2 enemies for 50%)
## on_warden_hit    incendiary_tips (burn)
## on_warden_kill   ricochet (a hitscan kill continues to `stacks` more enemies within 3 m for 60%), kill_chain (+4% fire
##                  rate per kill for 2 s, up to +40%); the kill blast of unstable_munitions is DeathHooks (every Warden kill)
## reload_jam_ticks unstable_munitions (5% of reloads jam for 1.5 s)
## on_turret_shot   arc_pylons (every 5 - stacks turret shots chain to 2 enemies for 60%)
## on_turret_hit    flak_heads (the hit splashes 1.2 m for 40%, 60% at stack 2)
## The off-hand fire of twin_link is ArsenalFire's. mine_layer is no shot hook (a timer of the turret, HazardSystem's mines).
## Hits of these hooks are area hits (DamageResolver.F_AREA): they run no hooks themselves, so nothing recurses.
##
## State: kill_chain keeps its stack count and its timer in the upper bits of ArsenalState.shots_since_proc (bits 4..7
## and 8..15); the low 4 bits count the shots of the pistol's level-3 perk. ArsenalState has no field of its own for it.

const D_SHOCK_ROUNDS: StringName = &"shock_rounds"
const D_RICOCHET: StringName = &"ricochet"
const D_KILL_CHAIN: StringName = &"kill_chain"
const D_UNSTABLE: StringName = &"unstable_munitions"
const D_ARC_PYLONS: StringName = &"arc_pylons"
const D_FLAK_HEADS: StringName = &"flak_heads"
const D_TWIN_LINK: StringName = &"twin_link"

const SHOCK_PERIOD_BASE: int = 7  ## every 6th shot at stack 1, 5th at 2, 4th at 3
const SHOCK_MAX_STACKS: int = 3
const SHOCK_JUMPS: int = 2
const SHOCK_REACH_M: float = 2.5
const SHOCK_FRAC: float = 0.5
const RICOCHET_REACH_M: float = 3.0
const RICOCHET_FRAC: float = 0.6
const RICOCHET_MAX_STACKS: int = 2
const KILL_CHAIN_MAX: int = 10
const KILL_CHAIN_TICKS: int = 120
const KILL_CHAIN_STEP_MILLI: int = 40  ## +4% of the fire rate per stack
const JAM_CHANCE: float = 0.05
const JAM_TICKS: int = 90
const PYLON_PERIOD_BASE: int = 5  ## every 4th turret shot at stack 1, 3rd at 2
const PYLON_MAX_STACKS: int = 2
const PYLON_JUMPS: int = 2
const PYLON_REACH_M: float = 2.5
const PYLON_FRAC: float = 0.6
const FLAK_RADIUS_M: float = 1.2
const FLAK_FRAC: float = 0.4
const FLAK_FRAC_STEP: float = 0.2
const FLAK_MAX_STACKS: int = 2

const PISTOL_BITS: int = 15  ## mask of the pistol's shot counter
const KILL_STACK_SHIFT: int = 4
const KILL_TICKS_SHIFT: int = 8

## The slot whose weapon is firing, set by ArsenalFire around a shot; -1 outside a shot (the active slot then counts).
static var shooter_slot: int = -1


## How many stacks of the directive `id` the build holds (0 on legacy content and for an id the content does not list).
static func stacks(world: SimWorld, id: StringName) -> int:
	if world.content.run == null:
		return 0
	return world.draft.stacks_of(world.content.directive_index(id))


## shock_rounds, after every shot of the active weapon: the shot's target arcs on.
static func on_warden_shot(world: SimWorld, slot: int, _target_index: int) -> void:
	var s: int = stacks(world, D_SHOCK_ROUNDS)
	if s <= 0:
		return
	var w: WardenState = world.warden
	if w.shots_fired % (SHOCK_PERIOD_BASE - mini(s, SHOCK_MAX_STACKS)) != 0:
		return
	var def: WeaponDef = ArsenalSystem.effective_of(world, slot)
	var level: int = world.arsenal.slot_level[slot]
	var reach: float = SHOCK_REACH_M * world.mods.area_mul
	var from_id: int = w.target_id
	for i: int in FireTargets.chain_victims(world, w.aim_x, w.aim_z, from_id, SHOCK_JUMPS, reach):
		var to_id: int = world.enemies.id[i]
		world.events.push(SimEventKind.Id.CHAIN_ARC, from_id, to_id)
		from_id = to_id
		var amount: float = DamageResolver.warden_amount(world, i, def, level) * SHOCK_FRAC
		var _dealt: float = DamageResolver.hit_ex(
			world, i, amount, DamageResolver.F_AREA | DamageResolver.weapon_flags(def), DamageSource.Id.WARDEN
		)


## incendiary_tips: `dealt` damage was applied to a living enemy.
static func on_warden_hit(world: SimWorld, target_index: int, _dealt: float) -> void:
	StatusSystem.ignite(world, target_index)


## ricochet, kill_chain: the Warden killed an enemy at (x, z) with a direct hit.
static func on_warden_kill(world: SimWorld, x: float, z: float) -> void:
	if world.content.run == null:
		return
	var ricochet: int = stacks(world, D_RICOCHET)
	if ricochet > 0:
		_ricochet(world, x, z, mini(ricochet, RICOCHET_MAX_STACKS))
	if stacks(world, D_KILL_CHAIN) > 0:
		var a: ArsenalState = world.arsenal
		_set_kill_chain(a, mini(KILL_CHAIN_MAX, kill_chain_stacks(a) + 1), KILL_CHAIN_TICKS)


## arc_pylons: the turret on `pad` has fired (its tally in CombatState.shots_by_source already counts the shot).
static func on_turret_shot(world: SimWorld, pad: int, _target_index: int) -> void:
	var s: int = stacks(world, D_ARC_PYLONS)
	if s <= 0:
		return
	var source: int = DamageSource.Id.TURRET_0 + pad
	if world.combat.shots_by_source[source] % (PYLON_PERIOD_BASE - mini(s, PYLON_MAX_STACKS)) != 0:
		return
	var t: TurretStore = world.turrets
	var from_id: int = t.target_id[pad]
	var amount: float = turret_damage(world) * PYLON_FRAC
	var reach: float = PYLON_REACH_M * world.mods.area_mul
	for i: int in FireTargets.chain_victims(world, t.aim_x[pad], t.aim_z[pad], from_id, PYLON_JUMPS, reach):
		var to_id: int = world.enemies.id[i]
		world.events.push(SimEventKind.Id.CHAIN_ARC, from_id, to_id)
		from_id = to_id
		var _dealt: float = DamageResolver.hit_ex(world, i, amount, DamageResolver.F_AREA, source)


## flak_heads: the shot of the turret on `pad` hit its target (which may be dead by now; the turret still aims at the
## place it stood).
static func on_turret_hit(world: SimWorld, pad: int, _target_index: int, _dealt: float) -> void:
	var s: int = stacks(world, D_FLAK_HEADS)
	if s <= 0:
		return
	var t: TurretStore = world.turrets
	var frac: float = FLAK_FRAC + FLAK_FRAC_STEP * float(mini(s, FLAK_MAX_STACKS) - 1)
	var amount: float = turret_damage(world) * frac
	var victims: PackedInt32Array = PackedInt32Array()
	var _n: int = AreaDamage.query(world, t.aim_x[pad], t.aim_z[pad], FLAK_RADIUS_M * world.mods.area_mul, victims)
	for i: int in victims:
		if world.enemies.id[i] != t.target_id[pad]:
			var _splash: float = DamageResolver.hit_ex(world, i, amount, DamageResolver.F_AREA, DamageSource.Id.TURRET_0 + pad)


## The damage of one turret shot before armor: the turret's own value x ModState.t_dmg_mul.
static func turret_damage(world: SimWorld) -> float:
	return world.content.upgrades[Ids.UP_AUTO_TURRET].turret_damage * world.mods.t_dmg_mul


## unstable_munitions: extra reload ticks when this reload jams (5% of reloads; the `proc` stream), else 0.
static func reload_jam_ticks(world: SimWorld) -> int:
	if stacks(world, D_UNSTABLE) > 0 and world.rng.stream(&"proc").randf() < JAM_CHANCE:
		return JAM_TICKS
	return 0


# --- kill_chain and the pistol counter (see the header for the layout of ArsenalState.shots_since_proc) ---


static func kill_chain_stacks(a: ArsenalState) -> int:
	return (a.shots_since_proc >> KILL_STACK_SHIFT) & 15


static func kill_chain_ticks(a: ArsenalState) -> int:
	return (a.shots_since_proc >> KILL_TICKS_SHIFT) & 255


## The fire rate multiplier of the kill chain in thousandths (1000 = none).
static func kill_chain_mult_milli(a: ArsenalState) -> int:
	return 1000 + KILL_CHAIN_STEP_MILLI * kill_chain_stacks(a)


## One tick of the kill chain's timer; the stacks drop when it runs out.
static func kill_chain_tick(a: ArsenalState) -> void:
	var left: int = kill_chain_ticks(a)
	if left <= 0:
		return
	left -= 1
	_set_kill_chain(a, kill_chain_stacks(a) if left > 0 else 0, left)


## True on every `every`-th call: the pistol's level-3 perk (a guaranteed x3 hit on every 6th shot).
static func pistol_crit_due(a: ArsenalState, every: int) -> bool:
	if every <= 0 or every > PISTOL_BITS:
		return false
	var n: int = (a.shots_since_proc & PISTOL_BITS) + 1
	if n >= every:
		a.shots_since_proc &= ~PISTOL_BITS
		return true
	a.shots_since_proc = (a.shots_since_proc & ~PISTOL_BITS) | n
	return false


static func _set_kill_chain(a: ArsenalState, stack_count: int, ticks: int) -> void:
	a.shots_since_proc = (a.shots_since_proc & PISTOL_BITS) | (stack_count << KILL_STACK_SHIFT) | (ticks << KILL_TICKS_SHIFT)


## ricochet: the killing hitscan shot goes on to the nearest enemies within 3 m, each hit for 60% of that shot.
static func _ricochet(world: SimWorld, x: float, z: float, jumps: int) -> void:
	var slot: int = shooter_slot if shooter_slot >= 0 else world.arsenal.active
	var def: WeaponDef = ArsenalSystem.effective_of(world, slot)
	if def.kind != WeaponDef.Kind.HITSCAN:
		return
	var level: int = world.arsenal.slot_level[slot]
	for i: int in FireTargets.chain_victims(world, x, z, 0, jumps, RICOCHET_REACH_M):
		var amount: float = DamageResolver.warden_amount(world, i, def, level) * RICOCHET_FRAC
		var _dealt: float = DamageResolver.hit_ex(
			world, i, amount, DamageResolver.F_AREA | DamageResolver.weapon_flags(def), DamageSource.Id.WARDEN
		)

class_name BossEffects
extends RefCounted
## Everything a boss script does to the world outside BossState, in one place (VARIETY_SPEC 6, 13.2 "boss motion
## hooks"). Where the owning system has a public function the effect goes through it (spawn_enemy, SpawnSystem.enqueue,
## kill_enemy, DamageResolver.heal, EventSystem.take_turrets_offline, ArsenalFire.dump_magazine). The one exception,
## recorded in the ownership table of ARCH 6.6: this class is the writer of the boss's own body and of its parts in
## EnemyStore (`state`, `attack_cd`, `x`, `z`, `face_*`, `path_dist`, `stun_ticks`) while a boss script drives them;
## MovementSystem, CoreAttackSystem and AbilitySystem own these fields for every other enemy and leave a parked boss
## body alone.
## Every function runs at tick step 13, after movement, weapons and core attacks of the tick.

## Attack timer of a parked part that never hits the core (CoreAttackSystem counts one off per tick).
const HOLD_ATTACK_CD: int = 1 << 20
const MIN_MOVE_M: float = 0.000001


## Sends one body of `type_index` in at (x, z), clamped into the yard. When a cap is full the body joins the spawn
## queue instead (VARIETY_SPEC 5.5: nothing is dropped). Returns the store index, or -1 when it was queued.
static func send(world: SimWorld, type_index: int, x: float, z: float) -> int:
	var i: int = send_now(world, type_index, x, z)
	if i < 0:
		var nav: NavState = world.nav
		SpawnSystem.enqueue(
			world, type_index, clampf(x, nav.bound_min_x, nav.bound_max_x), clampf(z, nav.bound_min_z, nav.bound_max_z)
		)
	return i


## Like `send`, but a body that finds no room is not queued: the caller keeps it owed and tries again (parts and
## escorts, whose ids the script must know). Returns the store index or -1.
static func send_now(world: SimWorld, type_index: int, x: float, z: float) -> int:
	var nav: NavState = world.nav
	var es: EnemyStore = world.enemies
	var px: float = clampf(x, nav.bound_min_x, nav.bound_max_x)
	var pz: float = clampf(z, nav.bound_min_z, nav.bound_max_z)
	var i: int = world.spawn_enemy(type_index, px, pz)
	if i < 0:
		return -1
	es.path_dist[i] = nav.path_dist_of(es, i)
	nav.track(i, es.id[i], es.path_dist[i])
	return i


## Removes a boss part with its boss (no Scrap, not a kill of the player's side).
static func remove(world: SimWorld, enemy_index: int) -> void:
	world.kill_enemy(enemy_index, DeathHooks.SOURCE_SELF)


## Parks a body where it stands: it counts as attacking (no movement, no slot, no stuck recovery) with its attack
## timer at `attack_cd`, and faces the core. Owner of these fields for other enemies: MovementSystem (`_capture`).
static func park(world: SimWorld, enemy_index: int, attack_cd: int) -> void:
	var es: EnemyStore = world.enemies
	var arena: ArenaDef = world.content.arena
	world.nav.slots.release(world, enemy_index)
	es.state[enemy_index] = EnemyStore.ST_ATTACKING
	es.attack_cd[enemy_index] = attack_cd
	es.path_dist[enemy_index] = 0.0
	var fx: float = arena.core_x - es.x[enemy_index]
	var fz: float = arena.core_z - es.z[enemy_index]
	var f: float = sqrt(fx * fx + fz * fz)
	if f > MIN_MOVE_M:
		es.face_x[enemy_index] = fx / f
		es.face_z[enemy_index] = fz / f


## Puts a parked part at (x, z) (an orbit) and keeps it from ever hitting the core. Owner: MovementSystem.
static func carry(world: SimWorld, enemy_index: int, x: float, z: float) -> void:
	var es: EnemyStore = world.enemies
	var nav: NavState = world.nav
	es.x[enemy_index] = clampf(x, nav.bound_min_x, nav.bound_max_x)
	es.z[enemy_index] = clampf(z, nav.bound_min_z, nav.bound_max_z)
	es.attack_cd[enemy_index] = HOLD_ATTACK_CD


## Lets a walking body cover `mult` times the ground it covered this tick (a speed multiplier applied after
## MovementSystem): the extra step follows this tick's own displacement, stops short of its slot, the cage, a prop
## and the yard's edge. Nothing happens to a body that stands, attacks or is stunned. Owner: MovementSystem.
static func advance(world: SimWorld, enemy_index: int, mult: float) -> void:
	var es: EnemyStore = world.enemies
	if mult <= 1.0 or es.state[enemy_index] == EnemyStore.ST_ATTACKING or es.stun_ticks[enemy_index] > 0:
		return
	var dx: float = es.x[enemy_index] - es.prev_x[enemy_index]
	var dz: float = es.z[enemy_index] - es.prev_z[enemy_index]
	var moved: float = sqrt(dx * dx + dz * dz)
	if moved < MIN_MOVE_M:
		return
	var nav: NavState = world.nav
	var arena: ArenaDef = world.content.arena
	var type_index: int = es.type[enemy_index]
	var extra: float = moved * (mult - 1.0)
	if es.state[enemy_index] == EnemyStore.ST_SEEK_SLOT and es.slot[enemy_index] >= 0:
		var sx: float = nav.slots.pos_x[es.slot[enemy_index]] - es.x[enemy_index]
		var sz: float = nav.slots.pos_z[es.slot[enemy_index]] - es.z[enemy_index]
		extra = minf(extra, sqrt(sx * sx + sz * sz))
	var qx: float = clampf(es.x[enemy_index] + dx / moved * extra, nav.bound_min_x, nav.bound_max_x)
	var qz: float = clampf(es.z[enemy_index] + dz / moved * extra, nav.bound_min_z, nav.bound_max_z)
	var clear: float = nav.t_clear[type_index]
	var cx: float = qx - arena.core_x
	var cz: float = qz - arena.core_z
	var keep: float = arena.core_radius + clear
	if cx * cx + cz * cz < keep * keep:
		return
	if NavGeometry.inside_any(arena.obstacles, qx, qz, clear):
		return
	es.x[enemy_index] = qx
	es.z[enemy_index] = qz


## A stun that began this tick lasts `total_ticks` in all (AbilitySystem has already counted this tick's one off).
## Never shortens a stun. Owner: AbilitySystem.
static func extend_stun(world: SimWorld, enemy_index: int, total_ticks: int) -> void:
	var es: EnemyStore = world.enemies
	es.stun_ticks[enemy_index] = maxi(es.stun_ticks[enemy_index], total_ticks - 1)


## The attack timer of an attacking body never waits longer than `period` ticks (an enraged boss). Owner:
## CoreAttackSystem.
static func cap_attack_cd(world: SimWorld, enemy_index: int, period: int) -> void:
	var es: EnemyStore = world.enemies
	if es.state[enemy_index] == EnemyStore.ST_ATTACKING and es.attack_cd[enemy_index] > period:
		es.attack_cd[enemy_index] = maxi(1, period)


## Restarts the attack timer of an attacking body (a cancelled shot). Owner: CoreAttackSystem.
static func restart_attack(world: SimWorld, enemy_index: int, period: int) -> void:
	world.enemies.attack_cd[enemy_index] = maxi(1, period)


## Turrets go offline for `ticks` (never shortens an outage that already runs). Done by the owner (EventSystem).
static func turrets_offline(world: SimWorld, ticks: int) -> void:
	EventSystem.take_turrets_offline(world, ticks)


## Empties the magazine of the weapon in the Warden's hands; the arsenal starts the reload on its next step. A heat
## weapon has no magazine and keeps firing. True when rounds were lost. Done by the owner (ArsenalFire.dump_magazine).
static func dump_magazine(world: SimWorld) -> bool:
	return ArsenalFire.dump_magazine(world)


## Repairs the boss by `amount` hit points (DamageResolver stays the only writer of enemies.hp).
static func heal(world: SimWorld, enemy_index: int, amount: float) -> float:
	return DamageResolver.heal(world, enemy_index, amount)

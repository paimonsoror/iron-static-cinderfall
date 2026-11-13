class_name EventPush
extends RefCounted
## Knockback for events (Core Vent 2 m, Runaway Freight 1.5 m). An event moves the enemy's centre directly: MovementSystem
## has no push of its own, and the enemy walks on from where it lands on the next tick. Bosses are never pushed.
## An attacker that is thrown back keeps its attack slot, goes back to ST_SEEK_SLOT (the movement system walks it to the
## slot again) and starts its attack timer anew when it arrives; that is the "attack timers reset" of the Core Vent.


## Moves enemy `index` `meters` straight away from (from_x, from_z), inside the arena. A centre exactly on the point
## goes along +x. Returns false when nothing moved (a boss, a dead slot, no room).
static func away(world: SimWorld, index: int, from_x: float, from_z: float, meters: float) -> bool:
	var store: EnemyStore = world.enemies
	if meters <= 0.0 or index < 0 or index >= store.capacity or store.alive[index] == 0:
		return false
	if world.content.enemies[store.type[index]].is_boss:
		return false
	var dx: float = store.x[index] - from_x
	var dz: float = store.z[index] - from_z
	var d: float = sqrt(dx * dx + dz * dz)
	var ux: float = 1.0
	var uz: float = 0.0
	if d > 0.000001:
		ux = dx / d
		uz = dz / d
	var nav: NavState = world.nav
	var nx: float = clampf(store.x[index] + ux * meters, nav.bound_min_x, nav.bound_max_x)
	var nz: float = clampf(store.z[index] + uz * meters, nav.bound_min_z, nav.bound_max_z)
	if nx == store.x[index] and nz == store.z[index]:
		return false
	store.x[index] = nx
	store.z[index] = nz
	if store.state[index] == EnemyStore.ST_ATTACKING:
		store.state[index] = EnemyStore.ST_SEEK_SLOT
		store.attack_cd[index] = nav.t_period[store.type[index]]
		nav.grace[index] = 0
	return true

class_name StuckRecovery
extends RefCounted
## Stuck detection and deterministic recovery for MovementSystem (ARCH 6.6, GDD 7). An enemy that is moving or
## seeking its slot and closes less than `stuck_min_progress_m` of path distance in `stuck_ticks` gets ENEMY_STUCK
## and stops being separated for GRACE_TICKS. If it is still no closer after that, it is moved to the nearest free
## cell center with a lower flow cost (or onto its slot when it is already seeking one). Enemies are never removed.

const GRACE_TICKS: int = 120
const SEARCH_CELLS: int = 6


## The progress window of enemy `i` has run `stuck_ticks` ticks: restart it, and declare the enemy stuck when
## it closed too little distance. `path` is its current path distance.
static func window_end(world: SimWorld, i: int, path: float) -> void:
	var nav: NavState = world.nav
	var progress: float = nav.stuck_ref[i] - path
	nav.stuck_timer[i] = 0
	nav.stuck_ref[i] = path
	if progress >= world.content.mission.stuck_min_progress_m:
		return
	nav.recoveries[i] += 1
	nav.sep_off[i] = GRACE_TICKS
	nav.grace[i] = 1
	nav.c_ttl[i] = 0
	world.stats.stuck_recoveries += 1
	world.events.push(SimEventKind.Id.ENEMY_STUCK, world.enemies.id[i], nav.recoveries[i])


## `elapsed` ticks of the separation-free period of enemy `i` have passed. When it ends and the enemy is still no
## closer than at the stuck event, writes the forced position into the store and returns the path distance there;
## otherwise returns `path` unchanged.
static func grace_tick(world: SimWorld, i: int, path: float, elapsed: int) -> float:
	var nav: NavState = world.nav
	nav.sep_off[i] = maxi(0, nav.sep_off[i] - elapsed)
	if nav.sep_off[i] > 0:
		return path
	nav.stuck_timer[i] = 0
	if nav.grace[i] == 0:
		nav.stuck_ref[i] = path
		return path
	nav.grace[i] = 0
	var result: float = path
	if nav.stuck_ref[i] - path < world.content.mission.stuck_min_progress_m:
		result = force_move(world, i, path)
	nav.stuck_ref[i] = result
	return result


## Moves enemy `i` (writes the store position) and returns its path distance at the new spot, or `path` if no move exists.
static func force_move(world: SimWorld, i: int, path: float) -> float:
	var es: EnemyStore = world.enemies
	var nav: NavState = world.nav
	if es.state[i] == EnemyStore.ST_SEEK_SLOT and es.slot[i] >= 0:
		var target: Vector2 = nav.slots.slot_position(es.slot[i])
		es.x[i] = target.x
		es.z[i] = target.y
		nav.c_ttl[i] = 0
		return 0.0
	var flow: FlowField = nav.flow
	var g: ArenaGrid = flow.grid
	var here: int = g.cell_of(es.x[i], es.z[i])
	var here_cost: float = flow.cost[here]
	if is_inf(here_cost):
		## Pressed into a prop's inflated cells: measure progress against the last known path distance instead.
		here_cost = es.path_dist[i] - nav.tail_m
	var cz0: int = floori(float(here) / float(g.cols))
	var cx0: int = here - cz0 * g.cols
	var obstacles: Array[ObstacleDef] = world.content.arena.obstacles
	var clear: float = nav.t_clear[es.type[i]]
	var in_blocked_cell: bool = is_inf(flow.cost[here])
	var best: int = -1
	var best_d2: float = INF
	for dz: int in range(-SEARCH_CELLS, SEARCH_CELLS + 1):
		var cz: int = cz0 + dz
		if cz < 0 or cz >= g.rows:
			continue
		for dx: int in range(-SEARCH_CELLS, SEARCH_CELLS + 1):
			var cx: int = cx0 + dx
			if cx < 0 or cx >= g.cols:
				continue
			var c: int = cz * g.cols + cx
			if g.blocked[c] == 1 or is_inf(flow.cost[c]):
				continue
			if flow.cost[c] >= here_cost - 0.01 and not (in_blocked_cell and here_cost <= 0.0):
				continue
			var p: Vector2 = g.cell_center(c)
			if NavGeometry.inside_any(obstacles, p.x, p.y, clear):
				continue
			var d2: float = (p.x - es.x[i]) * (p.x - es.x[i]) + (p.y - es.z[i]) * (p.y - es.z[i])
			if d2 < best_d2:
				best_d2 = d2
				best = c
	if best < 0:
		return path
	var spot: Vector2 = g.cell_center(best)
	es.x[i] = spot.x
	es.z[i] = spot.y
	nav.c_ttl[i] = 0
	return flow.cost[best] + nav.tail_m

class_name RailLines
extends RefCounted
## The two rail lines of Runaway Freight (VARIETY_SPEC 13.6, GDD 12.3: "kept low-contrast"): for every line of `arena.json` (`rail_lines`, a
## constant z) two steel rails and a row of dark sleepers, all FLAT quads a hair above the ground, so a line reads as a faint mark across the
## yard and never competes with the swarm. They run past the playable rectangle on both sides (the car comes from beyond the screen). The
## lane the telegraph draws over them (`FxTelegraph.lane`) is wider, so the rail is always inside it. Palette materials only: `steel_grey`
## rails (the lightest thing here, still a step above the concrete) on `dark_frame` sleepers. The legacy arena has no rail line: `build`
## returns null and the yard is as it was.

const Y_SLEEPER: float = 0.02
const Y_RAIL: float = 0.026
const RAIL_WIDTH_M: float = 0.11
const GAUGE_HALF_M: float = 0.62
const SLEEPER_LENGTH_M: float = 1.5
const SLEEPER_WIDTH_M: float = 0.28
const SLEEPER_PITCH_M: float = 0.85
const OVERRUN_M: float = 14.0  ## beyond the playable rectangle on each side


## One merged mesh for all the lines, or null when the arena has none.
static func build(arena: ArenaDef) -> ArrayMesh:
	if arena.rail_z.is_empty():
		return null
	var mb: MeshBuilder = MeshKit.begin()
	var x0: float = arena.min_x - OVERRUN_M
	var x1: float = arena.max_x + OVERRUN_M
	for k: int in arena.rail_z.size():
		var z: float = arena.rail_z[k]
		var length: float = x1 - x0
		var mid: float = (x0 + x1) * 0.5
		for side: float in [-1.0, 1.0]:
			mb.quad(Vector2(length, RAIL_WIDTH_M), Transform3D(Basis.IDENTITY, Vector3(mid, Y_RAIL, z + side * GAUGE_HALF_M)), &"steel_grey")
		var n: int = floori(length / SLEEPER_PITCH_M)
		for s: int in n:
			var x: float = x0 + (float(s) + 0.5) * SLEEPER_PITCH_M
			mb.quad(Vector2(SLEEPER_WIDTH_M, SLEEPER_LENGTH_M), Transform3D(Basis.IDENTITY, Vector3(x, Y_SLEEPER, z)), &"dark_frame")
	return mb.build()


## The z of the rail line nearest to `z` (the line a freight that was called at `z` runs on); `z` itself when the arena has none.
static func nearest_z(arena: ArenaDef, z: float) -> float:
	var best: float = z
	var best_d: float = INF
	for k: int in arena.rail_z.size():
		var d: float = absf(arena.rail_z[k] - z)
		if d < best_d:
			best_d = d
			best = arena.rail_z[k]
	return best

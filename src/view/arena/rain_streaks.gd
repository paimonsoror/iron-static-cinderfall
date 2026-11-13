class_name RainStreaks
extends RefCounted
## The mesh of the yard's rain (ARCH 8; split out of ArenaView so the view stays under its line limit): `STREAKS` thin streaks leaning 7
## degrees, each drawn twice one `period` apart so a scroll of one period wraps without a seam.

const STREAKS: int = 90


static func build(arena: ArenaDef, rng: RandomNumberGenerator, period: float) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var lean: Basis = Basis(Vector3.BACK, deg_to_rad(7.0)) * Basis(Vector3.RIGHT, PI * 0.5)
	var lo: Vector2 = Vector2(arena.min_x - 12.0, arena.min_z - 10.0)
	var hi: Vector2 = Vector2(arena.max_x + 12.0, arena.max_z + 8.0)
	for i: int in STREAKS:
		var x: float = rng.randf_range(lo.x, hi.x)
		var z: float = rng.randf_range(lo.y, hi.y)
		var y: float = rng.randf_range(0.0, period)
		var streak_len: float = rng.randf_range(0.9, 1.6)
		for copy: int in 2:
			var at: Vector3 = Vector3(x, y + period * float(copy), z)
			mb.quad(Vector2(0.022, streak_len), Transform3D(lean, at), &"rain")
	return mb.build()

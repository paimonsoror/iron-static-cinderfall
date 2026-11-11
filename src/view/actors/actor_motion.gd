class_name ActorMotion
extends RefCounted
## Procedural motion of the enemy archetypes (ARCH 8: no AnimationTree). Pure math: `pose` returns the local
## transform of the enemy MeshInstance3D (feet at the origin, forward -Z) from a per-actor gait clock `t`.

enum Mode { MOVE, ATTACK, STUN }

## Stomp cycle of the Siege Hulk in rad/s; one footfall per half cycle (PI radians).
const HULK_STEP_RATE: float = 2.4
## Seconds a Siege Hulk takes to collapse after it is killed.
const HULK_COLLAPSE_S: float = 1.5


static func pose(kind: int, t: float, mode: int) -> Transform3D:
	var y: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	var yaw: float = 0.0
	var fwd: float = 0.0
	match kind:
		Ids.EN_SKITTER:
			# scuttle bob and a lateral weave lean
			match mode:
				Mode.MOVE:
					y = absf(sin(t * 13.0)) * 0.05
					roll = sin(t * 6.5) * 0.12
					yaw = sin(t * 6.5 + 0.6) * 0.1
				Mode.ATTACK:
					var jab: float = maxf(0.0, sin(t * 9.0))
					fwd = -0.14 * jab
					pitch = -0.1 * jab
					yaw = sin(t * 4.0) * 0.08
				_:
					roll = sin(t * 35.0) * 0.04
		Ids.EN_HOLLOW:
			# slow stride bob, attack arm swing as a forward lunge
			match mode:
				Mode.MOVE:
					y = absf(sin(t * 4.0)) * 0.05
					roll = sin(t * 4.0) * 0.04
					pitch = -0.03
				Mode.ATTACK:
					var swing: float = maxf(0.0, sin(t * 5.0))
					pitch = -0.3 * swing
					fwd = -0.12 * swing
					yaw = sin(t * 2.5) * 0.05
				_:
					pitch = 0.06
					roll = sin(t * 30.0) * 0.03
		Ids.EN_RUSHER:
			# fast bob, forward lean
			match mode:
				Mode.MOVE:
					y = absf(sin(t * 18.0)) * 0.06
					pitch = -0.08 + sin(t * 18.0) * 0.03
					roll = sin(t * 9.0) * 0.05
				Mode.ATTACK:
					var lunge: float = maxf(0.0, sin(t * 13.0))
					yaw = sin(t * 26.0) * 0.12
					fwd = -0.1 * lunge
					pitch = -0.12 * lunge
				_:
					roll = sin(t * 40.0) * 0.06
					pitch = 0.05
		Ids.EN_HULK:
			# heavy stomp: the body rises between steps and thumps down at each footfall
			match mode:
				Mode.MOVE:
					var s: float = absf(sin(t * HULK_STEP_RATE))
					y = 0.12 * s
					roll = sin(t * HULK_STEP_RATE) * 0.06
					pitch = -0.03 * cos(t * HULK_STEP_RATE * 2.0)
				Mode.ATTACK:
					var slam: float = maxf(0.0, sin(t * 2.6))
					pitch = -0.14 * slam * slam
					y = -0.05 * slam
				_:
					pitch = 0.2 + sin(t * 2.0) * 0.03
					roll = sin(t * 5.0) * 0.05
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3(0.0, y, fwd))


## Collapse pose for u in 0..1 (topple forward, sink, squash). Used by the Siege Hulk after its death.
static func dying_pose(u: float) -> Transform3D:
	var k: float = clampf(u, 0.0, 1.0)
	var basis: Basis = Basis.from_euler(Vector3(-0.6 * k * k, 0.0, 0.08 * k))
	basis = basis.scaled(Vector3(1.0, 1.0 - 0.4 * k, 1.0))
	return Transform3D(basis, Vector3(0.0, -0.9 * k * k, 0.0))


## Number of footfalls completed at gait time `t` for the Siege Hulk; -1 for the other archetypes.
static func step_index(kind: int, t: float) -> int:
	if kind != Ids.EN_HULK:
		return -1
	return floori(t * HULK_STEP_RATE / PI)


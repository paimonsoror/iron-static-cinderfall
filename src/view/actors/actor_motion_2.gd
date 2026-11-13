class_name ActorMotion2
extends RefCounted
## Procedural motion of the variety machines of V4-R (spitter, splitter, shieldbearer, reclaimer, jammer, borer, ward pylon and the
## four boss nodes). Same contract as `ActorMotion.pose`: pure math, the local transform of the enemy's MeshInstance3D (feet at the
## origin, forward -Z) from the gait clock `t`, the gait `mode` and `phase`, the seconds spent in the ATTACK mode. Bodies only: a
## mini (mote, shard) is hopped by the MiniSwarm.

## Stomp cycle of the Tremor Rig in rad/s (one footfall per half cycle); slower and heavier than the Hulk's.
const TREMOR_STEP_RATE: float = 1.7


static func pose(kind: int, t: float, mode: int, phase: float) -> Transform3D:
	var y: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	var yaw: float = 0.0
	var fwd: float = 0.0
	var moving: bool = mode == ActorMotion.Mode.MOVE
	var attacking: bool = mode == ActorMotion.Mode.ATTACK
	var stunned: bool = mode == ActorMotion.Mode.STUN
	match kind:
		Ids.EN_SPITTER:
			if moving:
				y = absf(sin(t * 5.0)) * 0.04
				roll = sin(t * 5.0) * 0.05
			elif attacking:  # the tube kicks back with every bolt
				var kick: float = maxf(0.0, sin(phase * 2.6))
				pitch = 0.1 * kick * kick
				fwd = 0.06 * kick
		Ids.EN_SPLITTER:
			if moving:
				y = absf(sin(t * 3.6)) * 0.05
				roll = sin(t * 3.6) * 0.07
				yaw = sin(t * 1.8) * 0.04
			elif attacking:
				var slam: float = maxf(0.0, sin(t * 4.5))
				pitch = -0.2 * slam
				fwd = -0.1 * slam
		Ids.EN_SHIELDBEARER:
			if moving:
				y = absf(sin(t * 3.5)) * 0.035
				roll = sin(t * 3.5) * 0.03
			elif attacking:  # a shield bash
				var bash: float = maxf(0.0, sin(t * 4.0))
				fwd = -0.18 * bash
				pitch = -0.06 * bash
		Ids.EN_RECLAIMER:
			if moving:
				y = absf(sin(t * 6.0)) * 0.025
				roll = sin(t * 6.0) * 0.03
			elif attacking:  # tethering: the mast sways and the body pulses
				yaw = sin(t * 1.5) * 0.08
				y = 0.02 * sin(t * 6.0)
		Ids.EN_JAMMER:
			if moving:
				y = absf(sin(t * 4.5)) * 0.045
				roll = sin(t * 4.5) * 0.04
			elif attacking:
				roll = sin(t * 18.0) * 0.03
		Ids.EN_BORER:
			if moving:
				y = absf(sin(t * 14.0)) * 0.025
				pitch = sin(t * 22.0) * 0.03
				roll = sin(t * 7.0) * 0.04
			elif attacking:
				var lunge: float = maxf(0.0, sin(t * 9.0))
				fwd = -0.14 * lunge
				pitch = -0.08 * lunge
		Ids.EN_WARD_PYLON:  # a hover over the ground and a slow tilt
			y = 0.06 + 0.05 * sin(t * 2.0)
			roll = sin(t * 1.3) * 0.04
			pitch = sin(t * 1.1 + 1.0) * 0.03
		Ids.EN_BROOD_CARRIER:
			if moving:
				y = absf(sin(t * 2.0)) * 0.06
				roll = sin(t * 2.0) * 0.035
			elif attacking:
				pitch = -0.04 * maxf(0.0, sin(t * 3.0))
		Ids.EN_LANCE_PLATFORM:
			if moving:
				y = absf(sin(t * 2.4)) * 0.04
				roll = sin(t * 2.4) * 0.02
			else:  # planted: it settles on its legs and hums
				y = -0.03
				roll = sin(t * 25.0) * 0.004
		Ids.EN_AEGIS_ARRAY:
			y = absf(sin(t * 1.8)) * 0.04 if moving else 0.0
			yaw = sin(t * 0.9) * 0.05
			roll = sin(t * 1.8) * 0.02 if moving else 0.0
		Ids.EN_TREMOR_RIG:
			if moving:  # a heavy stomp: the body rises between steps and thumps down at each footfall
				var s: float = absf(sin(t * TREMOR_STEP_RATE))
				y = 0.1 * s
				roll = sin(t * TREMOR_STEP_RATE) * 0.045
				pitch = -0.025 * cos(t * TREMOR_STEP_RATE * 2.0)
			elif attacking:
				var slam2: float = maxf(0.0, sin(t * 2.2))
				pitch = -0.1 * slam2 * slam2
				y = -0.06 * slam2
	if stunned:
		roll += sin(t * 32.0) * 0.04
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3(0.0, y, fwd))


## Footfalls completed at gait time `t` for the Tremor Rig; -1 for the others (the Hulk is `ActorMotion.step_index`).
static func step_index(kind: int, t: float) -> int:
	if kind != Ids.EN_TREMOR_RIG:
		return -1
	return floori(t * TREMOR_STEP_RATE / PI)

class_name LookDevIk
extends RefCounted
## Analytic two-bone solve for the arms of the hard-surface Warden (W3-C round 2). The shoulder and the wrist are known;
## the elbow is the point on the circle of intersection of the two bone spheres that lies toward the pole direction
## (outward, down and back for an arm). A target out of reach is clamped to the line toward it at full stretch, so the
## arm never breaks. Pure math, no allocation beyond Vector3 values; the nodes are only written by `pose_arm`.

const MIN_BEND: float = 0.01
const MAX_BEND: float = 0.002


## The wrist position the arm can actually reach: `target` clamped to the shell between |a - b| and a + b around `shoulder`.
static func reach_point(shoulder: Vector3, target: Vector3, len_a: float, len_b: float) -> Vector3:
	var to_t: Vector3 = target - shoulder
	var dist: float = to_t.length()
	if dist < 0.0001:
		return shoulder + Vector3(0.0, 0.0, -0.01)
	var d: float = clampf(dist, absf(len_a - len_b) + MIN_BEND, len_a + len_b - MAX_BEND)
	return shoulder + to_t / dist * d


## The elbow for a wrist at `reach_point(...)`, bent toward `pole`.
static func elbow(shoulder: Vector3, target: Vector3, len_a: float, len_b: float, pole: Vector3) -> Vector3:
	var wrist: Vector3 = reach_point(shoulder, target, len_a, len_b)
	var to_w: Vector3 = wrist - shoulder
	var d: float = to_w.length()
	var u: Vector3 = to_w / d
	var cos_a: float = clampf((len_a * len_a + d * d - len_b * len_b) / (2.0 * len_a * d), -1.0, 1.0)
	var along: float = len_a * cos_a
	var height: float = sqrt(maxf(len_a * len_a - along * along, 0.0))
	var side: Vector3 = pole - u * pole.dot(u)
	if side.length_squared() < 0.000001:
		side = Vector3.UP - u * u.y
	return shoulder + u * along + side.normalized() * height


## Places the two segment nodes of an arm: `upper` at the shoulder, `fore` at the elbow, each looking along its bone (-Z)
## with +Y toward the pole, so the meshes (built along -Z with their outer side on +Y) bend the right way.
static func pose_arm(
	upper: Node3D, fore: Node3D, shoulder: Vector3, target: Vector3, len_a: float, len_b: float, pole: Vector3
) -> void:
	var wrist: Vector3 = reach_point(shoulder, target, len_a, len_b)
	var e: Vector3 = elbow(shoulder, target, len_a, len_b, pole)
	upper.position = shoulder
	upper.basis = _aim(e - shoulder, pole)
	fore.position = e
	fore.basis = _aim(wrist - e, pole)


## The wrist of an arm posed by `pose_arm` (end of the forearm), from the forearm node.
static func wrist_of(fore: Node3D, len_b: float) -> Vector3:
	return fore.position + fore.basis * Vector3(0.0, 0.0, -len_b)


static func _aim(dir: Vector3, pole: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	var up: Vector3 = pole - d * pole.dot(d)
	if up.length_squared() < 0.000001:
		up = Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(d, up.normalized())

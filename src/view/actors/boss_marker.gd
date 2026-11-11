class_name BossMarker
extends MeshInstance3D
## World marker of the wave-5 boss: a pulsing red ring on the ground around the Siege Hulk and two bobbing chevrons
## above its head, so the boss reads at a glance in a crowd of 50. One merged mesh, unshaded red (the enemy color; the
## chevrons are a shape cue besides): one node, two draw calls (ring alpha, chevrons opaque). Hidden while there is no boss.

const RING_IN: float = 2.25
const RING_OUT: float = 2.55
const CHEVRON_Y: float = 6.6  ## world height: the camera pitch projects it clear of the Hulk's top (3.4 m, 1.6 m radius)
const CHEVRON_STEP: float = 0.8
const CHEVRON_W: float = 1.9
const CHEVRON_H: float = 1.0
const BOB_M: float = 0.18
const PULSE: float = 0.05

var _time: float = 0.0
var _at: Vector3 = Vector3.INF


func setup(pitch_down_deg: float, yaw_deg: float) -> void:
	name = "BossMarker"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the chevrons face the camera: its basis (CameraFit), then 180 degrees about Z so the apex points down
	var cam: Basis = Basis(Vector3.RIGHT, -deg_to_rad(pitch_down_deg)) * Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var down: Basis = cam * Basis(Vector3.BACK, PI)
	var mb: MeshBuilder = MeshKit.begin()
	mb.ring(RING_IN, RING_OUT, 48, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.07, 0.0)), &"add_red")
	for k: int in 2:
		var lift: Vector3 = Vector3(0.0, CHEVRON_Y + CHEVRON_STEP * float(k), 0.0)
		mb.prism(Vector3(CHEVRON_W, CHEVRON_H, 0.04), Transform3D(down, lift), &"emit_red")
	mesh = mb.build()
	visible = false


## Follows the boss at `world_pos`; Vector3.INF (no boss, or it is collapsing) hides the marker.
func track(world_pos: Vector3, delta: float) -> void:
	_time += delta
	_at = world_pos
	if not world_pos.is_finite():
		visible = false
		return
	visible = true
	# the ring stays on the ground (y is nearly 0); the bob is a tiny vertical scale that only moves the chevrons
	var pulse: float = 1.0 + PULSE * sin(_time * 4.0)
	position = world_pos
	scale = Vector3(pulse, 1.0 + sin(_time * 3.0) * BOB_M / CHEVRON_Y, pulse)


func is_tracking() -> bool:
	return visible and _at.is_finite()

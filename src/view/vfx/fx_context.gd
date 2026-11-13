class_name FxContext
extends RefCounted
## What every chaos module of the VfxLayer shares (V4-X): the content, the actor layer (positions of enemies), the camera rig, the view-only
## RNG, the screen-size factor (`FxScale`), the sim while the layer is bound (read only), and the three view switches: the quality tier,
## Reduced Flash and High Contrast. The VfxLayer owns one and hands it to `FxChaos`; a module reads the switches, it never changes them.

var content: ContentSet
var actors: ActorLayer
var rig: CameraRig
var rng: RandomNumberGenerator
var scale: FxScale = FxScale.new()
var sim: SimWorld  ## null until `bind`
var tier: int = VisualQuality.Tier.HIGH
var reduced: bool = false  ## Reduced Flash
var contrast: bool = false  ## High Contrast


func setup(content_set: ContentSet, camera_rig: CameraRig, actor_layer: ActorLayer, view_rng: RandomNumberGenerator) -> void:
	content = content_set
	rig = camera_rig
	actors = actor_layer
	rng = view_rng
	scale.setup(content_set.arena)


## The world position of a live enemy as drawn (Vector3.INF when the view does not know it).
func enemy_at(enemy_id: int) -> Vector3:
	return actors.enemy_world_position(enemy_id) if actors != null else Vector3.INF


## A random point of the yard on the ground, from the view RNG.
func random_in_yard(margin: float = 0.0) -> Vector3:
	var a: ArenaDef = content.arena
	return Vector3(rng.randf_range(a.min_x + margin, a.max_x - margin), 0.0, rng.randf_range(a.min_z + margin, a.max_z - margin))

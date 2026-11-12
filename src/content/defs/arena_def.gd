class_name ArenaDef
extends RefCounted
## Arena geometry (ARCH 5.2/5.3). X = screen right, Z = screen down, meters.

var id: StringName
var min_x: float
var max_x: float
var min_z: float
var max_z: float
var cell_m: float
var margin_cells: int
var core_x: float
var core_z: float
var core_radius: float
var warden_x: float
var warden_z: float
var turret_pads: PackedVector2Array = PackedVector2Array()  ## (x, z)
var approach_radius: float
var slot_positions: PackedVector2Array = PackedVector2Array()  ## (x, z), 64 entries, computed by the loader
var slot_ring: PackedInt32Array = PackedInt32Array()
var spawn_regions: Array[SpawnRegionDef] = []
var obstacles: Array[ObstacleDef] = []
var pitch_down_deg: float
var yaw_deg: float
var frame_margin_m: float
var decor_yaw_deg: float
# --- arena.json schema 2 (variety milestone; empty in the legacy content) ---
var standoff_points: PackedVector2Array = PackedVector2Array()  ## (x, z) on the slot arc, computed by the loader
var standoff_ring: PackedInt32Array = PackedInt32Array()  ## index into standoff_radii, per point
var standoff_radii: PackedFloat32Array = PackedFloat32Array()
var breach_points: PackedVector2Array = PackedVector2Array()
var drop_points: PackedVector2Array = PackedVector2Array()
var drum_points: PackedVector2Array = PackedVector2Array()
var rail_z: PackedFloat32Array = PackedFloat32Array()  ## one entry per rail line (a line of constant z)
var rail_half_width: PackedFloat32Array = PackedFloat32Array()


func region(region_id: StringName) -> SpawnRegionDef:
	for r: SpawnRegionDef in spawn_regions:
		if r.id == region_id:
			return r
	return null

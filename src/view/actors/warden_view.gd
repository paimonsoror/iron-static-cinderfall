class_name WardenView
extends Node3D
## The Warden: legs stay planted, the upper body yaws to `warden.aim` (GDD 5.1), recoils on `shot_fired`, swaps the
## weapon on `weapon_changed`, dips the weapon while reloading and sways when idle. Procedural, read-only on the sim.
## W3-C: a look switch (LookDevStyle). CURRENT keeps the original boxes and poses byte for byte; the hard-surface looks
## swap the meshes and materials of the same nodes, add the arms, pack, antenna and cable parts, and drive them with
## WardenMotion (springs, breathing, reload pose). In STYLISED_PLUS on HIGH a pooled omni light flashes at each shot.
##
## Node tree: WardenView (ground) / Legs, Upper (waist pivot, yaw) / Body (recoil, sway) / Torso, Hand / Pistol, Smg
## (each with a Muzzle marker); Body also holds ArmR, ArmL, Pack, Antenna, Cable (hidden in CURRENT); Hand holds the
## MuzzleLight.

const AIM_RATE: float = 16.0
const RECOIL_KICK: float = 0.7
const RECOIL_DECAY: float = 20.0
const RELOAD_RATE: float = 7.0
const FLASH_DECAY: float = 32.0
const MUZZLE_LIGHT_ENERGY: float = 1.1
const MUZZLE_LIGHT_RANGE: float = 2.6

var _sim: SimWorld
var _upper: Node3D
var _body: Node3D
var _hand: Node3D
var _weapons: Array[MeshInstance3D] = []
var _muzzles: Array[Node3D] = []
var _weapon: int = 0
var _yaw: float = 0.0
var _fresh: bool = true
var _recoil: float = 0.0
var _reload_amt: float = 0.0
var _reloading: bool = false
var _reload_left: float = 0.0
var _reload_total: float = 1.0
var _t: float = 0.0
var _parts: WardenParts = WardenParts.new()
var _motion: WardenMotion = WardenMotion.new()
var _light: OmniLight3D
var _flash: float = 0.0
var _look: int = LookDevStyle.Look.CURRENT
var _tier: int = VisualQuality.Tier.HIGH
var _accent_energy: float = -1.0


func setup() -> void:
	name = "WardenView"
	visible = false
	var legs: MeshInstance3D = _mesh_node("Legs", ActorMeshes.warden_legs())
	add_child(legs)
	_upper = Node3D.new()
	_upper.name = "Upper"
	_upper.position = Vector3(0.0, HeroMeshes.WARDEN_WAIST_Y, 0.0)
	add_child(_upper)
	_body = Node3D.new()
	_body.name = "Body"
	_upper.add_child(_body)
	var torso: MeshInstance3D = _mesh_node("Torso", ActorMeshes.warden_torso())
	_body.add_child(torso)
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = HeroMeshes.WARDEN_HAND
	_body.add_child(_hand)
	var specs: Array[Array] = [
		["Pistol", ActorMeshes.pistol(), HeroMeshes.PISTOL_MUZZLE],
		["Smg", ActorMeshes.smg(), HeroMeshes.SMG_MUZZLE],
		["ArcProjector", ActorMeshes.new_weapon(&"arc_projector"), WeaponMeshes.ARC_MUZZLE],
	]
	for spec: Array in specs:
		var weapon_name: String = spec[0]
		var weapon_mesh: ArrayMesh = spec[1]
		var tip: Vector3 = spec[2]
		var w: MeshInstance3D = _mesh_node(weapon_name, weapon_mesh)
		var m: Node3D = Node3D.new()
		m.name = "Muzzle"
		m.position = tip
		w.add_child(m)
		_hand.add_child(w)
		_weapons.append(w)
		_muzzles.append(m)
	_parts.attach(legs, torso, _weapons, _body)
	_light = OmniLight3D.new()
	_light.name = "MuzzleLight"
	_light.position = Vector3(0.0, 0.06, -0.62)
	_light.omni_range = MUZZLE_LIGHT_RANGE
	_light.omni_attenuation = 1.4
	_light.light_energy = 0.0
	_light.light_specular = 0.4
	_light.shadow_enabled = false
	_light.visible = false
	_light.light_color = MatLib.mat(&"emit_amber").albedo_color.lerp(Color.WHITE, 0.3)
	_hand.add_child(_light)
	set_look(LookDevStyle.current())
	_show_weapon(0)


## Starts reading `sim` (read only) and listening to the Events that drive the Warden's poses.
func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	_fresh = true
	_recoil = 0.0
	_flash = 0.0
	_reload_amt = 0.0
	_motion.reset()
	_reloading = sim.warden.reload_ticks_left > 0
	_reload_left = float(sim.warden.reload_ticks_left) * SimWorld.DT
	_reload_total = maxf(_reload_left, 0.5)
	_show_weapon(WeaponMeshes.model_index(sim.warden.weapon_index))
	position = Vector3(sim.warden.x, 0.0, sim.warden.z)
	Events.shot_fired.connect(_on_shot_fired)
	Events.weapon_changed.connect(_on_weapon_changed)
	Events.weapon_swapped.connect(_on_weapon_swapped)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	render(0.0, 0.0)
	visible = true


func unbind() -> void:
	if Events.shot_fired.is_connected(_on_shot_fired):
		Events.shot_fired.disconnect(_on_shot_fired)
	if Events.weapon_changed.is_connected(_on_weapon_changed):
		Events.weapon_changed.disconnect(_on_weapon_changed)
	if Events.weapon_swapped.is_connected(_on_weapon_swapped):
		Events.weapon_swapped.disconnect(_on_weapon_swapped)
	if Events.reload_started.is_connected(_on_reload_started):
		Events.reload_started.disconnect(_on_reload_started)
	if Events.reload_finished.is_connected(_on_reload_finished):
		Events.reload_finished.disconnect(_on_reload_finished)
	_sim = null
	visible = false


func render(_alpha: float, delta: float) -> void:
	if _sim == null:
		return
	var w: WardenState = _sim.warden
	position = Vector3(w.x, 0.0, w.z)
	var dx: float = w.aim_x - w.x
	var dz: float = w.aim_z - w.z
	if dx * dx + dz * dz > 0.0001:
		var target: float = atan2(-dx, -dz)
		if _fresh:
			_yaw = target
		else:
			_yaw = lerp_angle(_yaw, target, 1.0 - exp(-AIM_RATE * delta))
		_fresh = false
	_upper.rotation.y = _yaw
	_t += delta
	_recoil *= exp(-RECOIL_DECAY * delta)
	_flash *= exp(-FLASH_DECAY * delta)
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reloading = false
	_reload_amt = move_toward(_reload_amt, 1.0 if _reloading else 0.0, delta * RELOAD_RATE)
	if LookDevStyle.secondary_motion_enabled(_look, _tier):
		_motion.step(delta, _yaw)
		var progress: float = clampf(1.0 - _reload_left / _reload_total, 0.0, 1.0)
		_motion.pose(_t, _reload_amt, progress, _weapon, _body, _hand, _parts)
		_drive_accents()
		_drive_muzzle_light()
		return
	# upper body: recoil kick back along the aim, forward dip while reloading, idle sway
	_body.position = Vector3(0.0, sin(_t * 1.8) * 0.008, 0.11 * _recoil + 0.04 * _reload_amt)
	_body.rotation = Vector3(-0.1 * _reload_amt, 0.0, sin(_t * 1.3) * 0.012)
	_hand.rotation.x = 0.08 * _recoil - 0.9 * _reload_amt
	_hand.position = HeroMeshes.WARDEN_HAND + Vector3(0.0, -0.06 * _reload_amt, 0.05 * _recoil)


## Switches the look (LookDevStyle.Look); safe before and after `bind`. Builds the hard-surface meshes on first use.
func set_look(new_look: int) -> void:
	_look = clampi(new_look, LookDevStyle.Look.CURRENT, LookDevStyle.Look.STYLISED_PLUS)
	_apply_style()


## Quality tier (VisualQuality.Tier): gates rim, ramp, wear, detail, accent brightness and the muzzle light.
func set_quality(tier: int) -> void:
	_tier = VisualQuality.from_setting(tier)
	_apply_style()


func look() -> int:
	return _look


func parts() -> WardenParts:
	return _parts


func muzzle_light() -> OmniLight3D:
	return _light


## World position of the muzzle of the weapon in hand.
func muzzle_position() -> Vector3:
	var m: Node3D = _muzzles[_weapon]
	if m.is_inside_tree():
		return m.global_position
	return position + Vector3(0.0, 1.3, 0.0)


func weapon_index() -> int:
	return _weapon


func weapon_visible(weapon: int) -> bool:
	return weapon >= 0 and weapon < _weapons.size() and _weapons[weapon].visible


func recoil_amount() -> float:
	return _recoil


func reload_amount() -> float:
	return _reload_amt


## Yaw of the upper body (radians, 0 = facing -Z).
func upper_yaw() -> float:
	return _yaw


func is_reloading() -> bool:
	return _reloading


## Look-dev only: holds the reload pose (a capture of the pose that reads), or releases it.
func debug_hold_reload(on: bool) -> void:
	_reloading = on
	_reload_left = 3600.0 if on else 0.0
	_reload_total = 3600.0


func _apply_style() -> void:
	if _parts.legs == null:
		return
	_parts.apply(_look, _tier)
	if not LookDevStyle.secondary_motion_enabled(_look, _tier):
		WardenMotion.rest(_body, _hand, _parts)
	_accent_energy = -1.0
	var lit: bool = LookDevStyle.muzzle_light_enabled(_look, _tier)
	if not lit:
		_light.visible = false
		_light.light_energy = 0.0


func _drive_accents() -> void:
	var accent: StandardMaterial3D = _parts.accent_material()
	if accent == null:
		return
	var energy: float = LookDevStyle.accent_energy(_look, _tier) * (1.0 + 0.1 * _flash - 0.55 * _reload_amt)
	if absf(energy - _accent_energy) > 0.02:
		_accent_energy = energy
		accent.albedo_color = LookDevMat.accent_color(energy)


func _drive_muzzle_light() -> void:
	if not LookDevStyle.muzzle_light_enabled(_look, _tier):
		return
	var on: bool = _flash > 0.03
	_light.visible = on
	if on:
		_light.light_energy = MUZZLE_LIGHT_ENERGY * _flash


func _show_weapon(index: int) -> void:
	_weapon = clampi(index, 0, _weapons.size() - 1)
	for i: int in _weapons.size():
		_weapons[i].visible = i == _weapon


func _mesh_node(node_name: String, mesh_res: ArrayMesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh_res
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _on_shot_fired(source: int, _target_id: int) -> void:
	if source == DamageSource.Id.WARDEN:
		_recoil = minf(1.0, _recoil + RECOIL_KICK)
		_flash = 1.0
		_motion.kick(1.0)


func _on_weapon_changed(weapon_id: StringName) -> void:
	var index: int = Ids.weapon_index(weapon_id)
	if index >= 0:
		_show_weapon(WeaponMeshes.model_index(index))


## The weapon in the other slot comes into the hand (the swap takes `swap_ticks` of no fire in the sim; the view just changes models).
func _on_weapon_swapped(_slot: int, weapon_id: StringName) -> void:
	_on_weapon_changed(weapon_id)


func _on_reload_started(ticks: int) -> void:
	_reloading = true
	_reload_left = float(ticks) * SimWorld.DT
	_reload_total = maxf(_reload_left, 0.5)


func _on_reload_finished() -> void:
	_reloading = false
	_reload_left = 0.0

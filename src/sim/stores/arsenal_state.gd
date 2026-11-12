class_name ArsenalState
extends RefCounted
## The weapon slots of the Warden (VARIETY_SPEC 3.1, 13.2). WardenState.weapon_index, magazine and reload_ticks_left
## stay and mirror the active slot, so the HUD, the view and the legacy tests keep reading them. Written by
## ArsenalSystem and SalvageSystem (slot contents) only; hashed.
## Units: magazines in rounds, reloads, vents and swaps in ticks, heat in the units of WeaponDef.heat_cap (0..cap). The
## two `*_acc` arrays carry the fractions that keep heat and timers integers (VARIETY_SPEC 9.5 rule 4): a holstered
## reload advances by `holster_reload_mult` x 1000 per tick and a reload tick costs 1000; cooling adds `cool_per_s` per
## tick and one unit of heat costs 60.

const MAX_SLOTS: int = 3
const FIELDS: PackedStringArray = [
	"slot_count", "slot_weapon", "slot_level", "slot_magazine", "slot_reload_left", "slot_heat", "slot_vent_left", "active",
	"swap_left", "charge_left", "charge_x", "charge_z", "spin_ticks", "idle_ticks", "beam_target", "beam_hits",
	"shots_since_proc", "offhand_acc_milli", "slot_reload_acc", "slot_cool_acc",
]

var slot_count: int = 2  ## 3 with the third sling
var slot_weapon: PackedInt32Array = PackedInt32Array([0, -1, -1])  ## Ids.WEAPONS index, -1 = empty (shows the pistol)
var slot_level: PackedInt32Array = PackedInt32Array([1, 1, 1])  ## 1..3
var slot_magazine: PackedInt32Array = PackedInt32Array([0, 0, 0])
var slot_reload_left: PackedInt32Array = PackedInt32Array([0, 0, 0])
var slot_heat: PackedInt32Array = PackedInt32Array([0, 0, 0])
var slot_vent_left: PackedInt32Array = PackedInt32Array([0, 0, 0])
var active: int = 0
var swap_left: int = 0  ## ticks of the swap in progress (no fire)
var charge_left: int = 0  ## rail lance wind-up
var charge_x: float = 0.0  ## the fixed end of the charge line
var charge_z: float = 0.0
var spin_ticks: int = 0  ## LMG spin-up progress
var idle_ticks: int = 0
var beam_target: int = 0  ## enemy id the beam is locked on
var beam_hits: int = 0  ## consecutive hits on beam_target (the ramp)
var shots_since_proc: int = 0  ## shock_rounds and the pistol level-3 perk
var offhand_acc_milli: int = 0  ## twin_link cadence accumulator
var slot_reload_acc: PackedInt32Array = PackedInt32Array([0, 0, 0])  ## holstered reload progress, thousandths of a tick
var slot_cool_acc: PackedInt32Array = PackedInt32Array([0, 0, 0])  ## cooling progress, sixtieths of a heat unit


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)

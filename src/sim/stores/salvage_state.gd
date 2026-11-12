class_name SalvageState
extends RefCounted
## The crate on the field, the bank and the offer being resolved (VARIETY_SPEC 3.4, CONTENT 7). Written by
## SalvageSystem only; hashed.
# TODO(V2-C): the stub holds the neutral state.

const FIELDS: PackedStringArray = [
	"crate_active", "crate_boss", "crate_x", "crate_z", "crate_point", "crate_progress", "crate_life_left", "crate_ordinal",
	"banked", "crates_secured", "offer", "offer_boss", "elite_kills",
]

var crate_active: bool = false
var crate_boss: bool = false  ## a boss crate (choose 1 of 2)
var crate_x: float = 0.0
var crate_z: float = 0.0
var crate_point: int = -1  ## index into ArenaDef.drop_points
var crate_progress: int = 0  ## uncontested ticks so far
var crate_life_left: int = 0
var crate_ordinal: int = 0  ## n of the `crate:<n>` stream: crates secured so far
var banked: PackedInt32Array = PackedInt32Array()  ## one entry per banked crate: 0 normal, 1 boss
var crates_secured: int = 0
var offer: PackedInt32Array = PackedInt32Array()  ## weapon indices of the crate being resolved (SALVAGE await)
var offer_boss: bool = false
var elite_kills: int = 0  ## chorus_handshake counter


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)

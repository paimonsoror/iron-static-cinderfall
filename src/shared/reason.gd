class_name Reason
extends RefCounted
## Command outcomes (ARCH 4).

enum Id {
	OK,
	WRONG_STATE,
	UNKNOWN_ID,
	MAX_LEVEL,
	INSUFFICIENT_SCRAP,
	PREREQ_NOT_MET,
	DUPLICATE_COMMAND,
	ON_COOLDOWN,
	ALREADY_ACTIVE,
	PAUSED,
}

const KEYS: PackedStringArray = [
	"reason.ok",
	"reason.wrong_state",
	"reason.unknown_id",
	"reason.max_level",
	"reason.insufficient_scrap",
	"reason.prereq_not_met",
	"reason.duplicate_command",
	"reason.on_cooldown",
	"reason.already_active",
	"reason.paused",
]


## String-table key for a reason, e.g. "reason.insufficient_scrap".
static func string_key(id: int) -> String:
	if id < 0 or id >= KEYS.size():
		return "reason.unknown_id"
	return KEYS[id]

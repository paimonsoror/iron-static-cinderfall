class_name ProfileCodec
extends RefCounted
## Profile <-> JSON text. TODO(W1-D): full encode/decode with type and range validation.

@warning_ignore_start("unused_parameter")


static func encode(p: Profile) -> String:
	# TODO(W1-D)
	return ""


## Validates types and ranges; clamps negatives to 0; unknown keys ignored; never executes or loads paths.
static func decode(text: String) -> ProfileDecodeResult:
	# TODO(W1-D)
	var r: ProfileDecodeResult = ProfileDecodeResult.new()
	r.error = "not implemented"
	return r

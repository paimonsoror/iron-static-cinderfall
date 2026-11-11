class_name ContentValidator
extends RefCounted
## Strict content checks (ARCH 5.4). TODO(W1-D): every rule, one test with a bad fixture each.

@warning_ignore_start("unused_parameter")


## Returns one message per problem; empty when the content is valid.
static func validate(content: ContentSet) -> PackedStringArray:
	# TODO(W1-D)
	return PackedStringArray()

class_name ContentLoadResult
extends RefCounted

var content: ContentSet  ## null when errors is not empty
var errors: PackedStringArray = PackedStringArray()  ## human-readable, one per problem, with file and JSON path

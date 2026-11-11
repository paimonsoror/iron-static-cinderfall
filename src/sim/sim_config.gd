class_name SimConfig
extends RefCounted

var run_seed: int
var content: ContentSet
var debug_invulnerable_core: bool = false
var debug_damage_mult: float = 1.0
var debug_start_scrap: int = 0


static func create(content_set: ContentSet, seed_value: int) -> SimConfig:
	var c: SimConfig = SimConfig.new()
	c.content = content_set
	c.run_seed = seed_value
	return c

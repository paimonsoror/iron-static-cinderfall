class_name VisualTokens
extends RefCounted
## Palette and layout tokens from visual_tokens.json.

## obsidian, warden_cyan, core_amber, chorus_red, gunmetal, bone_ceramic
var palette: Dictionary[StringName, Color] = {}
var top_hud_fraction: float = 0.11
var bottom_controls_fraction: float = 0.23
var touch_target_min_dp: int = 48
var text_contrast_target: float = 4.5
var down_angle_min_deg: float = 55.0
var down_angle_max_deg: float = 65.0


## Magenta for an unknown token so mistakes are visible.
func color(token: StringName) -> Color:
	if palette.has(token):
		return palette[token]
	return Color.MAGENTA

class_name GameViewSettings
extends RefCounted
## Pushes the player's settings (and the debug overrides) into the 3D view and the engine. Quality tiers, Reduced
## Flash and High Contrast change only how the battle looks, never an outcome (ARCH 13). `--quality=<0..2>` beats the
## saved tier for the whole session.

## Settings keys that have to be re-applied when `Events.settings_changed` names them.
const VIEW_KEYS: Array[StringName] = [&"quality", &"reduced_flash", &"high_contrast"]
## The character look of the shipped game (owner pick after the W3-C Warden look-dev, v4). `--look=` overrides it.
const SHIPPED_LOOK: int = LookDevStyle.Look.STYLISED


## Sets the process-wide character look (`--look=current|stylised|stylised_plus`, else the shipped one). `Game.boot` calls
## it before any BattleView exists, because ActorLayer and ArenaView read the look when they are constructed. Returns it.
static func apply_look(args: DebugArgs) -> int:
	LookDevStyle.set_current(args.look if args != null and args.look >= 0 else SHIPPED_LOOK)
	return LookDevStyle.current()


## The tier to show: `--quality` when forced, otherwise the saved setting (clamped to 0..2).
static func quality_tier(args: DebugArgs) -> int:
	if args != null and args.quality >= 0:
		return VisualQuality.from_setting(args.quality)
	return VisualQuality.from_setting(int_setting(&"quality", VisualQuality.Tier.HIGH))


## set_quality, set_reduced_flash and set_high_contrast on the view.
static func apply_to_view(view: BattleView, args: DebugArgs) -> void:
	if view == null:
		return
	view.set_quality(quality_tier(args))
	view.set_reduced_flash(bool_setting(&"reduced_flash", false))
	view.set_high_contrast(bool_setting(&"high_contrast", false))


## Engine.max_fps from the `fps_cap` setting (30 or 60). A headless run has no display to pace, so it is left alone.
static func apply_fps_cap() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = int_setting(&"fps_cap", 60)


static func bool_setting(key: StringName, fallback: bool) -> bool:
	var v: Variant = Save.get_setting(key)
	return v if typeof(v) == TYPE_BOOL else fallback


static func int_setting(key: StringName, fallback: int) -> int:
	var v: Variant = Save.get_setting(key)
	return v if typeof(v) == TYPE_INT else fallback

class_name SafeArea
extends RefCounted
## Converts the OS safe area (window pixels) into margins in viewport units (ARCH 9).


## Returns (left, top, right, bottom). A zero-size window or an empty safe rect gives zero margins.
static func margins(window_px: Vector2i, safe_px: Rect2i, viewport_size: Vector2) -> Vector4:
	if window_px.x <= 0 or window_px.y <= 0 or safe_px.size.x <= 0 or safe_px.size.y <= 0:
		return Vector4.ZERO
	var sx: float = viewport_size.x / float(window_px.x)
	var sy: float = viewport_size.y / float(window_px.y)
	var left: float = float(safe_px.position.x) * sx
	var top: float = float(safe_px.position.y) * sy
	var right: float = float(window_px.x - safe_px.end.x) * sx
	var bottom: float = float(window_px.y - safe_px.end.y) * sy
	return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))

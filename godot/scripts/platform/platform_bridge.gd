extends RefCounted
## All Android access is isolated here; desktop needs no native plugin.
var native: Object
var session_id := "desktop-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]

func _init() -> void:
	if Engine.has_singleton("IdleBridge"):
		native = Engine.get_singleton("IdleBridge")

func clock_now() -> Dictionary:
	if native:
		var parsed = JSON.parse_string(native.clock_json())
		if parsed is Dictionary and parsed.has_all(["wall", "mono", "boot"]):
			if str(parsed.boot).is_empty():
				parsed.boot = session_id
			return parsed
	return {"wall": Time.get_unix_time_from_system(), "mono": Time.get_ticks_msec() / 1000.0, "boot": session_id}

func available() -> bool:
	return native != null

func can_overlay() -> bool:
	return native != null and native.can_overlay()

func request_permission() -> void:
	if native:
		native.request_overlay_permission()

func start_overlay(payload: Dictionary) -> void:
	if native:
		native.start_overlay(JSON.stringify(payload))

func stop_overlay() -> void:
	if native:
		native.stop_overlay()

func status() -> Dictionary:
	if native:
		var result = JSON.parse_string(native.status_json())
		if result is Dictionary:
			return result
	return {"state": "idle", "message": "Janela flutuante disponível no aplicativo Android."}

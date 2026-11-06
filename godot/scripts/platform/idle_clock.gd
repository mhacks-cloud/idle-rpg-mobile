extends RefCounted
## Same boot: Android elapsedRealtime includes suspend and ignores wall edits.
## Across reboot / desktop process: bounded wall fallback cannot prevent cheating.
const CAP_SECONDS := 7200

static func _valid_stamp(stamp: Dictionary) -> bool:
	if not stamp.has_all(["wall", "mono", "boot"]):
		return false
	for key in ["wall", "mono"]:
		if not (stamp[key] is int or stamp[key] is float):
			return false
		if not is_finite(float(stamp[key])) or float(stamp[key]) < 0.0:
			return false
	if not stamp.boot is String or str(stamp.boot).is_empty() or str(stamp.boot).length() > 200:
		return false
	return true

static func elapsed(previous: Dictionary, current: Dictionary) -> Dictionary:
	if not _valid_stamp(previous) or not _valid_stamp(current):
		return {"seconds": 0, "source": "missing", "clamped": true}
	var same_boot: bool = previous.boot == current.boot
	var delta := float(current.mono) - float(previous.mono) if same_boot else float(current.wall) - float(previous.wall)
	return {"seconds": int(clampf(floor(delta), 0, CAP_SECONDS)), "source": "monotonic" if same_boot else "wall_bounded", "clamped": delta < 0 or delta > CAP_SECONDS}

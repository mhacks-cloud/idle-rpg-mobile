class_name SaveStore
extends RefCounted
## Crash-resistant local persistence. Hash detects accidental damage, not cheating.
## Unknown future formats are read-only until a compatible app opens them.
const FORMAT_VERSION := 1
const MAX_FILE_BYTES := 4 * 1024 * 1024
var path: String
var last_error := ""
var _future_version := false

func _init(save_path: String = "user://session.json") -> void:
	path = save_path

func _read(candidate_path: String) -> Dictionary:
	if not FileAccess.file_exists(candidate_path):
		return {"status": "missing"}
	var file := FileAccess.open(candidate_path, FileAccess.READ)
	if file == null:
		return {"status": "io_error"}
	if file.get_length() > MAX_FILE_BYTES:
		return {"status": "corrupt"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"status": "corrupt"}
	var envelope: Dictionary = parser.data
	if not (envelope.get("format") is float or envelope.get("format") is int):
		return {"status": "corrupt"}
	if float(envelope.format) > FORMAT_VERSION:
		return {"status": "future_version"}
	if float(envelope.format) != FORMAT_VERSION:
		return {"status": "corrupt"}
	if not envelope.get("payload_json") is String or not envelope.get("sha256") is String:
		return {"status": "corrupt"}
	var serialized: String = envelope.payload_json
	if serialized.sha256_text() != envelope.sha256:
		return {"status": "corrupt"}
	if parser.parse(serialized) != OK or not parser.data is Dictionary:
		return {"status": "corrupt"}
	return {"status": "ok", "payload": parser.data}

func load_save() -> Dictionary:
	_future_version = false
	var primary := _read(path)
	if primary.status == "ok":
		return {"status": "ok", "payload": primary.payload, "message": "Sessão restaurada."}
	if primary.status == "future_version":
		_future_version = true
		return {"status": "future_version", "payload": {}, "message": "Save de versão mais nova. Arquivo preservado; gravação bloqueada."}
	for suffix in [".bak", ".tmp"]:
		var fallback := _read(path + suffix)
		if fallback.status == "future_version":
			_future_version = true
			return {"status": "future_version", "payload": {}, "message": "Cópia de versão mais nova preservada."}
		if fallback.status == "ok":
			return {"status": "recovered", "payload": fallback.payload,
				"message": "Sessão recuperada pela cópia de segurança."}
	var status: String = primary.status
	if status == "missing" and (FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp")):
		status = "corrupt"
	return {"status": status, "payload": {}, "message": "Nenhuma sessão salva." if status == "missing" else "Save ilegível; original preservado para diagnóstico."}

func save(payload: Dictionary) -> bool:
	last_error = ""
	if _future_version or _read(path).status == "future_version":
		last_error = "Não é seguro sobrescrever um save de versão mais nova."
		return false
	var serialized := JSON.stringify(payload)
	var envelope := JSON.stringify({"format": FORMAT_VERSION, "payload_json": serialized, "sha256": serialized.sha256_text()})
	if envelope.to_utf8_buffer().size() > MAX_FILE_BYTES:
		last_error = "Save excedeu o limite de 4 MiB."
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Não foi possível abrir o diretório de salvamento."
		return false
	var temporary := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if temporary == null:
		last_error = "Falha ao criar o arquivo temporário."
		return false
	temporary.store_string(envelope)
	temporary.flush()
	var write_error := temporary.get_error()
	temporary.close()
	if write_error != OK or _read(path + ".tmp").status != "ok":
		last_error = "Falha ao verificar a gravação temporária."
		return false
	if FileAccess.file_exists(path):
		var suffix := ".bak" if _read(path).status == "ok" else ".corrupt"
		if FileAccess.file_exists(path + suffix):
			if DirAccess.remove_absolute(absolute + suffix) != OK:
				last_error = "Falha ao substituir a cópia anterior."
				return false
		if DirAccess.rename_absolute(absolute, absolute + suffix) != OK:
			last_error = "Falha ao preservar a sessão anterior."
			return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		last_error = "Falha ao finalizar o save; cópia anterior preservada."
		return false
	return true

func archive_for_new_game() -> bool:
	## Call only after the player deliberately confirms a new expedition.
	## Even unknown newer formats are archived, never reinterpreted or deleted.
	last_error = ""
	var stamp := "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if not FileAccess.file_exists(path + suffix):
			continue
		var source := ProjectSettings.globalize_path(path + suffix)
		var target := ProjectSettings.globalize_path(path + ".archive-" + stamp + suffix)
		if DirAccess.rename_absolute(source, target) != OK:
			last_error = "Não foi possível arquivar a sessão anterior; nova expedição cancelada."
			return false
	_future_version = false
	return true

extends SceneTree
const EngineScript = preload("res://scripts/core/rpg_engine.gd")
const StoreScript = preload("res://scripts/core/save_store.gd")
const IdleClock = preload("res://scripts/platform/idle_clock.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS · " + description)
	else:
		failed += 1
		push_error("FAIL · " + description)

func _run() -> void:
	_test_progression()
	_test_replay()
	_test_inventory_and_quests()
	_test_validation()
	_test_persistence()
	_test_clock()
	print("CORE TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_progression() -> void:
	for class_id in ["warrior", "archer", "mage", "healer"]:
		var game = EngineScript.new()
		game.new_game(class_id)
		var report: Dictionary = game.advance(600)
		_check(game.state.class_id == class_id, "classe " + class_id)
		_check(report.kills > 10 and game.state.level > 1, "combate/progressão " + class_id)
		_check(game.state.boss_kills > 0, "chefe vencível " + class_id)
		_check(game.state.hp >= 0 and game.state.hp <= game.snapshot().max_hp, "vida limitada " + class_id)
		_check(game.state.inventory.size() <= EngineScript.MAX_INVENTORY, "mochila limitada " + class_id)
		var copy = EngineScript.new()
		_check(copy.load_state(game.state), "estado gerado válido " + class_id)
		game.advance(7200)
		_check(copy.load_state(JSON.parse_string(JSON.stringify(game.state))), "roundtrip após 2 horas " + class_id)
	var bounded = EngineScript.new()
	bounded.new_game("warrior")
	_check(bounded.advance(-8).seconds == 0 and bounded.state.tick == 0, "tempo negativo não retrocede")
	var report: Dictionary = bounded.advance(9999999)
	_check(report.seconds == 7200 and bounded.state.tick == 7200 and report.capped, "idle limitado a duas horas")
	var lethal = EngineScript.new()
	lethal.new_game("mage")
	lethal.tick()
	lethal.tick()
	lethal.state.hp = 1
	lethal.state.enemy.hp = 9999
	lethal.state.enemy.attack = 9999
	lethal.tick()
	_check(lethal.state.phase == "defeat", "transição de derrota")
	lethal.advance(4)
	_check(lethal.state.phase == "exploration" and lethal.state.hp == lethal.snapshot().max_hp, "recuperação após derrota")

func _test_replay() -> void:
	var direct = EngineScript.new()
	direct.new_game("archer")
	var baseline: Dictionary = direct.state.duplicate(true)
	var frames: Array = direct.preview(300)
	_check(direct.state == baseline, "preview não modifica autoridade")
	_check(frames.size() == 301 and frames[0] == direct.snapshot(), "preview contém quadro inicial")
	var same := true
	for second in range(1, frames.size()):
		direct.tick()
		if direct.snapshot() != frames[second]:
			same = false
	_check(same, "301 snapshots do overlay equivalem ao combate real")
	var resumed = EngineScript.new()
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(baseline))
	_check(resumed.load_state(round_trip), "desserialização JSON aceita inteiros como floats")
	resumed.advance(300)
	_check(resumed.state == direct.state, "replay após persistência é idêntico")
	var batch = EngineScript.new()
	batch.new_game("archer")
	batch.advance(137)
	batch.advance(163)
	_check(batch.state == direct.state, "particionar o tempo não altera RNG/resultado")

func _test_inventory_and_quests() -> void:
	var game = EngineScript.new()
	game.new_game("healer")
	_check(not game.claim_quest("first_watch"), "missão não pode ser coletada cedo")
	_check(not game.equip_item("missing"), "equipamento inexistente rejeitado")
	_check(not game.train(), "treino exige sementes")
	game.advance(400)
	_check(game.inventory().size() > 0, "combate produz equipamentos")
	var item: Dictionary = game.inventory()[0]
	_check(game.equip_item(item.id), "item existente pode ser equipado")
	_check(not game.sell_item(item.id), "item equipado não pode ser vendido")
	var attack_before: int = game.snapshot().attack
	var gold_before: int = game.state.gold
	var cost: int = game.training_cost()
	_check(game.train() and game.snapshot().attack == attack_before + 1 and game.state.gold == gold_before - cost, "treino debita custo e aumenta atributo")
	_check(game.claim_quest("first_watch"), "missão pronta concede recompensa")
	var after_claim: Dictionary = game.state.duplicate(true)
	_check(not game.claim_quest("first_watch") and game.state == after_claim, "recompensa não pode ser duplicada")
	game.advance(7200)
	_check(game.inventory().size() <= 30, "overflow de loot convertido sem crescer save")

func _test_validation() -> void:
	var game = EngineScript.new()
	game.new_game("warrior")
	var pristine: Dictionary = game.state.duplicate(true)
	for key in ["version", "level", "stage", "seed", "hp"]:
		var bad: Dictionary = pristine.duplicate(true)
		bad[key] = -500
		_check(not game.load_state(bad) and game.state == pristine, "save inválido não altera estado: " + key)
	for key in ["version", "event", "enemy", "inventory", "settings"]:
		var missing: Dictionary = pristine.duplicate(true)
		missing.erase(key)
		_check(not game.load_state(missing), "chave obrigatória ausente rejeitada: " + key)
	var malformed_version: Dictionary = pristine.duplicate(true)
	malformed_version.version = {"wrong": 1}
	_check(not game.load_state(malformed_version), "versão malformada não causa conversão insegura")
	var future: Dictionary = pristine.duplicate(true)
	future.version = 999
	_check(not game.load_state(future), "schema futuro não é reinterpretado")
	var invalid_class: Dictionary = pristine.duplicate(true)
	invalid_class.class_id = "unknown"
	_check(not game.load_state(invalid_class), "classe inválida rejeitada")
	var malformed: Dictionary = pristine.duplicate(true)
	malformed.inventory = ["invalid"]
	_check(not game.load_state(malformed), "item malformado rejeitado")
	for setting in ["sound", "battery_saver", "tutorial_seen"]:
		var wrong_setting: Dictionary = pristine.duplicate(true)
		wrong_setting.settings[setting] = "yes"
		_check(not game.load_state(wrong_setting), "setting malformado rejeitado: " + setting)
	var wrong_quest: Dictionary = pristine.duplicate(true)
	wrong_quest.claimed_quests = [123]
	_check(not game.load_state(wrong_quest), "missão malformada rejeitada")
	var bad_equipment: Dictionary = pristine.duplicate(true)
	bad_equipment.equipment = {"weapon": "missing"}
	_check(not game.load_state(bad_equipment), "referência de equipamento inválida rejeitada")

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func _test_persistence() -> void:
	var path := "user://tests/core_session.json"
	_cleanup(path)
	var store = StoreScript.new(path)
	_check(store.load_save().status == "missing", "primeira execução sem save")
	var payload := {"game": {"gold": 12}, "clock": {"wall": 123}}
	_check(store.save(payload), "save gravado e verificado")
	var loaded: Dictionary = store.load_save()
	_check(loaded.status == "ok" and loaded.payload.game.gold == 12 and loaded.payload.clock.wall == 123, "checksum e roundtrip persistente")
	_check(store.save({"game": {"gold": 99}}), "segundo save cria backup")
	_write(path, "{truncated")
	loaded = store.load_save()
	_check(loaded.status == "recovered" and loaded.payload.game.gold == 12 and loaded.payload.clock.wall == 123, "save truncado recupera backup")
	_check(store.save(payload) and FileAccess.file_exists(path + ".corrupt"), "save corrompido preservado antes de nova gravação")
	_cleanup(path)
	_check(store.save(payload), "gravação para teste de integridade")
	var serialized: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	serialized.payload_json = JSON.stringify({"game": {"gold": 99999}})
	_write(path, JSON.stringify(serialized))
	_check(store.load_save().status == "corrupt", "alteração de payload detectada por hash")
	_cleanup(path)
	_write(path, JSON.stringify({"format": 99}))
	_check(store.load_save().status == "future_version" and not store.save(payload), "formato futuro preservado e somente leitura")
	_check(store.archive_for_new_game() and not FileAccess.file_exists(path), "reset explícito arquiva formato futuro")
	_check(store.save(payload), "nova expedição pode salvar após arquivamento explícito")
	var archive_found := false
	for name in DirAccess.get_files_at("user://tests"):
		if name.begins_with("core_session.json.archive-"):
			archive_found = archive_found or JSON.parse_string(FileAccess.get_file_as_string("user://tests/" + name)).get("format") == 99
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tests/" + name))
	_check(archive_found, "arquivo futuro arquivado permanece íntegro")
	_cleanup(path)
	# Recovery after interruption between rotation and final rename.
	var fresh = StoreScript.new(path)
	_check(fresh.save(payload), "novo objeto de store não mantém bloqueio antigo")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".tmp"))
	_check(fresh.load_save().status == "recovered", "temporário íntegro recupera gravação interrompida")
	_cleanup(path)

func _test_clock() -> void:
	var before := {"wall": 10000, "mono": 100.25, "boot": "boot-a"}
	var after := {"wall": 500, "mono": 110.75, "boot": "boot-a"}
	var result: Dictionary = IdleClock.elapsed(before, after)
	_check(result.seconds == 10 and result.source == "monotonic" and not result.clamped, "relógio monotônico ignora mudança de hora")
	after = {"wall": 100000, "mono": 2.0, "boot": "boot-b"}
	result = IdleClock.elapsed(before, after)
	_check(result.seconds == 7200 and result.source == "wall_bounded" and result.clamped, "reboot usa relógio civil limitado a 2 horas")
	after.wall = 500
	result = IdleClock.elapsed(before, after)
	_check(result.seconds == 0 and result.clamped, "relógio civil regressivo não concede progresso")
	after = {"wall": 10000, "mono": 10.0, "boot": "boot-a"}
	result = IdleClock.elapsed(before, after)
	_check(result.seconds == 0 and result.clamped, "âncora monotônica regressiva é descartada")
	_check(IdleClock.elapsed({}, after).seconds == 0, "âncora ausente não inventa progresso")
	for value in [null, "not-a-time", [], {}, true, INF, NAN]:
		var malformed: Dictionary = before.duplicate()
		malformed.mono = value
		result = IdleClock.elapsed(malformed, after)
		_check(result.seconds == 0 and result.source == "missing", "timestamp malformado seguro: " + str(value))
	var bad_boot := {"wall": 10000, "mono": 0.0, "boot": {"invalid": 1}}
	_check(IdleClock.elapsed(before, bad_boot).source == "missing", "identificador de boot malformado rejeitado")

	var empty_boot := {"wall": 10000, "mono": 110.0, "boot": ""}
	_check(IdleClock.elapsed(empty_boot, empty_boot).source == "missing", "boot vazio não é autoridade monotônica")

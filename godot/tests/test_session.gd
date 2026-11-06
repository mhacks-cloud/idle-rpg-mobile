extends SceneTree
## Integration tests for the actual Session autoload with deterministic platform I/O.
## Native WindowManager/service behavior still requires the Android device checklist.
const EngineModel = preload("res://scripts/core/rpg_engine.gd")
const Store = preload("res://scripts/core/save_store.gd")
const TEST_PATH := "user://tests/integration_session.json"
var passed := 0
var failed := 0
var session: Node
var platform: FakeBridge

class FakeBridge extends RefCounted:
	var now := {"wall": 100000.0, "mono": 100.0, "boot": "integration-boot"}
	var permission := true
	var supported := true
	var permission_requests := 0
	var starts := 0
	var stops := 0
	var received: Dictionary = {}
	var current_status := {"state": "idle", "message": ""}
	func clock_now() -> Dictionary:
		return now.duplicate(true)
	func available() -> bool:
		return supported
	func can_overlay() -> bool:
		return permission
	func request_permission() -> void:
		permission_requests += 1
	func start_overlay(payload: Dictionary) -> void:
		starts += 1
		received = payload.duplicate(true)
		current_status = {"state": "active", "message": "Vigília flutuante"}
	func stop_overlay() -> void:
		stops += 1
		current_status = {"state": "idle", "message": "Fechada"}
	func status() -> Dictionary:
		return current_status.duplicate()
	func elapse(seconds: float) -> void:
		now.mono += seconds
		now.wall += seconds

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS · " + description)
	else:
		failed += 1
		push_error("FAIL · " + description)

func _clean_files() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://tests")):
		return
	for name in DirAccess.get_files_at("user://tests"):
		if name.begins_with("integration_session.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tests/" + name))

func _reset() -> void:
	_clean_files()
	platform = FakeBridge.new()
	session.bridge = platform
	session.store = Store.new(TEST_PATH)
	session.game.new_game("warrior")
	session.anchor = platform.clock_now()
	session.suspended = false
	session.awaiting_overlay = false
	session.save_locked = false
	session.last_save = 0

func _run() -> void:
	session = root.get_node_or_null("Session")
	_check(session != null, "autoload Session real está disponível")
	if session == null:
		quit(1)
		return
	session.timer.stop()
	_reset()
	_test_clock_and_lifecycle()
	_reset()
	_test_overlay_checkpoint()
	_reset()
	_test_overlay_errors_and_consent()
	_reset()
	_test_mutation_guards()
	_reset()
	_test_settings_and_new_game()
	_clean_files()
	# Prevent a lifecycle notification during shutdown from recreating the fixture.
	session.save_locked = true
	session.suspended = true
	print("SESSION TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_clock_and_lifecycle() -> void:
	platform.elapse(0.4)
	session._pulse()
	_check(session.game.state.tick == 0, "pulso fracionário não adianta combate")
	platform.elapse(0.8)
	session._pulse()
	_check(session.game.state.tick == 1 and is_equal_approx(float(session.anchor.mono), 101.0), "pulso preserva fração para próximo segundo")
	for _repeat in range(8):
		session._pulse()
	_check(session.game.state.tick == 1, "pulsos repetidos no mesmo instante não duplicam progresso")
	platform.elapse(2.2)
	session._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(session.suspended and session.game.state.tick == 3, "pause salva todos os segundos anteriores")
	var saved: Dictionary = session.store.load_save()
	_check(saved.status == "ok" and saved.payload.game.tick == 3, "checkpoint de pausa contém estado e âncora compatíveis")
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	platform.elapse(20.0)
	session._pulse()
	_check(session.game.state.tick == 3, "pulso suspenso não executa combate paralelo")
	session._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var expected = EngineModel.new()
	expected.new_game("warrior")
	expected.advance(23)
	_check(not session.suspended and session.game.state == expected.state, "retomada aplica exatamente os segundos pendentes")
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	session._pulse()
	_check(session.game.state == expected.state, "resume/focus duplicados não recompensam duas vezes")
	_check(platform.stops == 1, "retomada encerra overlay antes de mutações")

func _test_overlay_checkpoint() -> void:
	platform.elapse(12.4)
	session._pulse()
	var initial: Dictionary = session.game.state.duplicate(true)
	session.request_overlay()
	_check(platform.starts == 1 and session.suspended and session.awaiting_overlay, "solicitação cria somente uma apresentação de overlay")
	_check(session.game.state == initial, "gerar projeção não adianta o estado autoritativo")
	_check(platform.received.frames.size() == 301 and platform.received.frames[0] == session.game.snapshot(), "overlay recebe 301 quadros desde o checkpoint exato")
	var saved: Dictionary = session.store.load_save()
	var restored = EngineModel.new()
	_check(saved.status == "ok" and restored.load_state(saved.payload.game) and restored.state == initial, "checkpoint gravado precede a projeção sem premiar futuro")
	platform.elapse(17.0)
	session._pulse()
	_check(session.game.state == initial, "overlay ativo mantém autoridade suspensa")
	var training_before: Dictionary = session.game.state.duplicate(true)
	session.game.state.gold = 500
	training_before = session.game.state.duplicate(true)
	session.train()
	_check(session.game.state == training_before, "ação de treino bloqueada enquanto overlay está ativo")
	# Restore fixture after probing a UI guard; this is not a production mutation.
	session.game.state = initial.duplicate(true)
	session._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	restored.advance(17)
	_check(session.game.state == restored.state, "retorno da janela reconcilia a mesma simulação do checkpoint")
	_check(session.game.snapshot() == platform.received.frames[17], "tela completa coincide com quadro 17 apresentado no overlay")
	_check(not session.awaiting_overlay and not session.suspended and platform.stops == 1, "overlay é encerrado e controles ficam ativos na retomada")

func _test_overlay_errors_and_consent() -> void:
	platform.permission = false
	session.request_overlay()
	_check(platform.permission_requests == 1 and platform.starts == 0, "sem consentimento abre somente pedido de permissão")
	_check(not session.suspended and not session.awaiting_overlay, "negar overlay preserva modo tela completa")
	platform.permission = true
	session.save_locked = true
	session.request_overlay()
	_check(platform.starts == 0, "falha de persistência impede overlay sem checkpoint seguro")
	session.save_locked = false
	session.request_overlay()
	platform.current_status = {"state": "error", "message": "Serviço recusado pelo sistema"}
	platform.elapse(4.0)
	session._pulse()
	_check(not session.suspended and not session.awaiting_overlay and session.game.state.tick == 4, "falha do serviço retoma e reconcilia tela completa")
	_check(session.notice == "Serviço recusado pelo sistema", "erro nativo é apresentado ao jogador")
	platform.supported = false
	var starts_before: int = platform.starts
	session.request_overlay()
	_check(platform.starts == starts_before and not session.suspended, "plataforma sem overlay usa fallback de tela completa")

func _test_mutation_guards() -> void:
	# A progressed fixture makes every guarded action genuinely actionable.
	platform.elapse(600)
	session._pulse()
	var item_id := ""
	for item in session.game.inventory():
		if not item.equipped:
			item_id = str(item.id)
			break
	var quest_id := ""
	for quest in session.game.quests():
		if quest.ready:
			quest_id = str(quest.id)
			break
	_check(not item_id.is_empty() and not quest_id.is_empty(), "fixture tem equipamento alternativo e missão resgatável")
	if item_id.is_empty() or quest_id.is_empty():
		return
	var before: Dictionary = session.game.state.duplicate(true)
	session.request_overlay()
	session.equip(item_id)
	_check(session.game.state == before, "equipar bloqueado durante projeção ativa")
	session.sell(item_id)
	_check(session.game.state == before, "vender bloqueado durante projeção ativa")
	session.claim(quest_id)
	_check(session.game.state == before, "resgatar missão bloqueado durante projeção ativa")
	session.set_option("sound", false)
	_check(session.game.state == before, "configuração bloqueada durante projeção ativa")
	session.start_new("healer")
	_check(session.game.state == before, "nova expedição bloqueada durante projeção ativa")
	session.request_overlay()
	_check(platform.starts == 1, "toques repetidos não criam outra projeção")
	session._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	session.equip(item_id)
	_check(session.game.state != before, "equipar volta a funcionar após retomada")
	session.claim(quest_id)
	_check(session.game.state.claimed_quests.has(quest_id), "missões voltam a funcionar após retomada")
	var saved: Dictionary = session.store.load_save()
	_check(saved.status == "ok" and saved.payload.game.claimed_quests.has(quest_id), "mutações após retomada são persistidas")

func _test_settings_and_new_game() -> void:
	session.set_option("sound", false)
	session.set_option("battery_saver", true)
	var saved: Dictionary = session.store.load_save()
	_check(saved.payload.game.settings.sound == false and saved.payload.game.settings.battery_saver == true, "configurações persistem no mesmo save da expedição")
	_check(Engine.max_fps == 15, "economia de bateria limita renderização")
	platform.elapse(10)
	session._pulse()
	session.save_now()
	var old_tick: int = session.game.state.tick
	session.start_new("mage")
	_check(session.game.state.class_id == "mage" and session.game.state.tick == 0, "nova expedição reinicia classe e autoridade")
	_check(session.game.state.settings.tutorial_seen and not session.save_locked, "nova expedição confirma tutorial e libera persistência")
	_check(Engine.max_fps == 30 and not session.game.state.settings.battery_saver, "nova expedição aplica limite de FPS das opções reiniciadas")
	var archive_found := false
	for name in DirAccess.get_files_at("user://tests"):
		if name.begins_with("integration_session.json.archive-") and not name.ends_with(".bak"):
			var archived = Store.new("user://tests/" + name)
			var old: Dictionary = archived.load_save()
			archive_found = archive_found or (old.status == "ok" and old.payload.game.tick == old_tick)
	_check(archive_found, "novo jogo arquiva sessão anterior sem apagar progresso")
	saved = session.store.load_save()
	_check(saved.status == "ok" and saved.payload.game.class_id == "mage" and saved.payload.game.tick == 0, "nova classe e relógio são persistidos juntos")
	_check(saved.payload.clock.mono == platform.now.mono, "novo jogo redefine âncora sem herdar tempo anterior")

extends Node
## The only mutable game authority. Android receives read-only projected frames.
signal updated
signal notice_changed(message: String)
const EngineModel = preload("res://scripts/core/rpg_engine.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Bridge = preload("res://scripts/platform/platform_bridge.gd")
const IdleClock = preload("res://scripts/platform/idle_clock.gd")
var game = EngineModel.new()
var store = Store.new()
var bridge = Bridge.new()
var anchor: Dictionary
var suspended := false
var save_locked := false
var notice := "A fogueira está acesa. Sua expedição começa aqui."
var last_save := 0
var timer: Timer
var awaiting_overlay := false

func _ready() -> void:
	game.new_game("warrior")
	anchor = bridge.clock_now()
	var loaded: Dictionary = store.load_save()
	if loaded.status in ["ok", "recovered"]:
		var payload: Dictionary = loaded.payload
		if payload.get("game") is Dictionary and game.load_state(payload.game):
			anchor = payload.clock if payload.get("clock") is Dictionary else anchor
			_settle(true)
			if loaded.status == "recovered":
				set_notice("Save principal danificado: backup recuperado.")
		else:
			save_locked = true
			set_notice("Save incompatível. Uma nova expedição pode ser iniciada em Ajustes.")
	elif loaded.status != "missing":
		save_locked = true
		set_notice(str(loaded.get("message", "Save indisponível; gravação automática protegida.")))
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_pulse)
	add_child(timer)
	timer.start()
	get_tree().auto_accept_quit = false
	Engine.max_fps = 15 if game.state.settings.get("battery_saver", false) else 30

func _pulse() -> void:
	var status: Dictionary = bridge.status()
	if awaiting_overlay:
		if status.get("state") in ["active", "starting"]:
			return
		awaiting_overlay = false
		suspended = false
		set_notice(str(status.get("message", "Expedição retomada.")))
	if suspended:
		return
	_settle(false)
	last_save += 1
	if last_save >= 15:
		save_now()
		last_save = 0

func _settle(report: bool) -> void:
	var now: Dictionary = bridge.clock_now()
	var delta: Dictionary = IdleClock.elapsed(anchor, now)
	var seconds := int(delta.seconds)
	if seconds > 0:
		game.advance(seconds)
		# Preserve fractions during ordinary ticks; re-anchor capped/reboot catch-up.
		if delta.source == "monotonic" and not delta.clamped:
			anchor.mono = float(anchor.mono) + seconds
			anchor.wall = float(anchor.wall) + seconds
		else:
			anchor = now
		if report and seconds >= 3:
			set_notice("Expedição recuperada: %d s de progresso (%s)." % [seconds, "máximo de 2 h" if delta.clamped else "tempo verificado"])
	elif delta.clamped or delta.source != "monotonic":
		anchor = now
	updated.emit()

func save_now() -> bool:
	if save_locked:
		return false
	var ok: bool = store.save({"game": game.state, "clock": anchor})
	if not ok:
		set_notice("Não foi possível salvar. Seu progresso continua em memória; tente novamente.")
	return ok

func start_new(class_id: String) -> void:
	if awaiting_overlay:
		return
	if not store.archive_for_new_game():
		set_notice("Não foi possível preservar o save antigo. A expedição atual foi mantida.")
		return
	bridge.stop_overlay()
	awaiting_overlay = false
	suspended = false
	save_locked = false
	game.new_game(class_id)
	Engine.max_fps = 30
	game.state.settings.tutorial_seen = true
	anchor = bridge.clock_now()
	save_now()
	set_notice("Nova vigília: %s. O combate é automático." % game.snapshot().class_name)
	updated.emit()

func train() -> void:
	if suspended or awaiting_overlay:
		return
	if game.train():
		set_notice("Treino concluído. Você ficou mais forte!")
		save_now()
	else:
		set_notice("Junte mais moedas para treinar.")
	updated.emit()

func equip(item_id: String) -> void:
	if suspended or awaiting_overlay:
		return
	if game.equip_item(item_id):
		set_notice("Equipamento atualizado.")
		save_now()
	updated.emit()

func sell(item_id: String) -> void:
	if suspended or awaiting_overlay:
		return
	if game.sell_item(item_id):
		save_now()
		updated.emit()

func claim(quest_id: String) -> void:
	if suspended or awaiting_overlay:
		return
	if game.claim_quest(quest_id):
		set_notice("Missão concluída! Recompensa recebida.")
		save_now()
	updated.emit()

func set_option(key: String, enabled: bool) -> void:
	if suspended or awaiting_overlay:
		return
	game.state.settings[key] = enabled
	Engine.max_fps = 15 if game.state.settings.get("battery_saver", false) else 30
	save_now()
	updated.emit()

func request_overlay() -> void:
	if suspended or awaiting_overlay:
		return
	if not bridge.available():
		set_notice("No computador, use a janela normal. O overlay precisa do aplicativo Android.")
		return
	if not bridge.can_overlay():
		set_notice("Autorize a sobreposição na tela do Android. Depois toque novamente em Janela flutuante.")
		bridge.request_permission()
		return
	_settle(false)
	if not save_now():
		set_notice("Salve a sessão antes de abrir a janela flutuante.")
		return
	var frames: Array = game.preview(300)
	awaiting_overlay = true
	suspended = true
	bridge.start_overlay({"version": 1, "clock": anchor, "frames": frames, "duration": 300})
	set_notice("Abrindo uma vigília flutuante de até 5 minutos…")

func set_notice(message: String) -> void:
	notice = message
	notice_changed.emit(message)

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if not suspended:
			_settle(false)
			save_now()
		suspended = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		# Always close the read-only overlay before allowing mutations in full screen.
		if suspended:
			bridge.stop_overlay()
			awaiting_overlay = false
			suspended = false
			_settle(true)
			save_now()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not suspended:
			_settle(false)
		save_now()
		get_tree().quit()

extends Control
const Battle = preload("res://scripts/presentation/battle_view.gd")
const MINT := Color("99e1ba")
const MUTED := Color("91aaa5")
const GOLD := Color("f3ce8d")
var layout: BoxContainer
var combat_column: VBoxContainer
var tabs: TabContainer
var battle: Control
var stage_label: Label
var phase_label: Label
var hero_label: Label
var enemy_label: Label
var hero_bar: ProgressBar
var enemy_bar: ProgressBar
var xp_bar: ProgressBar
var stats_label: Label
var skill_label: Label
var event_label: Label
var wallet: Label
var notice_label: Label
var training_button: Button
var inventory_list: VBoxContainer
var quests_list: VBoxContainer
var sound: CheckButton
var saver: CheckButton
var overlay_button: Button
var tutorial: AcceptDialog
var reset_dialog: ConfirmationDialog
var selected_class := "warrior"
var last_inventory := ""
var last_quests := ""
var last_tick := -1
var player: AudioStreamPlayer
var margin: MarginContainer

func _ready() -> void:
	_build_theme()
	_build_ui()
	Session.updated.connect(_refresh)
	Session.notice_changed.connect(func(message: String): notice_label.text = message)
	resized.connect(_adapt)
	_refresh()
	_adapt()
	if not Session.game.state.settings.get("tutorial_seen", false):
		call_deferred("_show_tutorial")
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _style(color: Color, border := Color("2c4543")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("e2eee4"))
	theme.set_color("font_color", "Button", Color("e2eee4"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_stylebox("normal", "Button", _style(Color("203934")))
	theme.set_stylebox("hover", "Button", _style(Color("305448"), MINT))
	theme.set_stylebox("pressed", "Button", _style(Color("163029"), MINT))
	theme.set_stylebox("disabled", "Button", _style(Color("172727")))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD))
	theme.set_stylebox("panel", "PanelContainer", _style(Color("142624")))
	theme.set_stylebox("panel", "TabContainer", _style(Color("142624")))
	theme.set_stylebox("tab_selected", "TabContainer", _style(Color("27453a")))
	theme.set_stylebox("tab_unselected", "TabContainer", _style(Color("101e20")))
	theme.set_stylebox("background", "ProgressBar", _style(Color("0c191c")))
	theme.set_stylebox("fill", "ProgressBar", _style(MINT, MINT))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)

func _label(text: String, font_size := 15, color := Color("e2eee4")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func _wrapped(text: String, font_size := 14, color := MUTED) -> Label:
	var result := _label(text, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	return result

func _bar(color: Color) -> ProgressBar:
	var result := ProgressBar.new()
	result.custom_minimum_size.y = 9
	result.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0c191c")
	bg.set_corner_radius_all(3)
	result.add_theme_stylebox_override("fill", fill)
	result.add_theme_stylebox_override("background", bg)
	return result

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b151b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var wordmark := VBoxContainer.new()
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wordmark.add_theme_constant_override("separation", 0)
	header.add_child(wordmark)
	wordmark.add_child(_label("VIGÍLIA DO MUSGO", 24, MINT))
	wordmark.add_child(_label("Pequenas jornadas. Raízes profundas.", 12, MUTED))
	wallet = _label("0\nsementes", 14, GOLD)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(wallet)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	layout = BoxContainer.new()
	layout.vertical = true
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	scroll.add_child(layout)
	combat_column = VBoxContainer.new()
	combat_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(combat_column)
	var area := HBoxContainer.new()
	combat_column.add_child(area)
	stage_label = _label("01 / BOSQUE DAS LUZES", 13, GOLD)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(stage_label)
	phase_label = _label("EXPLORANDO", 11, MINT)
	area.add_child(phase_label)
	var arena := PanelContainer.new()
	combat_column.add_child(arena)
	battle = Battle.new()
	battle.custom_minimum_size = Vector2(0, 225)
	arena.add_child(battle)
	event_label = _wrapped("", 14, GOLD)
	event_label.custom_minimum_size.y = 38
	combat_column.add_child(event_label)
	var vitals := HBoxContainer.new()
	combat_column.add_child(vitals)
	var hero := VBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals.add_child(hero)
	hero_label = _wrapped("", 13, Color("e2eee4"))
	hero.add_child(hero_label)
	hero_bar = _bar(MINT)
	hero.add_child(hero_bar)
	var enemy := VBoxContainer.new()
	enemy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals.add_child(enemy)
	enemy_label = _wrapped("", 13, Color("e2eee4"))
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy.add_child(enemy_label)
	enemy_bar = _bar(Color("df9d8d"))
	enemy.add_child(enemy_bar)
	xp_bar = _bar(Color("b6a4e2"))
	combat_column.add_child(xp_bar)
	stats_label = _label("", 13, MUTED)
	combat_column.add_child(stats_label)
	skill_label = _wrapped("", 13, MINT)
	combat_column.add_child(skill_label)
	training_button = _button("Treinar", Session.train)
	combat_column.add_child(training_button)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(0, 280)
	layout.add_child(tabs)
	inventory_list = VBoxContainer.new()
	inventory_list.name = "Bolsa"
	tabs.add_child(inventory_list)
	quests_list = VBoxContainer.new()
	quests_list.name = "Missões"
	tabs.add_child(quests_list)
	var settings := VBoxContainer.new()
	settings.name = "Ajustes"
	tabs.add_child(settings)
	sound = CheckButton.new()
	sound.text = "Sons da expedição"
	sound.custom_minimum_size.y = 44
	sound.toggled.connect(func(value: bool): Session.set_option("sound", value))
	settings.add_child(sound)
	saver = CheckButton.new()
	saver.text = "Economia de bateria"
	saver.custom_minimum_size.y = 44
	saver.toggled.connect(func(value: bool): Session.set_option("battery_saver", value))
	settings.add_child(saver)
	settings.add_child(_wrapped("Salva a cada 15 segundos. Fora do jogo, sua expedição avança por até 2 horas. A janela flutuante dura até 5 minutos."))
	settings.add_child(_button("Como jogar / escolher classe", _show_tutorial))
	settings.add_child(_button("Salvar agora", func():
		if Session.save_now():
			Session.set_notice("Expedição salva neste dispositivo.")))
	var bottom := PanelContainer.new()
	root.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom.add_child(bottom_box)
	overlay_button = _button("↗  Janela flutuante", Session.request_overlay)
	bottom_box.add_child(overlay_button)
	notice_label = _wrapped(Session.notice, 12)
	notice_label.custom_minimum_size.y = 32
	bottom_box.add_child(notice_label)
	player = AudioStreamPlayer.new()
	player.volume_db = -16
	add_child(player)
	_build_dialogs()

func _build_dialogs() -> void:
	tutorial = AcceptDialog.new()
	tutorial.title = "Boas-vindas à vigília"
	tutorial.ok_button_text = "Continuar expedição"
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 310
	tutorial.add_child(box)
	box.add_child(_wrapped("Acompanhe um guardião pelo Bosque das Luzes. Ele luta e usa sua habilidade sozinho. Equipe os achados da Bolsa, resgate Missões e treine com sementes.", 15))
	box.add_child(_wrapped("Dez encontros levam ao Guardião das Raízes. A derrota leva você de volta ao abrigo; equipamentos são preservados. O bosque fica mais forte a cada volta.", 14))
	box.add_child(_label("ESCOLHA UMA NOVA EXPEDIÇÃO", 12, GOLD))
	for definition in Session.game.classes():
		var id := str(definition.id)
		var b := _button(str(definition.name) + " · " + str(definition.skill), func(): _confirm_class(id))
		b.tooltip_text = str(definition.description)
		box.add_child(b)
	box.add_child(_wrapped("O overlay pede autorização do Android, mostra uma única expedição e pode ser fechado a qualquer momento. Sem autorização, continue em tela completa.", 12))
	tutorial.confirmed.connect(func():
		Session.game.state.settings.tutorial_seen = true
		Session.save_now())
	add_child(tutorial)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Começar de novo?"
	reset_dialog.dialog_text = "Isso substitui a expedição e seu save local.\nEscolha Cancelar para manter seu progresso."
	reset_dialog.ok_button_text = "Iniciar nova expedição"
	reset_dialog.cancel_button_text = "Cancelar"
	reset_dialog.confirmed.connect(func():
		Session.start_new(selected_class)
		tutorial.hide())
	add_child(reset_dialog)

func _confirm_class(id: String) -> void:
	selected_class = id
	if int(Session.game.state.tick) < 5 and not Session.game.state.settings.get("tutorial_seen", false):
		Session.start_new(id)
		tutorial.hide()
	else:
		reset_dialog.popup_centered(Vector2i(340, 160))

func _show_tutorial() -> void:
	tutorial.popup_centered(Vector2i(mini(430, int(size.x) - 24), 520))

func _adapt() -> void:
	if not layout:
		return
	var wide := size.x >= 760
	layout.vertical = not wide
	combat_column.size_flags_stretch_ratio = 1.3
	tabs.size_flags_stretch_ratio = 1.0
	battle.custom_minimum_size.y = 245 if wide else 205
	# Native host handles system bar insets; desktop uses these same comfortable margins.

func _refresh() -> void:
	if not battle:
		return
	var s: Dictionary = Session.game.snapshot()
	battle.display(s)
	wallet.text = "%d\nsementes" % int(s.gold)
	stage_label.text = "BOSQUE DAS LUZES · %02d/11" % int(s.stage)
	phase_label.text = {"exploration": "EXPLORANDO", "combat": "COMBATE", "victory": "VITÓRIA", "defeat": "ABRIGO"}.get(s.phase, "")
	hero_label.text = "%s · Nv.%d · %d/%d" % [s.class_name, s.level, s.hp, s.max_hp]
	enemy_label.text = str(s.enemy_name) if s.enemy_hp > 0 else "Trilha livre"
	hero_bar.max_value = s.max_hp
	hero_bar.value = s.hp
	enemy_bar.max_value = maxi(1, int(s.enemy_max_hp))
	enemy_bar.value = s.enemy_hp
	xp_bar.max_value = s.xp_next
	xp_bar.value = s.xp
	stats_label.text = "ATQ %d   DEF %d   •   XP %d/%d   •   Volta %d" % [s.attack, s.defense, s.xp, s.xp_next, s.cycle]
	skill_label.text = "%s  ·  %s" % [s.skill_name, "ativada!" if s.get("skill_flash", false) else "recarga %ds" % int(s.skill_cooldown)]
	event_label.text = s.event
	training_button.text = "Treinar +1 ATQ · %d sementes" % Session.game.training_cost()
	sound.set_pressed_no_signal(Session.game.state.settings.get("sound", true))
	saver.set_pressed_no_signal(Session.game.state.settings.get("battery_saver", false))
	if int(s.tick) != last_tick and not Session.suspended and sound.button_pressed:
		var audio_path := "res://assets/victory.wav" if s.phase == "victory" else "res://assets/attack.wav"
		if s.phase in ["victory", "combat"] and ResourceLoader.exists(audio_path):
			player.stream = load(audio_path)
			player.play()
	last_tick = int(s.tick)
	var items: Array = Session.game.inventory()
	var fingerprint := JSON.stringify(items)
	if fingerprint != last_inventory:
		last_inventory = fingerprint
		_update_inventory(items)
	var quests: Array = Session.game.quests()
	fingerprint = JSON.stringify(quests)
	if fingerprint != last_quests:
		last_quests = fingerprint
		_update_quests(quests)

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _update_inventory(items: Array) -> void:
	_clear(inventory_list)
	inventory_list.add_child(_wrapped("ACHADOS DO BOSQUE  ·  %d/30" % items.size(), 12, GOLD))
	if items.is_empty():
		inventory_list.add_child(_wrapped("Sua bolsa está leve. Vença encontros para encontrar armas, armaduras e amuletos. O chefe sempre deixa um equipamento."))
	for item in items:
		var id := str(item.id)
		var row := VBoxContainer.new()
		inventory_list.add_child(row)
		row.add_child(_wrapped("%s · %s" % [item.name, item.rarity_name], 14, Color(item.color)))
		row.add_child(_label("ATQ +%d   DEF +%d   VIDA +%d" % [item.attack, item.defense, item.hp], 12, MUTED))
		var actions := HBoxContainer.new()
		row.add_child(actions)
		var equip := _button("Equipado" if item.equipped else "Equipar", func(): Session.equip(id))
		equip.disabled = item.equipped
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(equip)
		var sell := _button("Vender", func(): Session.sell(id))
		sell.disabled = item.equipped
		actions.add_child(sell)

func _update_quests(quests: Array) -> void:
	_clear(quests_list)
	quests_list.add_child(_label("CADERNO DE CAMPO", 12, GOLD))
	for quest in quests:
		var id := str(quest.id)
		quests_list.add_child(_wrapped(str(quest.name), 15))
		quests_list.add_child(_wrapped("%s · %d/%d" % [quest.description, mini(int(quest.progress), int(quest.target)), quest.target], 12))
		var b := _button("Concluída" if quest.claimed else "Resgatar · %d sementes + %d XP" % [quest.gold, quest.xp], func(): Session.claim(id))
		b.disabled = not quest.ready or quest.claimed
		quests_list.add_child(b)

func _capture() -> void:
	# Explicit opt-in used for reproducible visual verification, never normal gameplay.
	tutorial.hide()
	Session.game.advance(48)
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var target := OS.get_environment("VIGILIA_CAPTURE")
	if not target.is_empty():
		get_viewport().get_texture().get_image().save_png(target)
	get_tree().quit()

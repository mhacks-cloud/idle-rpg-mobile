class_name RpgEngine
extends RefCounted
## One deterministic authority. Each tick represents one expedition second.
## The Android overlay only displays snapshots computed by this implementation.

const SAVE_VERSION := 1
const MAX_IDLE_SECONDS := 7200
const MAX_INVENTORY := 30
const MAX_LEVEL := 100
const PHASES := ["exploration", "combat", "victory", "defeat"]
var state: Dictionary = {}
var _classes: Array = []
var _enemies: Array = []
var _gear: Dictionary = {}
var _quests: Array = []

func _init() -> void:
	_classes = _read_json("res://data/classes.json")
	_enemies = _read_json("res://data/enemies.json")
	_gear = _read_json("res://data/equipment.json")
	_quests = _read_json("res://data/quests.json")

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Required data unavailable: " + path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed != null, "Invalid configuration: " + path)
	return parsed

func classes() -> Array:
	return _classes.duplicate(true)

func _class_data(class_id: String) -> Dictionary:
	for definition in _classes:
		if definition.id == class_id:
			return definition
	return _classes[0]

func new_game(class_id: String) -> void:
	var definition := _class_data(class_id)
	state = {
		"version": SAVE_VERSION, "class_id": definition.id, "tick": 0, "seed": 42731,
		"level": 1, "xp": 0, "gold": 0, "hp": int(definition.hp), "training": 0,
		"phase": "exploration", "phase_ticks": 0, "stage": 1, "cycle": 1,
		"kills": 0, "boss_kills": 0, "deaths": 0, "enemy": {},
		"skill_cooldown": 2, "skill_flash": false, "event": "A trilha desperta. Sua vigília começa.",
		"inventory": [], "equipment": {}, "next_item_id": 1, "claimed_quests": [],
		"settings": {"sound": true, "battery_saver": false, "tutorial_seen": false}
	}

func load_state(candidate: Dictionary) -> bool:
	# Reject malformed or newer saves before mutating the running expedition.
	if not _bounded_integer(candidate.get("version"), SAVE_VERSION, SAVE_VERSION):
		return false
	var known_class := false
	for definition in _classes:
		known_class = known_class or candidate.get("class_id", "") == definition.id
	if not known_class or not PHASES.has(candidate.get("phase", "")):
		return false
	var bounds := {
		"tick": [0, 2147483647], "seed": [0, 2147483647], "level": [1, MAX_LEVEL],
		"xp": [0, 1000000000], "gold": [0, 1000000000], "hp": [0, 1000000],
		"training": [0, 1000], "phase_ticks": [0, 1000000], "stage": [1, 11],
		"cycle": [1, 10000], "kills": [0, 1000000000], "boss_kills": [0, 1000000000],
		"deaths": [0, 1000000000], "skill_cooldown": [0, 60], "next_item_id": [1, 1000000000]
	}
	for key in bounds:
		if not candidate.has(key) or not _bounded_integer(candidate[key], bounds[key][0], bounds[key][1]):
			return false
	if not candidate.get("inventory") is Array or candidate.inventory.size() > MAX_INVENTORY:
		return false
	if not candidate.get("equipment") is Dictionary or not candidate.get("enemy") is Dictionary:
		return false
	if not candidate.get("claimed_quests") is Array or not candidate.get("settings") is Dictionary:
		return false
	if not candidate.get("skill_flash") is bool:
		return false
	for key in ["sound", "battery_saver", "tutorial_seen"]:
		if not candidate.settings.get(key) is bool:
			return false
	if candidate.claimed_quests.size() > _quests.size():
		return false
	var claimed_ids: Dictionary = {}
	for quest_id in candidate.claimed_quests:
		if not quest_id is String or claimed_ids.has(quest_id):
			return false
		var found := false
		for quest in _quests:
			found = found or quest.id == quest_id
		if not found:
			return false
		claimed_ids[quest_id] = true
	if not candidate.get("event") is String or str(candidate.get("event", "")).length() > 300:
		return false
	var ids: Dictionary = {}
	for item in candidate.inventory:
		if not item is Dictionary or not _valid_item(item) or ids.has(item.id):
			return false
		ids[item.id] = item
	for slot in candidate.equipment:
		var id: Variant = candidate.equipment[slot]
		if not ids.has(id) or ids[id].slot != slot:
			return false
	var enemy: Dictionary = candidate.enemy
	if not enemy.is_empty():
		for key in ["hp", "max_hp", "attack", "defense", "xp", "gold"]:
			if not _bounded_integer(enemy.get(key), 0, 1000000):
				return false
		if enemy.hp > enemy.max_hp or not enemy.get("id") is String or not enemy.get("name") is String:
			return false
		if not enemy.get("boss") is bool or str(enemy.name).length() > 100:
			return false
		var valid_enemy := false
		for definition in _enemies:
			if definition.id == enemy.id and bool(definition.get("boss", false)) == enemy.boss:
				valid_enemy = true
		if not valid_enemy:
			return false
	if candidate.phase == "combat" and (enemy.is_empty() or int(enemy.hp) <= 0):
		return false
	var previous := state
	state = candidate.duplicate(true)
	state.version = SAVE_VERSION
	for item in state.inventory:
		for key in ["attack", "defense", "hp"]:
			item[key] = int(item[key])
	for key in ["hp", "max_hp", "attack", "defense", "xp", "gold"]:
		if state.enemy.has(key):
			state.enemy[key] = int(state.enemy[key])
	for key in bounds:
		state[key] = int(state[key])
	if state.hp > _stats().max_hp:
		state = previous
		return false
	return true

func _bounded_integer(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func _valid_item(item: Dictionary) -> bool:
	for key in ["id", "name", "base_id", "slot", "rarity", "rarity_name", "color"]:
		if not item.get(key) is String or str(item[key]).length() > 100:
			return false
	if not ["weapon", "armor", "charm"].has(item.slot):
		return false
	for key in ["attack", "defense", "hp"]:
		if not _bounded_integer(item.get(key), 0, 10000):
			return false
	return true

func _stats() -> Dictionary:
	var definition := _class_data(str(state.class_id))
	var level_bonus: int = int(state.level) - 1
	var result := {
		"max_hp": int(definition.hp) + level_bonus * 14,
		"attack": int(definition.attack) + level_bonus * 3 + int(state.training),
		"defense": int(definition.defense) + level_bonus
	}
	for item in state.inventory:
		if state.equipment.get(item.slot, "") == item.id:
			result.max_hp += int(item.hp)
			result.attack += int(item.attack)
			result.defense += int(item.defense)
	return result

func _roll(limit: int) -> int:
	state.seed = (int(state.seed) * 1103515245 + 12345) % 2147483648
	return int(state.seed) % maxi(1, limit)

func xp_required() -> int:
	return 30 + (int(state.level) - 1) * 25

func tick() -> void:
	if state.is_empty():
		return
	state.tick = mini(int(state.tick) + 1, 2147483647)
	state.skill_flash = false
	state.phase_ticks = int(state.phase_ticks) + 1
	match str(state.phase):
		"exploration":
			state.hp = mini(int(state.hp) + 3, int(_stats().max_hp))
			if int(state.phase_ticks) >= 2:
				_spawn_enemy()
		"combat":
			_combat_turn()
		"victory":
			if int(state.phase_ticks) >= 2:
				state.stage = int(state.stage) + 1
				if int(state.stage) > 11:
					state.stage = 1
					state.cycle = mini(int(state.cycle) + 1, 10000)
				_change_phase("exploration")
				state.enemy = {}
		"defeat":
			if int(state.phase_ticks) >= 4:
				state.hp = int(_stats().max_hp)
				state.stage = maxi(1, int(state.stage) - 1)
				state.enemy = {}
				_change_phase("exploration")
				state.event = "O abrigo restaurou sua energia. A trilha continua."

func _change_phase(value: String) -> void:
	state.phase = value
	state.phase_ticks = 0

func _spawn_enemy() -> void:
	var is_boss: bool = int(state.stage) == 11
	var definition: Dictionary = _enemies[3] if is_boss else _enemies[_roll(3)]
	var scaling: float = 1.0 + (int(state.stage) - 1) * 0.075 + (int(state.cycle) - 1) * 0.28
	if is_boss:
		scaling = 1.0 + (int(state.cycle) - 1) * 0.38
	state.enemy = {
		"id": definition.id, "name": definition.name,
		"hp": int(float(definition.hp) * scaling), "max_hp": int(float(definition.hp) * scaling),
		"attack": int(float(definition.attack) * scaling), "defense": int(definition.defense),
		"xp": int(definition.xp) + int(state.cycle) * 2,
		"gold": int(definition.gold) + int(state.cycle), "boss": is_boss
	}
	_change_phase("combat")
	state.event = "Encontrou %s." % definition.name

func _combat_turn() -> void:
	var attributes := _stats()
	var enemy: Dictionary = state.enemy
	var definition := _class_data(str(state.class_id))
	state.skill_cooldown = maxi(0, int(state.skill_cooldown) - 1)
	var damage: int = maxi(1, int(attributes.attack) - int(enemy.defense))
	var ability_used := int(state.skill_cooldown) == 0
	if ability_used:
		state.skill_cooldown = int(definition.cooldown)
		state.skill_flash = true
		match str(definition.skill_kind):
			"cleave": damage *= 2
			"volley": damage = damage * 2 + 3
			"arcane": damage = int(attributes.attack) * 3
			"heal":
				state.hp = mini(int(attributes.max_hp), int(state.hp) + int(attributes.max_hp) / 4)
				damage += 4
		state.event = "%s! %d de dano." % [definition.skill, damage]
	else:
		state.event = "Ataque: %d de dano." % damage
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	if int(enemy.hp) == 0:
		_win()
		return
	var incoming: int = maxi(1, int(enemy.attack) - int(attributes.defense))
	state.hp = maxi(0, int(state.hp) - incoming)
	if int(state.hp) == 0:
		state.deaths = int(state.deaths) + 1
		_change_phase("defeat")
		state.event = "Recuando ao abrigo. Seu equipamento está seguro."

func _win() -> void:
	state.kills = int(state.kills) + 1
	var enemy: Dictionary = state.enemy
	state.gold = mini(1000000000, int(state.gold) + int(enemy.gold))
	_add_xp(int(enemy.xp))
	if bool(enemy.boss):
		state.boss_kills = int(state.boss_kills) + 1
	state.event = "Vitória! +%d XP · +%d sementes" % [enemy.xp, enemy.gold]
	if bool(enemy.boss) or _roll(100) < 40:
		_drop_item(bool(enemy.boss))
	_change_phase("victory")

func _add_xp(amount: int) -> void:
	state.xp = int(state.xp) + amount
	while int(state.level) < MAX_LEVEL and int(state.xp) >= xp_required():
		state.xp = int(state.xp) - xp_required()
		state.level = int(state.level) + 1
		state.hp = int(_stats().max_hp)
	if int(state.level) >= MAX_LEVEL:
		state.xp = mini(int(state.xp), xp_required())

func _drop_item(boss: bool) -> void:
	var base: Dictionary = _gear.items[_roll(_gear.items.size())]
	var chance := _roll(100)
	var rarity_index := 2 if chance < 9 else (1 if chance < 36 or boss else 0)
	var rarity: Dictionary = _gear.rarities[rarity_index]
	var multiplier: int = int(rarity.multiplier) + mini(int(state.cycle) - 1, 20)
	var item := {
		"id": "item_%d" % int(state.next_item_id), "base_id": base.id,
		"name": base.name, "slot": base.slot, "rarity": rarity.id,
		"rarity_name": rarity.name, "color": rarity.color,
		"attack": int(base.attack) * multiplier,
		"defense": int(base.defense) * multiplier, "hp": int(base.hp) * multiplier
	}
	state.next_item_id = int(state.next_item_id) + 1
	if state.inventory.size() >= MAX_INVENTORY:
		state.gold = mini(1000000000, int(state.gold) + 8 * multiplier)
		state.event += " · Mochila cheia: achado convertido em sementes."
		return
	state.inventory.append(item)
	state.event += " · %s (%s)" % [item.name, item.rarity_name]
	if not state.equipment.has(item.slot):
		equip_item(str(item.id))

func inventory() -> Array:
	var result: Array = state.inventory.duplicate(true)
	for item in result:
		item["equipped"] = state.equipment.get(item.slot, "") == item.id
	return result

func equip_item(item_id: String) -> bool:
	for item in state.inventory:
		if item.id == item_id:
			var old_max: int = int(_stats().max_hp)
			state.equipment[item.slot] = item.id
			var new_max: int = int(_stats().max_hp)
			state.hp = clampi(int(state.hp) + new_max - old_max, 1 if int(state.hp) > 0 else 0, new_max)
			return true
	return false

func sell_item(item_id: String) -> bool:
	for index in range(state.inventory.size()):
		var item: Dictionary = state.inventory[index]
		if item.id == item_id and state.equipment.get(item.slot, "") != item.id:
			state.inventory.remove_at(index)
			state.gold = mini(1000000000, int(state.gold) + 10)
			return true
	return false

func train() -> bool:
	var cost: int = training_cost()
	if int(state.gold) < cost or int(state.training) >= 1000:
		return false
	state.gold = int(state.gold) - cost
	state.training = int(state.training) + 1
	state.event = "Treino concluído: +1 de ataque permanente."
	return true

func training_cost() -> int:
	return 35 + int(state.training) * 20

func quests() -> Array:
	var result := _quests.duplicate(true)
	for quest in result:
		quest["progress"] = mini(int(quest.target), int(state.get(quest.metric, 0)))
		quest["claimed"] = state.claimed_quests.has(quest.id)
		quest["ready"] = quest.progress >= int(quest.target) and not quest.claimed
	return result

func claim_quest(quest_id: String) -> bool:
	for quest in quests():
		if quest.id == quest_id and bool(quest.ready):
			state.claimed_quests.append(quest_id)
			state.gold = mini(1000000000, int(state.gold) + int(quest.gold))
			_add_xp(int(quest.xp))
			state.event = "Missão concluída: %s!" % quest.name
			return true
	return false

func advance(seconds: int) -> Dictionary:
	var ticks := clampi(seconds, 0, MAX_IDLE_SECONDS)
	var before_kills := int(state.kills)
	var before_gold := int(state.gold)
	var before_level := int(state.level)
	for _second in range(ticks):
		tick()
	return {"seconds": ticks, "kills": int(state.kills) - before_kills,
		"gold": int(state.gold) - before_gold, "levels": int(state.level) - before_level,
		"capped": seconds > MAX_IDLE_SECONDS}

func preview(seconds: int) -> Array:
	# A disposable clone evaluates the SAME function. Native code receives only frames.
	var clone := get_script().new() as RpgEngine
	if not clone.load_state(state):
		return []
	var result: Array = [clone.snapshot()]
	for _second in range(clampi(seconds, 0, MAX_IDLE_SECONDS)):
		clone.tick()
		result.append(clone.snapshot())
	return result

func snapshot() -> Dictionary:
	if state.is_empty():
		return {}
	var definition := _class_data(str(state.class_id))
	var attributes := _stats()
	var enemy: Dictionary = state.enemy
	return {
		"class_id": state.class_id, "class_name": definition.name,
		"level": int(state.level), "xp": int(state.xp), "xp_next": xp_required(),
		"gold": int(state.gold), "hp": int(state.hp), "max_hp": int(attributes.max_hp),
		"attack": int(attributes.attack), "defense": int(attributes.defense),
		"phase": state.phase, "stage": int(state.stage), "cycle": int(state.cycle),
		"kills": int(state.kills), "wins": int(state.kills), "boss_kills": int(state.boss_kills),
		"enemy_id": enemy.get("id", ""), "enemy_name": enemy.get("name", "A trilha está tranquila"),
		"enemy_hp": int(enemy.get("hp", 0)), "enemy_max_hp": int(enemy.get("max_hp", 1)),
		"skill_name": definition.skill, "skill_cooldown": int(state.skill_cooldown),
		"skill_flash": bool(state.skill_flash), "event": state.event, "tick": int(state.tick)
	}

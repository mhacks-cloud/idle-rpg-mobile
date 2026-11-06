extends Control
## Original pixel scenery. Rendering reads snapshots; it never changes combat.
var state: Dictionary = {}
var phase := 0.0
var background: Texture2D
var sprites: Dictionary = {}
var refresh: Timer
const SPRITE_IDS := ["warrior", "archer", "mage", "healer", "dew_slime", "bark_mite", "lantern_moth", "root_guardian"]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/forest.png"):
		background = load("res://assets/forest.png")
	for id in SPRITE_IDS:
		var path := "res://assets/%s.png" % id
		if ResourceLoader.exists(path):
			sprites[id] = load(path)
	refresh = Timer.new()
	refresh.wait_time = 0.16
	refresh.timeout.connect(_animate)
	add_child(refresh)
	refresh.start()
	resized.connect(queue_redraw)

func _animate() -> void:
	if not is_visible_in_tree() or Session.suspended:
		return
	phase += 0.16
	refresh.wait_time = 0.5 if Session.game.state.settings.get("battery_saver", false) else 0.16
	queue_redraw()

func display(snapshot: Dictionary) -> void:
	state = snapshot
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("102829"))
	if background:
		draw_texture_rect(background, rect, false)
	else:
		for i in 12:
			draw_rect(Rect2(i * size.x / 11, 20 + i % 3 * 14, 12, size.y), Color("183a36"))
	var floor_y := size.y * 0.78
	var scale_px := maxf(2.0, floorf(minf(size.x / 125.0, size.y / 50.0)))
	var hero_x := size.x * 0.25
	var enemy_x := size.x * 0.74
	var fighting: bool = state.get("phase", "exploration") == "combat"
	var move := sin(phase * 5) * 3.0 if fighting else sin(phase * 2) * 1.5
	_draw_actor(str(state.get("class_id", "warrior")), Vector2(hero_x + move, floor_y), scale_px, false)
	if state.get("enemy_hp", 0) > 0:
		_draw_actor(str(state.get("enemy_id", "dew_slime")), Vector2(enemy_x - move, floor_y), scale_px, true)
	if fighting:
		var progress := fmod(phase * 1.5, 1.0)
		var p := Vector2(lerpf(hero_x + 30, enemy_x - 30, progress), floor_y - 36 - sin(progress * PI) * 20)
		draw_rect(Rect2(p, Vector2(7, 4)), Color("f6cf79") if not state.get("skill_flash", false) else Color("c4abf7"))
	for i in 7:
		var p := Vector2(fmod(i * 79.0 + phase * (3 + i % 3), maxf(1, size.x)), 18 + fmod(i * 43.0, maxf(1, size.y * 0.6)))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.9, 0.85, 0.5, 0.3 + sin(phase + i) * 0.2))

func _draw_actor(id: String, feet: Vector2, pixel_scale: float, flip: bool) -> void:
	var actor_size := Vector2(24, 24) * pixel_scale
	draw_ellipse_shadow(feet, pixel_scale)
	if sprites.has(id):
		var texture: Texture2D = sprites[id]
		var frame_count := maxi(1, texture.get_width() / 24)
		var frame := int(phase * 4) % frame_count
		var destination := Rect2(feet - Vector2(actor_size.x / 2, actor_size.y), actor_size)
		if flip:
			destination.position.x += actor_size.x
			destination.size.x = -actor_size.x
		draw_texture_rect_region(texture, destination, Rect2(frame * 24, 0, 24, 24))
	else:
		draw_rect(Rect2(feet - Vector2(12, 36), Vector2(24, 36)), Color("8cd6ac") if not flip else Color("d39c78"))

func draw_ellipse_shadow(feet: Vector2, pixel_scale: float) -> void:
	draw_rect(Rect2(feet - Vector2(10 * pixel_scale, pixel_scale), Vector2(20 * pixel_scale, 2 * pixel_scale)), Color(0.02, 0.04, 0.06, 0.35))

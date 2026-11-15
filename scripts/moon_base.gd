extends Node2D

## Playable lunar exploration level built around the repository's current lunar atlas.
## The existing grayscale map composition is used as the art-directed terrain base;
## walkable gameplay, HUD, sample sites, collisions, and map bounds remain live nodes.

const PLAYER_SCENE: PackedScene = preload("res://scripts/player.tscn")
const WORLD_SIZE := Vector2(1536.0, 1024.0)
const WALK_SPEED := 115.0
const TOTAL_SURVEY_SITES := 3
const OUTPOST_POSITION := Vector2(760.0, 435.0)
const LANDING_SITE_POSITION := Vector2(1310.0, 254.0)

var astronaut: CharacterBody2D
var oxygen := 100.0
var samples := 0
var active := true
var status_label: Label
var notice_label: Label
var sites: Array[Area2D] = []

func _ready() -> void:
	_configure_inputs()
	_add_player()
	_add_survey_sites()
	_add_hud()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if not active:
		return
	# The outpost keeps the mission viable; outside its radius oxygen drains slowly.
	var player_position := _player_collision_position()
	var at_outpost := player_position.distance_to(OUTPOST_POSITION) < 145.0
	if at_outpost:
		oxygen = minf(100.0, oxygen + delta * 8.0)
	else:
		oxygen = maxf(0.0, oxygen - delta * 0.22)
	if oxygen <= 0.0:
		active = false
		astronaut.velocity = Vector2.ZERO
		astronaut.set_physics_process(false)
		notice_label.text = "SUIT OXYGEN DEPLETED  •  Press R to restart"
	if Input.is_action_just_pressed("interact"):
		_interact()
	status_label.text = "O₂  %03d%%       SAMPLES  %d / %d" % [roundi(oxygen), samples, TOTAL_SURVEY_SITES]

func _configure_inputs() -> void:
	_bind_key("ui_up", KEY_W)
	_bind_key("ui_down", KEY_S)
	_bind_key("ui_left", KEY_A)
	_bind_key("ui_right", KEY_D)
	_bind_key("interact", KEY_E)
	_bind_key("restart", KEY_R)

func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _add_player() -> void:
	astronaut = PLAYER_SCENE.instantiate() as CharacterBody2D
	astronaut.name = "Astronaut"
	# The current player scene offsets its sprite and collision shape to align the
	# astronaut with the figure already painted into the map image.
	astronaut.position = Vector2(821, 660)
	astronaut.z_index = 10
	astronaut.velocity = Vector2.ZERO
	astronaut.move_speed = WALK_SPEED
	var sprite := astronaut.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.scale = Vector2(0.14, 0.14)
	add_child(astronaut)
	var camera := Camera2D.new()
	camera.name = "ExplorationCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(1.0, 1.0)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	astronaut.add_child(camera)
	camera.make_current()

func _add_survey_sites() -> void:
	_add_site("NORTH CRATER", Vector2(586, 150))
	_add_site("SOUTH RIM", Vector2(575, 730))
	_add_site("EAST BASALT", Vector2(1125, 765))

func _add_site(site_name: String, at: Vector2) -> void:
	var site := Area2D.new()
	site.name = site_name.replace(" ", "_")
	site.position = at
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	var collision := CollisionShape2D.new()
	collision.shape = circle
	site.add_child(collision)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
	marker.color = Color(0.2, 0.86, 1.0, 0.95)
	site.add_child(marker)
	site.body_entered.connect(_on_site_entered.bind(site, site_name))
	add_child(site)
	sites.append(site)

func _on_site_entered(body: Node2D, site: Area2D, site_name: String) -> void:
	if body != astronaut or not active or not is_instance_valid(site):
		return
	samples += 1
	oxygen = minf(100.0, oxygen + 12.0)
	notice_label.text = "SAMPLE LOGGED  •  %s" % site_name
	site.queue_free()
	sites.erase(site)
	if samples == TOTAL_SURVEY_SITES:
		notice_label.text = "ALL SURVEY SAMPLES RECOVERED  •  Return to the habitat"

func _interact() -> void:
	if not active:
		return
	var player_position := _player_collision_position()
	if player_position.distance_to(OUTPOST_POSITION) < 165.0:
		oxygen = 100.0
		notice_label.text = "HABITAT AIRLOCK  •  SUIT RECHARGED"
	elif player_position.distance_to(LANDING_SITE_POSITION) < 150.0:
		notice_label.text = "LANDING SITE  •  SYSTEMS NOMINAL"
	else:
		notice_label.text = "Move near the habitat or landing site to interact."

func _player_collision_position() -> Vector2:
	var collision := astronaut.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		return astronaut.to_global(collision.position)
	return astronaut.global_position

func _add_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Mission_HUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(360, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.88)
	style.border_color = Color(0.22, 0.73, 0.92, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var title := Label.new()
	title.text = "LUNAR FIELD OPERATIONS"
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	stack.add_child(title)
	status_label = Label.new()
	stack.add_child(status_label)
	notice_label = Label.new()
	notice_label.position = Vector2(20, 118)
	notice_label.text = "WASD / Arrows move    E interact    O₂ recharges at habitat    R restart"
	notice_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	layer.add_child(notice_label)
	status_label.text = "O₂  100%       SAMPLES  0 / %d" % TOTAL_SURVEY_SITES

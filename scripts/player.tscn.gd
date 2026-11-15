extends CharacterBody2D

@export var move_speed: float = 180.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_facing: Vector2 = Vector2.DOWN


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)
	# Keep the scene playable even when runtime-generated InputMap entries have
	# not been applied yet (for example, on a first editor launch).
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length_squared() > 0.0:
		input_direction = wasd.normalized()

	velocity = input_direction * move_speed
	move_and_slide()

	if input_direction.length_squared() > 0.0:
		last_facing = input_direction

	_update_animation(input_direction)


func _update_animation(direction: Vector2) -> void:
	var animation_name: String

	if direction.length_squared() == 0.0:
		animation_name = _get_idle_animation()
	else:
		animation_name = _get_walk_animation(direction)

	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _get_walk_animation(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		animated_sprite.flip_h = direction.x < 0.0
		return "walk_side"

	animated_sprite.flip_h = false
	return "walk_back" if direction.y < 0.0 else "walk_front"


func _get_idle_animation() -> String:
	if absf(last_facing.x) > absf(last_facing.y):
		animated_sprite.flip_h = last_facing.x < 0.0
		return "idle-side"

	animated_sprite.flip_h = false
	return "idle_back" if last_facing.y < 0.0 else "idle_front"

extends CharacterBody2D

signal health_changed(current, max)
signal died

@export var speed: float = 200.0
@export var max_health: int = 100
@export var attack_cooldown: float = 0.4
@export var attack_range: float = 28.0
@export var attack_damage: int = 10

var _health: int
var _cooldown_timer: float = 0.0

func _ready():
	_health = max_health
	emit_signal("health_changed", _health, max_health)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	var input_vec = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_vec.length() > 1:
		input_vec = input_vec.normalized()
	velocity = input_vec * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_attack()

func _attack() -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = attack_cooldown
	# Simple area-based attack: detect enemies in range.
	for body in get_tree().get_nodes_in_group("enemies"):
		if not body or not body.has_method("receive_damage"):
			continue
		if global_position.distance_to(body.global_position) <= attack_range:
			body.receive_damage(attack_damage)

func receive_damage(amount: int) -> void:
	_health -= amount
	emit_signal("health_changed", _health, max_health)
	if _health <= 0:
		_health = 0
		emit_signal("died")
	var material = $Icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("damage_flash", 1.0)
		var tween = create_tween()
		tween.tween_property(material, "shader_parameter/damage_flash", 0.0, 0.2)
		await tween.finished
		tween.kill()

func reset_health():
	_health = max_health
	emit_signal("health_changed", _health, max_health)

func get_health() -> int:
	return _health

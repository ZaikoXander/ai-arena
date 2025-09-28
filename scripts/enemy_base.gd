extends CharacterBody2D
class_name EnemyBase

signal health_changed(current, max)
signal died

@export var max_health: int = 100
@export var speed: float = 120.0
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 0.8
@export var touch_damage: int = 8

var _health: int = 0
var _cooldown: float = 0.0
var player: Node = null

func _ready():
	_health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	emit_signal("health_changed", _health, max_health)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	take_step(delta)
	move_and_slide()

func take_step(delta: float) -> void:
	# Override in subclasses to provide movement/strategy.
	velocity = Vector2.ZERO

func can_attack() -> bool:
	return _cooldown <= 0.0

func perform_attack() -> void:
	if not player or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > attack_range:
		return
	if not can_attack():
		return
	if player.has_method("receive_damage"):
		player.receive_damage(touch_damage)
	_cooldown = attack_cooldown

func move_towards(target: Vector2, delta: float) -> void:
	var dir = target - global_position
	if dir.length() > 1.0:
		dir = dir.normalized()
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO

func receive_damage(amount: int) -> void:
	_health -= amount
	emit_signal("health_changed", _health, max_health)
	if _health <= 0:
		_health = 0
		emit_signal("died")
		queue_free()
	var material = $Icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("damage_flash", 1.0)
		var tween = create_tween()
		tween.tween_property(material, "shader_parameter/damage_flash", 0.0, 0.2)
		await tween.finished
		tween.kill()

func get_health() -> int:
	return _health

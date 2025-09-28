extends EnemyBase
class_name EnemyBT

@export var patrol_points: Array[Vector2] = [Vector2(-60,0), Vector2(60,0)]
@export var chase_distance: float = 140
@export var retreat_health_threshold: int = 30
@export var heal_rate: float = 8.0
@export var heal_time: float = 2.5

var BT = preload("res://scripts/bt_nodes.gd")
var _tree_root
var _heal_timer: float = 0.0
var _patrol_index: int = 0
var _attack_recovery: float = 0.0

func _ready():
	super._ready()
	_build_tree()

func _build_tree():
	var chase_seq = BT.SequenceNode.new([
		BT.ConditionNode.new(func(a): return a.player and a.global_position.distance_to(a.player.global_position) <= chase_distance),
		BT.ActionNode.new(func(a, d): return a._do_chase(d))
	])
	var attack_seq = BT.SequenceNode.new([
		BT.ConditionNode.new(func(a): return a.player and a.global_position.distance_to(a.player.global_position) <= a.attack_range + 4),
		BT.ActionNode.new(func(a, d): return a._do_attack(d))
	])
	var retreat_seq = BT.SequenceNode.new([
		BT.ConditionNode.new(func(a): return a._health <= retreat_health_threshold),
		BT.ActionNode.new(func(a, d): return a._do_retreat(d))
	])
	_tree_root = BT.SelectorNode.new([retreat_seq, attack_seq, chase_seq, BT.ActionNode.new(func(a,d): return a._do_patrol(d))])

func take_step(delta: float) -> void:
	if _tree_root:
		if _attack_recovery > 0.0:
			_attack_recovery -= delta
		_tree_root.tick(self, delta)

func _do_patrol(delta: float) -> String:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return "success"
	var target_local = patrol_points[_patrol_index]
	var target = get_parent().to_global(target_local)
	move_towards(target, delta)
	if global_position.distance_to(target) < 8:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
	return "running"

func _do_chase(delta: float) -> String:
	if not player:
		return "failure"
	move_towards(player.global_position, delta)
	return "running"

func _do_attack(delta: float) -> String:
	velocity = Vector2.ZERO
	if _attack_recovery > 0.0:
		return "running"
	if can_attack():
		perform_attack()
		_attack_recovery = 0.35
	return "success"

func _do_retreat(delta: float) -> String:
	# Move away from player to a 'safe' position (opposite direction) and heal.
	if not player:
		return "failure"
	var dir = (global_position - player.global_position).normalized()
	velocity = dir * speed
	_heal_timer += delta
	if _heal_timer >= heal_time:
		_health = min(max_health, _health + int(heal_rate * heal_time))
		_heal_timer = 0
		emit_signal("health_changed", _health, max_health)
		return "success"
	return "running"

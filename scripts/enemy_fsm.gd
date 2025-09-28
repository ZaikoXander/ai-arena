extends EnemyBase
class_name EnemyFSM

@export var patrol_points: Array[Vector2] = [Vector2(-40,0), Vector2(40,0)]
@export var chase_distance: float = 120
@export var attack_distance: float = 34

var _state := "patrol" # patrol, chase, attack
var _patrol_index := 0

func take_step(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	match _state:
		"patrol":
			_patrol(delta)
			if player and global_position.distance_to(player.global_position) <= chase_distance:
				_state = "chase"
		"chase":
			_chase(delta)
			if player and global_position.distance_to(player.global_position) <= attack_distance:
				_state = "attack"
			elif player and global_position.distance_to(player.global_position) > chase_distance * 1.3:
				_state = "patrol"
		"attack":
			_attack(delta)
			if player and global_position.distance_to(player.global_position) > attack_distance * 1.3:
				_state = "chase"

func _patrol(delta: float):
	if patrol_points.size() == 0:
		velocity = Vector2.ZERO
		return
	var target = patrol_points[_patrol_index]
	move_towards(get_parent().to_global(target), delta)
	if global_position.distance_to(get_parent().to_global(target)) < 8:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()

func _chase(delta: float):
	if player:
		move_towards(player.global_position, delta)

func _attack(delta: float):
	velocity = Vector2.ZERO
	perform_attack()

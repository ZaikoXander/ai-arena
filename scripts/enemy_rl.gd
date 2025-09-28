extends EnemyBase
class_name EnemyRL

# Reinforcement-inspired enemy with adaptive aggression, defensive retreats, and deceptive feints.

@export var epsilon: float = 0.18
@export var epsilon_min: float = 0.05
@export var epsilon_decay: float = 0.0012
@export var decision_interval: float = 0.18
@export var feint_cooldown: float = 1.9
@export var feint_rush_duration: float = 0.24
@export var feint_pause_duration: float = 0.14
@export var feint_retreat_duration: float = 0.32
@export var aggressive_push_distance: float = 110.0
@export var defensive_retreat_distance: float = 155.0
@export var retreat_speed_multiplier: float = 1.3

var q_table: Dictionary = {}
var last_state = null
var last_action = null
var prev_player_health: float = 100.0
var prev_self_health: float = 100.0

var alpha: float = 0.25
var gamma: float = 0.88

var decision_timer: float = 0.0
var current_action: int = -1
var mode: String = "aggressive"

var strafe_dir: int = 1

var feint_state: String = "none"
var feint_timer: float = 0.0
var feint_cooldown_timer: float = 0.0
var feint_counter_ready: bool = false

func _ready():
	super._ready()
	prev_self_health = _health
	prev_player_health = _get_player_health()

func take_step(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var current_player_health = _get_player_health()
	var current_self_health = _health
	var distance = global_position.distance_to(player.global_position)
	if decision_timer <= 0.0 and last_state != null and last_action != null:
		var reward = _compute_reward(current_player_health, current_self_health, distance)
		var new_state = _compose_state(distance, current_self_health, current_player_health)
		_update_q(last_state, last_action, reward, new_state)
		last_state = null
		last_action = null
	_update_mode(distance, current_self_health, current_player_health)
	_decay_epsilon(delta)
	if feint_cooldown_timer > 0.0:
		feint_cooldown_timer -= delta
	if feint_state != "none":
		_continue_feint(delta)
		decision_timer -= delta
		if decision_timer < 0.0:
			decision_timer = 0.0
		return
	if decision_timer > 0.0:
		decision_timer -= delta
		_apply_current_action(delta, distance)
		return
	var state = _compose_state(distance, current_self_health, current_player_health)
	var action = _select_action(state, distance, current_self_health, current_player_health)
	prev_player_health = current_player_health
	prev_self_health = current_self_health
	current_action = _execute_action(action, delta, distance)
	last_state = state
	last_action = current_action
	if current_action == 4:
		decision_timer = feint_rush_duration + feint_pause_duration + feint_retreat_duration + 0.1
	else:
		decision_timer = decision_interval

func _compute_reward(player_hp: float, self_hp: float, distance: float) -> float:
	var reward = 0.0
	reward += (prev_player_health - player_hp) * 0.55
	reward -= (prev_self_health - self_hp) * 0.8
	if last_action == 1 and prev_player_health > player_hp:
		reward += 3.0
	if last_action == 2 and self_hp > prev_self_health:
		reward += 1.5
	if last_action == 3 and mode == "aggressive" and distance < attack_range * 1.4:
		reward += 0.4
	if last_action == 4 and feint_state == "none":
		reward += 0.7
	if self_hp <= 0.0:
		reward -= 5.0
	return reward

func _compose_state(distance: float, self_hp: float, player_hp: float) -> Vector3i:
	var dist_bucket = 2
	if distance < 60.0:
		dist_bucket = 0
	elif distance < 140.0:
		dist_bucket = 1
	var self_ratio = float(self_hp) / float(max_health)
	var self_bucket = 0
	if self_ratio > 0.66:
		self_bucket = 2
	elif self_ratio > 0.33:
		self_bucket = 1
	var player_ratio = clamp(player_hp / 100.0, 0.0, 1.0)
	var advantage_bucket = 1
	if self_ratio < player_ratio - 0.1:
		advantage_bucket = 0
	elif self_ratio > player_ratio + 0.1:
		advantage_bucket = 2
	return Vector3i(dist_bucket, self_bucket, advantage_bucket)

func _select_action(state: Vector3i, distance: float, self_hp: float, player_hp: float) -> int:
	if randf() < epsilon or not q_table.has(state):
		return randi() % 5
	var best_action = 0
	var best_val = -INF
	for a in range(5):
		var value = _get_q_value(state, a)
		value += _action_bias(a, distance, self_hp, player_hp)
		if value > best_val:
			best_val = value
			best_action = a
	return best_action

func _get_q_value(state: Vector3i, action: int) -> float:
	if not q_table.has(state):
		q_table[state] = {}
	return q_table[state].get(action, 0.0)

func _action_bias(action: int, distance: float, self_hp: float, player_hp: float) -> float:
	var bias = 0.0
	if mode == "aggressive":
		if action == 1 and distance <= attack_range + 10.0:
			bias += 1.2
		if action == 0 and distance > aggressive_push_distance:
			bias += 0.4
		if action == 4 and feint_cooldown_timer <= 0.0 and distance <= attack_range * 1.8:
			bias += 0.6
		if action == 2 and self_hp > player_hp:
			bias -= 0.6
	else:
		if action == 2 and distance <= defensive_retreat_distance:
			bias += 1.0
		if action == 3:
			bias += 0.3
		if action == 1 and distance > attack_range + 8.0:
			bias -= 0.5
		if action == 4 and feint_cooldown_timer <= 0.0:
			bias += 0.4
	return bias

func _execute_action(action: int, delta: float, distance: float) -> int:
	match action:
		0:
			_approach_move(delta)
			return 0
		1:
			if can_attack() and distance <= attack_range + 6.0:
				velocity = Vector2.ZERO
				perform_attack()
				return 1
			_approach_move(delta)
			return 0
		2:
			_retreat_move()
			return 2
		3:
			_strafe_move(delta, distance)
			return 3
		4:
			if feint_cooldown_timer <= 0.0:
				_start_feint(distance)
				return 4
			_strafe_move(delta, distance)
			return 3
		_:
			_approach_move(delta)
			return 0

func _apply_current_action(delta: float, distance: float) -> void:
	match current_action:
		0:
			_approach_move(delta)
		1:
			if can_attack() and distance <= attack_range + 6.0:
				velocity = Vector2.ZERO
				perform_attack()
			else:
				_approach_move(delta)
		2:
			_retreat_move()
		3:
			_strafe_move(delta, distance)
		4:
			if feint_state == "none":
				_strafe_move(delta, distance)
		_:
			_approach_move(delta)

func _approach_move(delta: float) -> void:
	var to_player = player.global_position - global_position
	if to_player.length() > 1.0:
		to_player = to_player.normalized()
	var lateral_sign = 1.0
	if randf() <= 0.5:
		lateral_sign = -1.0
	var lateral = Vector2(-to_player.y, to_player.x) * 0.18 * lateral_sign
	velocity = (to_player + lateral) * speed

func _retreat_move() -> void:
	var away = global_position - player.global_position
	if away.length() > 1.0:
		away = away.normalized()
	var tangent = Vector2(-away.y, away.x) * 0.35
	var mult = retreat_speed_multiplier
	if mode == "aggressive":
		mult = 1.05
	velocity = (away * mult + tangent) * speed

func _strafe_move(delta: float, distance: float) -> void:
	var to_player = player.global_position - global_position
	if to_player.length() > 1.0:
		to_player = to_player.normalized()
	var tangent = Vector2(-to_player.y, to_player.x) * strafe_dir
	var forward_factor = 0.2
	if mode == "aggressive" and distance > attack_range * 1.1:
		forward_factor = 0.45
	elif mode == "defensive":
		forward_factor = 0.1
	velocity = (to_player * forward_factor + tangent) * speed
	if randi() % 120 == 0:
		strafe_dir *= -1

func _start_feint(distance: float) -> void:
	feint_state = "rush"
	feint_timer = feint_rush_duration
	feint_cooldown_timer = feint_cooldown
	feint_counter_ready = distance <= attack_range + 8.0 and mode == "aggressive"

func _continue_feint(delta: float) -> void:
	match feint_state:
		"rush":
			var to_player = player.global_position - global_position
			if to_player.length() > 1.0:
				to_player = to_player.normalized()
			var multiplier = 1.4
			if mode != "aggressive":
				multiplier = 1.15
			velocity = to_player * speed * multiplier
			feint_timer -= delta
			if feint_timer <= 0.0:
				feint_state = "pause"
				feint_timer = feint_pause_duration
		"pause":
			velocity = Vector2.ZERO
			feint_timer -= delta
			if feint_timer <= 0.0:
				feint_state = "retreat"
				feint_timer = feint_retreat_duration
		"retreat":
			var away = global_position - player.global_position
			if away.length() > 1.0:
				away = away.normalized()
			var tangent = Vector2(-away.y, away.x) * 0.25
			velocity = (away * retreat_speed_multiplier + tangent) * speed
			feint_timer -= delta
			if feint_timer <= 0.0:
				feint_state = "none"
				if feint_counter_ready and can_attack():
					var dist = global_position.distance_to(player.global_position)
					if dist <= attack_range + 6.0:
						perform_attack()
				decision_timer = 0.0

func _update_mode(distance: float, self_hp: float, player_hp: float) -> void:
	var self_ratio = float(self_hp) / float(max_health)
	var player_ratio = clamp(player_hp / 100.0, 0.0, 1.0)
	var target = mode
	if self_ratio < 0.4 and self_ratio < player_ratio + 0.05:
		target = "defensive"
	elif distance <= aggressive_push_distance and self_ratio > player_ratio:
		target = "aggressive"
	elif distance > defensive_retreat_distance * 1.1:
		target = "aggressive"
	if target != mode:
		mode = target

func _decay_epsilon(delta: float) -> void:
	epsilon -= epsilon_decay * delta * 60.0
	if epsilon < epsilon_min:
		epsilon = epsilon_min

func _get_player_health() -> float:
	if player and player.has_method("get_health"):
		return float(player.get_health())
	return 100.0

func _update_q(prev_state, prev_action, reward: float, new_state: Vector3i) -> void:
	if prev_state == null or prev_action == null:
		return
	if not q_table.has(prev_state):
		q_table[prev_state] = {}
	if not q_table.has(new_state):
		q_table[new_state] = {}
	var prev_val = q_table[prev_state].get(prev_action, 0.0)
	var max_next = 0.0
	for a in range(5):
		max_next = max(max_next, q_table[new_state].get(a, 0.0))
	var new_val = prev_val + alpha * (reward + gamma * max_next - prev_val)
	q_table[prev_state][prev_action] = new_val

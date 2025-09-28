extends EnemyBase
class_name EnemyNN

# A tiny fixed neural network (2-layer perceptron) selecting actions based on features:
# Inputs: [distance_to_player / 200, self_health_ratio, player_health_ratio, health_diff]
# Hidden layer: size 5, activation ReLU
# Output layer: 3 logits -> 0: approach, 1: attack, 2: circle (strafe)
# Weights are pre-trained (simulated) constants.

@export var decision_interval: float = 0.18
@export var style_reassess_time: float = 1.2
@export var aggressive_feint_chance: float = 0.28
@export var defensive_feint_chance: float = 0.18
@export var feint_cooldown: float = 2.0
@export var feint_rush_duration: float = 0.25
@export var feint_pause_duration: float = 0.15
@export var feint_retreat_duration: float = 0.35
@export var defensive_retreat_distance: float = 160.0
@export var retreat_speed_multiplier: float = 1.2

var W1 = [
	[0.8, 0.2, -0.1, 0.5],
	[-0.4, 0.9, 0.3, -0.2],
	[0.3, -0.6, 0.7, 0.1],
	[0.5, 0.5, -0.3, 0.2],
	[-0.2, 0.4, 0.6, -0.5]
]
var b1 = [0.0, 0.1, -0.05, 0.05, 0.0]
var W2 = [
	[0.6, -0.3, 0.2, 0.1, 0.4], # approach
	[0.2, 0.5, -0.6, 0.3, 0.1], # attack
	[-0.4, 0.2, 0.5, -0.2, 0.3]  # circle
]
var b2 = [0.05, -0.1, 0.0]

var circle_dir: int = 1
var style: String = "aggressive"
var style_timer: float = 0.0
var decision_timer: float = 0.0
var current_action: int = 0
var feint_state: String = "none"
var feint_timer: float = 0.0
var feint_aggressive: bool = true
var feint_cooldown_timer: float = 0.0
var last_distance: float = 999.0

func take_step(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		velocity = Vector2.ZERO
		return
	_update_timers(delta)
	var distance = player.global_position.distance_to(global_position)
	_update_style(distance)
	if feint_state != "none":
		_update_feint(delta)
		last_distance = distance
		return
	if _maybe_start_feint(distance):
		last_distance = distance
		return
	if decision_timer <= 0.0:
		current_action = _choose_action(distance)
		decision_timer = decision_interval
	_apply_action(current_action, delta, distance)
	last_distance = distance

func _update_timers(delta: float) -> void:
	if decision_timer > 0.0:
		decision_timer -= delta
	if style_timer > 0.0:
		style_timer -= delta
	if feint_cooldown_timer > 0.0:
		feint_cooldown_timer -= delta

func _update_style(distance: float) -> void:
	if style_timer > 0.0:
		return
	var self_ratio = float(_health) / float(max_health)
	var player_ratio = _player_health_ratio()
	var target_style = "aggressive"
	if self_ratio < 0.45:
		target_style = "defensive"
	elif self_ratio < player_ratio - 0.1:
		target_style = "defensive"
	elif distance > defensive_retreat_distance * 1.2:
		target_style = "aggressive"
	if target_style != style:
		style = target_style
		style_timer = style_reassess_time
	else:
		style_timer = style_reassess_time * 0.5

func _maybe_start_feint(distance: float) -> bool:
	if feint_cooldown_timer > 0.0:
		return false
	var chance = 0.0
	if style == "aggressive" and distance <= attack_range * 1.8 and can_attack():
		chance = aggressive_feint_chance
	elif style == "defensive" and distance <= defensive_retreat_distance:
		chance = defensive_feint_chance
	if chance <= 0.0:
		return false
	if randf() < chance:
		_start_feint(style == "aggressive")
		return true
	return false

func _start_feint(is_aggressive: bool) -> void:
	feint_aggressive = is_aggressive
	feint_state = "rush"
	feint_timer = feint_rush_duration
	feint_cooldown_timer = feint_cooldown

func _update_feint(delta: float) -> void:
	match feint_state:
		"rush":
			var to_player = player.global_position - global_position
			if to_player.length() > 1.0:
				to_player = to_player.normalized()
			var rush_multiplier = 1.2
			if feint_aggressive:
				rush_multiplier = 1.45
			var rush_speed = speed * rush_multiplier
			velocity = to_player * rush_speed
			feint_timer -= delta
			if feint_timer <= 0.0:
				feint_state = "pause"
				feint_timer = feint_pause_duration
		"pause":
			velocity = Vector2.ZERO
			feint_timer -= delta
			if feint_timer <= 0.0:
				feint_state = "retreat"
				var extra = 0.2
				if not feint_aggressive:
					extra = 0.35
				feint_timer = feint_retreat_duration + extra
		"retreat":
			var away = global_position - player.global_position
			if away.length() > 1.0:
				away = away.normalized()
			var tangent = Vector2(-away.y, away.x)
			velocity = (away * 0.9 + tangent * 0.35) * speed * 1.1
			feint_timer -= delta
			if feint_timer <= 0.0:
				feint_state = "none"
				if feint_aggressive and can_attack():
					var dist = player.global_position.distance_to(global_position)
					if dist <= attack_range + 6.0:
						perform_attack()

func _choose_action(distance: float) -> int:
	var player_ratio = _player_health_ratio()
	var self_ratio = float(_health) / float(max_health)
	var features = [clamp(distance / 200.0, 0.0, 1.0), self_ratio, player_ratio, self_ratio - player_ratio]
	var hidden: Array = []
	for i in range(W1.size()):
		var sum = b1[i]
		for j in range(features.size()):
			sum += W1[i][j] * features[j]
		hidden.append(max(sum, 0.0))
	var outputs: Array = []
	for o in range(W2.size()):
		var s = b2[o]
		for h in range(hidden.size()):
			s += W2[o][h] * hidden[h]
		outputs.append(s)
	var best_idx = 0
	var best_val = -INF
	for idx in range(outputs.size()):
		if outputs[idx] > best_val:
			best_val = outputs[idx]
			best_idx = idx
	var action = best_idx
	if style == "aggressive":
		if action == 2 and distance <= attack_range * 0.9:
			action = 1
		elif action == 0 and distance <= attack_range * 0.6 and can_attack():
			action = 1
	else:
		var low_health = _health < max_health * 0.45
		if low_health and distance <= defensive_retreat_distance:
			action = 3
		elif action == 1 and (not can_attack() or distance > attack_range + 10.0):
			action = 2
		elif action == 0 and distance < defensive_retreat_distance * 0.8:
			action = 3
	return action

func _apply_action(action: int, delta: float, distance: float) -> void:
	match action:
		0:
			_advance(delta)
		1:
			_attempt_attack(distance)
		2:
			_circle_move(delta, distance)
		3:
			_retreat_move(delta)
		_:
			_circle_move(delta, distance)

func _advance(delta: float) -> void:
	var to_player = player.global_position - global_position
	if to_player.length() > 1.0:
		to_player = to_player.normalized()
	var lateral_sign = 1.0
	if randf() <= 0.5:
		lateral_sign = -1.0
	var lateral = Vector2(-to_player.y, to_player.x) * 0.15 * lateral_sign
	velocity = (to_player + lateral) * speed

func _attempt_attack(distance: float) -> void:
	if can_attack() and distance <= attack_range + 4.0:
		velocity = Vector2.ZERO
		perform_attack()
	else:
		_advance(0.0)

func _circle_move(delta: float, distance: float) -> void:
	var to_player = player.global_position - global_position
	if to_player.length() > 1.0:
		to_player = to_player.normalized()
	var tangent = Vector2(-to_player.y, to_player.x) * circle_dir
	var approach_scale = 0.3
	if style == "aggressive" and distance > attack_range * 1.1:
		approach_scale = 0.55
	elif style == "defensive":
		approach_scale = 0.15
	velocity = (to_player * approach_scale + tangent * 0.85) * speed
	if randi() % 160 == 0:
		circle_dir *= -1

func _retreat_move(delta: float) -> void:
	var away = global_position - player.global_position
	if away.length() > 1.0:
		away = away.normalized()
	var tangent = Vector2(-away.y, away.x)
	var strafe = tangent * 0.4
	velocity = (away * retreat_speed_multiplier + strafe) * speed

func _player_health_ratio() -> float:
	if player and player.has_method("get_health"):
		return clamp(float(player.get_health()) / 100.0, 0.0, 1.0)
	return 1.0

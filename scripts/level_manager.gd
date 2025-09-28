extends Node
class_name LevelManager

# Manages sequential levels with different AI enemies.
# Level order: 0 FSM, 1 BT, 2 NN, 3 RL

@export var player_scene: PackedScene
@export var fsm_enemy_scene: PackedScene
@export var bt_enemy_scene: PackedScene
@export var nn_enemy_scene: PackedScene
@export var rl_enemy_scene: PackedScene
@export var player_spawn_positions: Array[Vector2] = [
	Vector2(-180, 0),
	Vector2(-180, 0),
	Vector2(-180, 0),
	Vector2(-180, 0)
]
@export var enemy_spawn_positions: Array[Vector2] = [
	Vector2(180, 0),
	Vector2(180, 0),
	Vector2(180, 0),
	Vector2(180, 0)
]
@export var fallback_player_spawn: Vector2 = Vector2(-200, 0)
@export var fallback_enemy_spawn: Vector2 = Vector2(200, 0)

var current_level: int = 0
var player: Node = null
var enemy: Node = null
var ui: CanvasLayer = null

signal all_levels_complete
signal level_started(level_index)

func _ready():
	ui = get_tree().get_first_node_in_group("ui")
	_start_level(0)

func _start_level(idx: int):
	current_level = idx
	call_deferred("_spawn_level")

func _spawn_level():
	_clear_level()
	if not player:
		if player_scene:
			player = player_scene.instantiate()
			player.add_to_group("player")
			add_child(player)
	# Choose spawn positions per level (with bounds safety)
	var p_pos: Vector2 = fallback_player_spawn
	var e_pos: Vector2 = fallback_enemy_spawn
	if current_level < player_spawn_positions.size():
		p_pos = player_spawn_positions[current_level]
	if current_level < enemy_spawn_positions.size():
		e_pos = enemy_spawn_positions[current_level]
	player.global_position = p_pos
	if player.has_method("reset_health"):
		player.reset_health()
	match current_level:
		0:
			enemy = fsm_enemy_scene.instantiate() if fsm_enemy_scene else null
		1:
			enemy = bt_enemy_scene.instantiate() if bt_enemy_scene else null
		2:
			enemy = nn_enemy_scene.instantiate() if nn_enemy_scene else null
		3:
			enemy = rl_enemy_scene.instantiate() if rl_enemy_scene else null
	if enemy:
		add_child(enemy)
		enemy.global_position = e_pos
		if enemy.has_signal("died"):
			enemy.connect("died", Callable(self, "_on_enemy_died"))
		if ui:
			ui.set_enemy(enemy)
	emit_signal("level_started", current_level)

func _clear_level():
	if enemy and is_instance_valid(enemy):
		enemy.queue_free()
	enemy = null

func _on_enemy_died():
	if ui:
		ui.set_enemy(null)
	if current_level >= 3:
		emit_signal("all_levels_complete")
		_show_end_menu()
	else:
		_start_level(current_level + 1)

func _show_end_menu():
	print("Todas as batalhas concluídas! Pressione R para reiniciar ou ESC para menu.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event.is_action_pressed("restart"):
		_start_level(0)

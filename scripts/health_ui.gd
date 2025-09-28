extends CanvasLayer
class_name HealthUI

@export var player_path: NodePath
@export var enemy_path: NodePath

var player_label: Label
var enemy_label: Label
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var current_enemy: Node = null

func _ready():
	player_label = Label.new()
	player_label.text = "Jogador"
	player_bar = ProgressBar.new()
	player_bar.min_value = 0
	player_bar.max_value = 100
	player_bar.value = 100
	player_bar.custom_minimum_size = Vector2(160, 12)
	player_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	enemy_label = Label.new()
	enemy_label.text = "Inimigo"
	enemy_bar = ProgressBar.new()
	enemy_bar.min_value = 0
	enemy_bar.max_value = 100
	enemy_bar.value = 100
	enemy_bar.custom_minimum_size = Vector2(160, 12)
	enemy_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	var vb = VBoxContainer.new()
	vb.anchor_right = 1
	vb.offset_right = 400
	add_child(vb)
	vb.add_child(player_label)
	vb.add_child(player_bar)
	vb.add_child(enemy_label)
	vb.add_child(enemy_bar)
	
	add_to_group("ui")
	await owner.ready
	call_deferred("_connect_player")

func _connect_player():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("health_changed"):
		player.connect("health_changed", Callable(self, "_on_player_health"))

func set_enemy(enemy: Node):
	if current_enemy and current_enemy.has_signal("health_changed") and current_enemy.is_connected("health_changed", Callable(self, "_on_enemy_health")):
		current_enemy.disconnect("health_changed", Callable(self, "_on_enemy_health"))
	current_enemy = enemy
	if enemy and enemy.has_signal("health_changed"):
		enemy.connect("health_changed", Callable(self, "_on_enemy_health"))
		# Update immediately
		var current = enemy.get_health()
		var max_h = enemy.max_health
		enemy_bar.max_value = max_h
		enemy_bar.value = current
		enemy_label.text = "Inimigo: %d/%d" % [current, max_h]
	else:
		enemy_bar.value = 0
		enemy_label.text = "Inimigo: 0/0"

func _on_player_health(current, max):
	player_bar.max_value = max
	player_bar.value = current
	player_label.text = "Jogador: %d/%d" % [current, max]

func _on_enemy_health(current, max):
	enemy_bar.max_value = max
	enemy_bar.value = current
	enemy_label.text = "Inimigo: %d/%d" % [current, max]

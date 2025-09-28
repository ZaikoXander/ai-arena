extends Control

@export var game_scene: PackedScene

func _ready():
	var vb = VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_top = 0.5
	vb.anchor_right = 0.5
	vb.anchor_bottom = 0.5
	vb.offset_left = -120
	vb.offset_top = -80
	vb.offset_right = 120
	vb.offset_bottom = 80
	add_child(vb)
	var title = Label.new()
	title.text = "AI Arena"
	title.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(title)
	var start_btn = Button.new()
	start_btn.text = "Iniciar"
	start_btn.pressed.connect(_on_start_pressed)
	vb.add_child(start_btn)
	var quit_btn = Button.new()
	quit_btn.text = "Sair"
	quit_btn.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit_btn)

func _on_start_pressed():
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)

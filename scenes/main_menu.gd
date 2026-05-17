extends Control

@onready var continue_button: Button = %ContinueButton
@onready var new_run_button: Button = %NewRunButton
@onready var quit_button: Button = %QuitButton

func _enter_tree() -> void:
    %ContinueButton.pressed.connect(_on_continue_pressed)
    %NewRunButton.pressed.connect(_on_new_run_pressed)
    %QuitButton.pressed.connect(_on_quit_pressed)

func _ready() -> void:
    continue_button.disabled = not SaveManager.has_save()

func _on_continue_pressed() -> void:
    if not SaveManager.has_save():
        return
    SaveManager.load_run()
    get_tree().change_scene_to_file("res://scenes/hud_battle.tscn")

func _on_new_run_pressed() -> void:
    SaveManager.save_run({})
    get_tree().change_scene_to_file("res://scenes/hud_battle.tscn")

func _on_quit_pressed() -> void:
    get_tree().quit()

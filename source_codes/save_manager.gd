extends Node

const SAVE_PATH := "user://savegame.save"

var last_run_data: Dictionary = {}

func save_run(data: Dictionary) -> void:
    last_run_data = data
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_var(data)

func load_run() -> Dictionary:
    if last_run_data.is_empty() and FileAccess.file_exists(SAVE_PATH):
        var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file:
            last_run_data = file.get_var()
    return last_run_data

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

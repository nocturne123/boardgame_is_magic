extends "res://source_codes/terrain/terrain_effect.gd"

## 雪地地形：站在其中时不能使用恢复牌。
## 实现：on_enter 设 meta "terrain_blocks_recovery" = true，on_exit 移除。

func _init() -> void:
    terrain_name = "雪地"

func on_enter(player: Player) -> void:
    player.set_meta("terrain_blocks_recovery", true)

func on_exit(player: Player) -> void:
    player.remove_meta("terrain_blocks_recovery")

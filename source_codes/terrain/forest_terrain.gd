extends "res://source_codes/terrain/terrain_effect.gd"

## 森林地形：进入时攻击距离 -1（最小 1）。
## 实现：on_enter 设 meta "terrain_attack_range_mod" = -1，on_exit 移除。

func _init() -> void:
    terrain_name = "森林"

func on_enter(player: Player) -> void:
    player.set_meta("terrain_attack_range_mod", -1)

func on_exit(player: Player) -> void:
    player.remove_meta("terrain_attack_range_mod")

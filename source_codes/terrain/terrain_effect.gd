class_name TerrainEffect extends Resource

## 地形效果基类。
## 子类重写 on_enter / on_exit / on_turn_start / on_turn_end 实现具体效果。
## 所有方法接收 player 参数，直接通过 meta 修改状态（pull 模型）。

## 地形显示名称
var terrain_name: String = ""

## 进入地形时触发
func on_enter(_player: Player) -> void:
    pass

## 离开地形时触发
func on_exit(_player: Player) -> void:
    pass

## 回合开始时触发（站在该地形上的角色的回合开始）
func on_turn_start(_player: Player) -> void:
    pass

## 回合结束时触发
func on_turn_end(_player: Player) -> void:
    pass

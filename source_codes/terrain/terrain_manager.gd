class_name TerrainManager extends Node

## 地形管理器。维护 tile → terrain_effect 映射，提供进入/离开/回合钩子。
## 由 HudBattle 创建，注入到每个 Player 的 meta "terrain_manager"。
## MoveAction / TurnStart 通过 player.get_meta("terrain_manager") 访问。
##
## 天马种族技能设 meta "terrain_immune" = true，所有效果跳过。

const _TerrainEffect = preload("res://source_codes/terrain/terrain_effect.gd")

## tile坐标(Vector2i) → TerrainEffect 实例
var _terrain_map: Dictionary = {}

## 记录每个玩家当前所在的地形 tile（用于离开检测）
var _player_tiles: Dictionary = {}  # Player → Vector2i


func add_terrain(cell: Vector2i, effect) -> void:
    _terrain_map[cell] = effect


func get_terrain_at(cell: Vector2i):
    return _terrain_map.get(cell, null)


func has_terrain(cell: Vector2i) -> bool:
    return _terrain_map.has(cell)


## 玩家移动到新格子时调用（由 MoveAction 触发）
func on_player_moved(player: Player, new_cell: Vector2i) -> void:
    if player == null:
        return
    var old_cell: Variant = _player_tiles.get(player, null)

    # 离开旧地形
    if old_cell != null and old_cell != new_cell:
        var old_effect = _terrain_map.get(old_cell, null)
        if old_effect:
            _apply_exit(player, old_effect)

    # 进入新地形
    _player_tiles[player] = new_cell
    var new_effect = _terrain_map.get(new_cell, null)
    if new_effect:
        _apply_enter(player, new_effect)


## 回合开始时调用（由 TurnStart 触发）
func on_turn_start(player: Player) -> void:
    if player == null:
        return
    var cell: Variant = _player_tiles.get(player, null)
    if cell == null:
        return
    var effect = _terrain_map.get(cell, null)
    if effect:
        _apply_turn_start(player, effect)


## 检查玩家是否被地形阻止使用恢复牌
func is_recovery_blocked(player: Player) -> bool:
    if player == null:
        return false
    return player.has_meta("terrain_blocks_recovery")


## 获取玩家当前的攻击距离修正
func get_attack_range_mod(player: Player) -> int:
    if player == null:
        return 0
    return player.get_meta("terrain_attack_range_mod", 0)


# ============================================================
# 内部：带天马免疫检查的效果应用
# ============================================================

func _apply_enter(player: Player, effect) -> void:
    if _is_immune(player):
        return
    effect.on_enter(player)

func _apply_exit(player: Player, effect) -> void:
    # 离开时即使免疫也要清理（防止之前非免疫时进入的效果残留）
    if _is_immune(player):
        # 免疫者不会有地形 meta，不需要清理
        return
    effect.on_exit(player)

func _apply_turn_start(player: Player, effect) -> void:
    if _is_immune(player):
        return
    effect.on_turn_start(player)


func _is_immune(player: Player) -> bool:
    return player.has_meta("terrain_immune") and player.get_meta("terrain_immune") == true

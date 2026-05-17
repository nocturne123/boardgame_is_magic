class_name TurnManager extends Node

## 全局回合调度器。
## 维护存活玩家的有序列表（规则中的全局循环链表）。
## 玩家死亡时立即从列表中移除。轮次为 player-relative（每个玩家独立计数）。

signal turn_started(player: Player)
signal turn_ended(player: Player)
signal player_eliminated(player: Player)
signal last_player_standing(winner: Player)

var _players: Array[Player] = []
var _current_index: int = 0

func setup(players: Array[Player]) -> void:
    _players = players.duplicate()
    _current_index = 0

func start_game(start_index: int = 0) -> void:
    if _players.is_empty():
        return
    _current_index = clampi(start_index, 0, _players.size() - 1)
    _start_turn_for(_players[_current_index])

func end_current_turn() -> void:
    if _players.is_empty():
        return
    var current: Player = _players[_current_index]
    turn_ended.emit(current)
    _advance_to_next_alive()
    if _players.is_empty():
        return
    var next_player: Player = _players[_current_index]
    _start_turn_for(next_player)

func _advance_to_next_alive() -> void:
    if _players.is_empty():
        return
    var start: int = _current_index
    while true:
        _current_index = (_current_index + 1) % _players.size()
        if _players[_current_index].living_state != Player.LivingState.Dead:
            break
        if _current_index == start:
            # 只剩死亡玩家（不应发生：remove_player 应在死亡时调用）
            break

func _start_turn_for(p: Player) -> void:
    p.health_last_turn = p.health
    var tree := p.get_node_or_null("ActionTree")
    if tree != null and tree.get("turn_start") != null:
        tree.chain_of_actions(tree.turn_start)
    turn_started.emit(p)

## 从轮转列表中移除玩家（应在 LivingUpdate 检测死亡后调用）。
func remove_player(p: Player) -> void:
    var idx := _players.find(p)
    if idx == -1:
        return
    _players.remove_at(idx)
    player_eliminated.emit(p)
    if _players.size() <= 1:
        if not _players.is_empty():
            last_player_standing.emit(_players[0])
    if idx < _current_index:
        _current_index -= 1
    elif _current_index >= _players.size():
        _current_index = 0

func get_current_player() -> Player:
    if _players.is_empty() or _current_index >= _players.size():
        return null
    return _players[_current_index]

func get_alive_count() -> int:
    var count := 0
    for p in _players:
        if p.living_state != Player.LivingState.Dead:
            count += 1
    return count

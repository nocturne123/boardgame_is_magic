class_name GlobalEffect
extends Resource

## 持续效果基类。由事件创建，注册到 EventManager.active_effects。
## 通过 pull 模型被 action 节点查询（ReceiveDamage/UseBaseplay/TurnStart），不使用回调钩子。

var effect_id: String = ""        ## 唯一实例 ID（自动生成）
var event_id: String = ""         ## 来源事件 ID
var triggerer: Player = null      ## 触发者
var duration_type: int = 0        ## EventCardData.DurationType
var affected_players: Array = []  ## 受影响的玩家列表
var effect_type: String = ""      ## 类型标签，供查询用

static var _id_counter: int = 0

func _init() -> void:
    _id_counter += 1
    effect_id = "effect_%d" % _id_counter

## 效果注册时调用（修改玩家状态，如 set_disabled）
func on_register(_event_manager) -> void:
    pass

## 效果移除时调用（恢复玩家状态）
func on_remove(_event_manager) -> void:
    pass

## 回合开始时检查，返回 true 表示过期
func check_expiry(_current_player: Player, _triggerer: Player) -> bool:
    return false

## 攻击端伤害修正（被 UseBaseplay 调用）。返回修正值（正=增伤，负=减伤）
func get_outgoing_damage_modifier(_player: Player, _damage_type: int) -> int:
    return 0

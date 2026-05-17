class_name EventCardData
extends Resource

## 事件牌基类。每个具体事件继承此类，重写 execute_instant / create_global_effect。
## 事件牌由 EventDeck 管理，独立于普通卡牌系统。

enum DurationType {
    INSTANT,                    ## 瞬时，无持续效果
    UNTIL_NEXT_TRIGGER_TURN,    ## 到下个触发者回合开始
    UNTIL_END_OF_NEXT_OWN_TURN, ## 到触发者下个回合结束
    CUSTOM                      ## 自定义（代码控制过期）
}

@export var event_id: String = ""
@export var nice_name: String = ""
@export var description: String = ""
@export var duration_type: DurationType = DurationType.INSTANT
@export var can_enter_hand: bool = false   ## true=事件牌进入触发者手牌（如魔法对决）

## 执行瞬时效果。由 EventManager 调用。
func execute_instant(_triggerer: Player, _event_manager, _all_players: Array) -> void:
    pass

## 创建持续效果（如果有）。由 EventManager 调用。
func create_global_effect(_triggerer: Player, _all_players: Array) -> GlobalEffect:
    return null

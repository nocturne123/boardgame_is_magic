class_name EventManager
extends Node

## 事件协调者。管理事件触发、级联、全局效果列表。
## 不直接修改 Player 状态——状态变更通过 ActionTree 动作完成。
## 持续效果通过 pull 模型被 action 节点查询（R7 合规）。

enum TriggerSource { EVENT_TRIGGER_CARD, SKILL, OTHER }

signal event_triggered(event_card: Resource, triggerer: Player)
signal global_effect_added(effect: GlobalEffect)
signal global_effect_removed(effect: GlobalEffect)
## 事件效果需要移动玩家时发射，HudBattle 监听后做坐标转换（R6 合规）
signal player_repositioned(player: Player, cube_pos: Vector3i)

var event_deck: EventDeck = null
var active_effects: Array[GlobalEffect] = []

## 触发事件。
## event_id 为空时从事件牌堆随机抽取。
## 事件后抽牌由调用方（EventTriggerPhase）负责，不在此处处理。
func trigger_event(event_id: String, triggerer: Player, source: int, all_players: Array) -> void:
    var event_card: Resource = null
    if event_id.is_empty():
        event_card = event_deck.draw_event()
        if event_card == null:
            return
    else:
        event_card = event_deck.create_event_by_id(event_id)
        if event_card == null:
            return

    event_triggered.emit(event_card, triggerer)

    # 执行瞬时效果（可能级联触发新事件）
    event_card.execute_instant(triggerer, self, all_players)

    # 创建持续效果（如果有）
    if event_card is EventCardData:
        var ec = event_card as EventCardData
        if ec.duration_type != EventCardData.DurationType.INSTANT:
            var effect = ec.create_global_effect(triggerer, all_players)
            if effect:
                register_effect(effect)
        # 进手牌的事件牌不进弃牌堆
        if not ec.can_enter_hand:
            event_deck.discard_event(event_card)
    else:
        event_deck.discard_event(event_card)

## 注册持续效果
func register_effect(effect: GlobalEffect) -> void:
    if effect == null:
        return
    active_effects.append(effect)
    effect.on_register(self)
    global_effect_added.emit(effect)

## 移除持续效果
func remove_effect(effect: GlobalEffect) -> void:
    if effect == null:
        return
    effect.on_remove(self)
    active_effects.erase(effect)
    global_effect_removed.emit(effect)

## 攻击端伤害修正（入戏太深等）。被 UseBaseplay 调用。
func get_outgoing_damage_modifiers(player: Player, damage_type: int) -> int:
    var total: int = 0
    for effect in active_effects:
        total += effect.get_outgoing_damage_modifier(player, damage_type)
    return total

## 回合开始时检查效果过期。被 TurnStart 调用。
func on_turn_start(player: Player) -> void:
    var expired: Array[GlobalEffect] = []
    for effect in active_effects:
        if effect.check_expiry(player, effect.triggerer):
            expired.append(effect)
    for effect in expired:
        remove_effect(effect)

## 请求移动玩家（通过信号通知 HudBattle 做坐标转换）
func reposition_player(p: Player, cube_pos: Vector3i) -> void:
    player_repositioned.emit(p, cube_pos)

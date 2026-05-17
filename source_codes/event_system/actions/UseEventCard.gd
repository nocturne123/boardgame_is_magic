class_name UseEventCard
extends BaseAction

## 打出事件手牌（如魔法对决）。
## 不消耗 attack_chance_in_turn。
## 卡牌用完后进入事件弃牌堆（不是普通弃牌堆）。

var card: CardData = null
var target: Player = null

func take_action() -> void:
    if card == null:
        return

    # 执行卡牌效果
    card.execute(player, target, player.card_manager)

    # 从手牌移除
    player.remove_card_from_hand(card)

    # 进入事件弃牌堆
    var event_mgr = player.get_meta("event_manager")
    if event_mgr and event_mgr.event_deck:
        event_mgr.event_deck.discard_event(card)

    # 不消耗 attack_chance_in_turn

func reset_property() -> void:
    card = null
    target = null


func _get_action_info() -> String:
    if card == null:
        return ""
    return "%s 打出了事件牌 [%s]" % [player.player_name, card.nice_name]

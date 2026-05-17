class_name EventTriggerPhase extends BaseAction

## 事件触发阶段。在 DrawCard 之后、出牌阶段之前执行。
## 检查手牌中的事件触发牌（来自初始手牌），依次打出。
## DrawCard 抽到的事件触发牌已经在 DrawCard 内部直接打出了，
## 这里只处理初始手牌中残留的事件触发牌。

func take_action() -> void:
    var event_mgr = player.get_meta("event_manager")
    if event_mgr == null:
        return
    var all_players = player.get_meta("all_players")
    if all_players == null:
        all_players = [player]

    # 循环打出手牌中的事件触发牌
    while true:
        var trigger_card = _find_event_trigger_card()
        if trigger_card == null:
            break

        # 1. 从手牌移除 → 进普通弃牌堆
        player.remove_card_from_hand(trigger_card)
        if player.card_manager:
            player.card_manager.receive_into_discard(trigger_card)

        # 2. 触发随机事件
        event_mgr.trigger_event("", player, EventManager.TriggerSource.EVENT_TRIGGER_CARD, all_players)

        # 3. 事件后抽牌：用 DrawCard._draw_one_card 统一逻辑
        #    如果抽到事件触发牌 → _draw_one_card 内部直接打出 + 递归
        var tree = player.get_node_or_null("ActionTree")
        if tree and tree.get("draw_card") != null:
            tree.draw_card._draw_one_card()
        else:
            _post_event_draw_simple()

## 简单事件后抽牌（fallback：无 DrawCard 时直接抽进手牌，然后循环检查）
func _post_event_draw_simple() -> void:
    if player.is_hand_at_max_capacity():
        return
    if player.card_manager == null:
        return
    var cards = player.card_manager.take_from_draw_pile(1)
    if cards.is_empty():
        return
    # 如果抽到事件触发牌，进手牌后由 while 循环打出
    player.add_card_to_hand(cards[0])

## 在手牌中查找第一张事件触发牌。
func _find_event_trigger_card() -> CardData:
    for card in player.hand:
        if card is EventTriggerCard:
            return card
    return null

func reset_property() -> void:
    pass


func _get_action_info() -> String:
    return "%s 的事件触发阶段" % player.player_name

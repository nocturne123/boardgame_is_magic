class_name DrawCard extends BaseAction

## 抽牌动作。抽到事件触发牌时不进手牌，直接打出触发事件。
## 事件结算后从普通抽牌堆摸 1 张牌（事件后抽牌）。
## 如果事件后抽牌又抽到事件触发牌 → 递归打出（级联）。

var draw_num: int = 0
var _drawn_count: int = 0

func take_action() -> void:
    _drawn_count = 0
    if player == null or player.card_manager == null:
        return
    for _i in range(draw_num):
        if player.is_hand_at_max_capacity():
            break
        var before_size: int = player.get_hand_size()
        _draw_one_card()
        if player.get_hand_size() > before_size:
            _drawn_count += 1

## 抽一张牌。如果是事件触发牌，直接打出 + 事件后抽牌（递归级联）。
func _draw_one_card() -> void:
    if player.is_hand_at_max_capacity():
        return
    var cards: Array[CardData] = player.card_manager.take_from_draw_pile(1)
    if cards.is_empty():
        return
    var card = cards[0]

    # 事件触发牌：不进手牌，直接打出
    if card is EventTriggerCard:
        player.card_manager.receive_into_discard(card)
        _trigger_event_and_post_draw()
    else:
        player.add_card_to_hand(card)

## 触发随机事件 + 事件后抽牌。
func _trigger_event_and_post_draw() -> void:
    var event_mgr = player.get_meta("event_manager")
    if event_mgr == null:
        return
    var all_players = player.get_meta("all_players")
    if all_players == null:
        all_players = [player]
    # 触发随机事件（EventManager 执行瞬时效果 + 持续效果注册）
    event_mgr.trigger_event("", player, EventManager.TriggerSource.EVENT_TRIGGER_CARD, all_players)
    # 事件后抽牌：从普通抽牌堆摸 1 张（可能又抽到事件触发牌 → _draw_one_card 内部递归）
    _draw_one_card()

func reset_property() -> void:
    draw_num = 0
    _drawn_count = 0


func _get_action_info() -> String:
    if _drawn_count > 0:
        return "%s 抽了 %d 张牌" % [player.player_name, _drawn_count]
    return ""

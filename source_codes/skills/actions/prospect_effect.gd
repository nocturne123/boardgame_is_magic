class_name ProspectEffect extends BaseAction

## 勘探效果：DrawCard 之后执行。
## 如果勘探已激活：peek 抽牌堆顶，手牌有同名牌则抽2张，否则 +1 护甲。

var _effect_text: String = ""

func take_action():
    _effect_text = ""
    var tree = get_parent() as ActionTree
    if tree == null:
        return
    var entry = tree.get_node_or_null("ProspectEntry")
    if entry == null or not entry.prospect_activated:
        return

    var cm = player.card_manager
    if cm == null:
        return
    var top_card = cm.peek_draw_pile()
    if top_card == null:
        return

    var has_match = false
    for cd in player.get_hand():
        if cd.nice_name == top_card.nice_name:
            has_match = true
            break

    if has_match:
        var cards = cm.take_from_draw_pile(2)
        for c in cards:
            if not player.is_hand_at_max_capacity():
                player.add_card_to_hand(c)
        _effect_text = "%s 勘探成功，额外抽了 2 张牌" % player.player_name
    else:
        player.armor = min(player.armor + 1, 4)
        _effect_text = "%s 勘探未中，护甲 +1" % player.player_name


func _get_action_info() -> String:
    return _effect_text

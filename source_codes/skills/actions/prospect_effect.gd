class_name ProspectEffect extends BaseAction

## 勘探效果：DrawCard 之后执行。
## 如果勘探已激活：peek 抽牌堆顶，手牌有同名牌则抽2张，否则 +1 护甲。

var _effect_text: String = ""

func take_action():
    _effect_text = ""
    var tree = get_parent() as ActionTree
    if tree == null:
        return
    # 读 ActionTree 上的临时标记（ProspectEntry.inform_next_action 写入）。
    # 不能读 entry.prospect_activated —— 它在本节点执行前已被 reset_property 清零。
    if not tree.get_meta("prospect_active_this_turn", false):
        return
    tree.set_meta("prospect_active_this_turn", false)   # 消费后立即清除

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
            if player.is_hand_at_max_capacity():
                # 手牌已满：牌已离开抽牌堆，必须进弃牌堆，否则凭空消失
                if player.card_manager:
                    player.card_manager.receive_into_discard(c)
            else:
                player.add_card_to_hand(c)
        _effect_text = "%s 勘探成功，额外抽了 2 张牌" % player.player_name
    else:
        player.armor = min(player.armor + 1, 4)
        _effect_text = "%s 勘探未中，护甲 +1" % player.player_name


func _get_action_info() -> String:
    return _effect_text

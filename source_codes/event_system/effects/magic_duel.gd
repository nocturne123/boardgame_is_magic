extends EventCardData

## 魔法对决：事件牌进入触发者手牌。打出时选择攻击范围内的对手，
## 如果手牌数大于对方，造成3点魔法伤害。
## 打出时不消耗 attack_chance_in_turn。

func execute_instant(triggerer: Player, _event_manager, _all_players: Array) -> void:
    var card = MagicDuelCard.new()
    card.nice_name = "魔法对决"
    card.type = "Event"
    card.identity = "magic_duel"
    card.description = "选择攻击范围内的对手，如果手牌数大于他，对其造成3点魔法伤害。"
    triggerer.add_card_to_hand(card)

class MagicDuelCard extends CardData:
    ## 打出时由 UseEventCard action 调用
    func execute(source: Player, target: Player, _card_manager: CardManager) -> bool:
        if target == null:
            return false
        if source.get_hand_size() > target.get_hand_size():
            var damage = Damage.new()
            damage.type = Damage.DamageType.Magic
            damage.num = 3
            var target_tree = target.get_node_or_null("ActionTree")
            if target_tree and target_tree.get("receive_damage") != null:
                target_tree.receive_damage.damage = damage
                # R14 保护：target 可能等于 source（同树嵌套），
                # 嵌套链会覆盖 _current_chain_action，跑完必须恢复外层链状态
                var saved: BaseAction = target_tree._current_chain_action
                target_tree.chain_of_actions(target_tree.receive_damage)
                target_tree._current_chain_action = saved
        return true

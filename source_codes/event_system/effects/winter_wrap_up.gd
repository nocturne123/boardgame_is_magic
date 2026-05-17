extends EventCardData

## 送冬迎春：所有玩家弃掉手中的法术攻击牌。

func execute_instant(_triggerer: Player, _event_manager, all_players: Array) -> void:
    for p in all_players:
        var to_discard: Array = []
        for card in p.hand:
            if card is BaseAttack:
                var attack = card as BaseAttack
                if attack.damage_type == Damage.DamageType.Magic:
                    to_discard.append(card)
        for card in to_discard:
            p.remove_card_from_hand(card)
            if p.card_manager:
                p.card_manager.receive_into_discard(card)

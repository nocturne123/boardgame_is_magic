class_name DiscardCard extends BaseAction

var card: CardData = null

func take_action() -> void:
    if player == null or card == null:
        return
    player.remove_card_from_hand(card)
    if player.card_manager:
        player.card_manager.receive_into_discard(card)

func reset_property() -> void:
    card = null


func _get_action_info() -> String:
    if card == null:
        return ""
    return "%s 弃掉了 [%s]" % [player.player_name, card.nice_name]

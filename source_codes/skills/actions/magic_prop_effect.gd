class_name MagicPropEffect extends BaseAction

## 魔术道具的「效果牌」路径。
## 规则：选择一张效果牌 → 弃置该牌 → 移动次数 +1（不走该牌自身的 execute）。
## 由 HudBattle 动态创建并通过 chain_of_actions 执行。
## R7：效果逻辑属于技能/动作层，不写在 HUD 里。

var card: CardData = null
var extra_move: int = 1
var _info: String = ""

func take_action() -> void:
    _info = ""
    if player == null or card == null:
        return
    player.remove_card_from_hand(card)
    # 虚拟牌（identity 以 __ 开头）不进弃牌堆，避免污染牌库
    if not card.identity.begins_with("__") and player.card_manager:
        player.card_manager.receive_into_discard(card)
    player.move_chance_in_turn += extra_move
    _info = "%s 弃置 [%s]（魔术道具），移动 +%d" % [player.player_name, card.nice_name, extra_move]

func reset_property() -> void:
    card = null
    extra_move = 1


func _get_action_info() -> String:
    return _info

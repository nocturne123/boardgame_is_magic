class_name AddMoveChance extends BaseAction

## 增加移动次数动作。供魔术道具等技能的效果牌路径使用。
## HudBattle 不直接改 move_chance_in_turn（R1/R2 合规），
## 通过 chain_of_actions(add_move_chance) 由 ActionTree 修改。

var amount: int = 1

func take_action() -> void:
    if player == null:
        return
    player.move_chance_in_turn += amount

func reset_property() -> void:
    amount = 1


func _get_action_info() -> String:
    if amount <= 0:
        return ""
    return "%s 增加 %d 次移动机会" % [player.player_name, amount]

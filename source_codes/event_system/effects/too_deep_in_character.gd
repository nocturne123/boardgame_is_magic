extends EventCardData

## 入戏太深：到触发者下个回合结束，触发者造成的心理伤害+2。

func create_global_effect(triggerer: Player, _all_players: Array) -> GlobalEffect:
    var effect = TooDeepEffect.new()
    effect.triggerer = triggerer
    effect.affected_players = [triggerer]
    effect.duration_type = EventCardData.DurationType.UNTIL_END_OF_NEXT_OWN_TURN
    effect.event_id = "too_deep_in_character"
    effect.effect_type = "outgoing_mental_boost"
    return effect

class TooDeepEffect extends GlobalEffect:
    var boost_amount: int = 2
    var _triggerer_had_turn: bool = false

    ## 攻击端心理伤害修正（被 UseBaseplay pull 查询）
    func get_outgoing_damage_modifier(player: Player, damage_type: int) -> int:
        if player in affected_players and damage_type == Damage.DamageType.Mental:
            return boost_amount
        return 0

    ## 触发者下个回合开始后，效果在下一次 check_expiry 时过期（即下个回合结束后）
    func check_expiry(current_player: Player, triggerer: Player) -> bool:
        if _triggerer_had_turn:
            return true  # 触发者的下个回合已过，效果过期
        if current_player == triggerer:
            _triggerer_had_turn = true  # 标记触发者的下个回合已开始
        return false

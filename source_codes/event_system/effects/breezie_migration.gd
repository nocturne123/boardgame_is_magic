extends EventCardData

## 布里兹迁徙：到下个触发者回合开始，所有玩家失去种族技能。

func create_global_effect(triggerer: Player, all_players: Array) -> GlobalEffect:
    var effect = BreezieMigrationEffect.new()
    effect.triggerer = triggerer
    effect.affected_players = all_players.duplicate()
    effect.duration_type = EventCardData.DurationType.UNTIL_NEXT_TRIGGER_TURN
    effect.event_id = "breezie_migration"
    effect.effect_type = "disable_species_skill"
    return effect

class BreezieMigrationEffect extends GlobalEffect:
    ## 注册时禁用所有玩家的种族技能
    func on_register(_event_manager) -> void:
        for p in affected_players:
            for skill in p.skills:
                if skill.category == SkillData.Category.Species:
                    skill.set_disabled(true, p)

    ## 移除时恢复种族技能
    func on_remove(_event_manager) -> void:
        for p in affected_players:
            for skill in p.skills:
                if skill.category == SkillData.Category.Species:
                    skill.set_disabled(false, p)

    ## 触发者的回合再次开始时过期
    func check_expiry(current_player: Player, triggerer: Player) -> bool:
        return current_player == triggerer

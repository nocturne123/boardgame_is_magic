class_name TurnStart extends BaseAction

#有大量的动作节点会夹在开始回合和抽牌之间
func take_action():
    #回合数加一
    player.turn_count += 1
    player.round_count += 1
    
    #重置玩家动次数和攻击次数
    player.move_chance_in_turn = player.move_chance
    player.attack_chance_in_turn = player.attack_chance

    #清除晕厥免伤标记（苏醒后下回合开始时解除）
    player.immune_from_attack = false

    # ★ 全局效果过期检查（布里兹迁徙、入戏太深等）
    var event_mgr = player.get_meta("event_manager")
    if event_mgr:
        event_mgr.on_turn_start(player)

    # ★ 地形回合开始效果
    var terrain_mgr = player.get_meta("terrain_manager")
    if terrain_mgr and terrain_mgr.has_method("on_turn_start"):
        terrain_mgr.on_turn_start(player)

func inform_next_action():
    if next_action and next_action.get("draw_num") != null:
        next_action.draw_num = player.draw_stage_card_number


func _get_action_info() -> String:
    return "%s 的回合开始（第 %d 回合）" % [player.player_name, player.turn_count]

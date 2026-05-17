extends EventCardData

## 龙卷供水：场上所有天马移动到云宝家 cube(2,0,-2)，并立即摸两张牌。

func execute_instant(_triggerer: Player, event_manager, all_players: Array) -> void:
    var cloudsdale_cube = Vector3i(2, 0, -2)
    for p in all_players:
        if p.species == Player.Species.Pegasi:
            # 移动到云宝家（通过信号通知 HudBattle 做坐标转换）
            event_manager.reposition_player(p, cloudsdale_cube)
            # 摸 2 张牌（通过 DrawCard action，内部检查事件触发牌级联）
            var tree = p.get_node_or_null("ActionTree")
            if tree and tree.get("draw_card") != null:
                tree.draw_card.draw_num = 2
                tree.draw_card.take_action()

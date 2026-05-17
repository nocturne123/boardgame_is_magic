class_name DecreaseHealth extends BaseAction

#需要的信息，每个节点的信息不一定相同
var decrease_num:int
var skip_armor: bool = false
var _armor_absorbed: int = 0
var _health_lost: int = 0

func take_action():
    _armor_absorbed = 0
    _health_lost = 0
    var remaining: int = max(decrease_num, 0)
    if not skip_armor and player.armor > 0 and remaining > 0:
        var used: int = min(player.armor, remaining)
        player.armor -= used
        remaining -= used
        _armor_absorbed = used
    if remaining > 0:
        player.health -= remaining
        _health_lost = remaining
        # 存活状态判定由 LivingUpdate 负责（含晕厥/苏醒逻辑）

func reset_property():
    decrease_num = 0
    skip_armor = false
    _armor_absorbed = 0
    _health_lost = 0


func _get_action_info() -> String:
    var parts: Array[String] = []
    if _armor_absorbed > 0:
        parts.append("护甲吸收 %d 点" % _armor_absorbed)
    if _health_lost > 0:
        parts.append("生命值 -%d" % _health_lost)
    if parts.is_empty():
        return ""
    return "%s：%s" % [player.player_name, "，".join(parts)]

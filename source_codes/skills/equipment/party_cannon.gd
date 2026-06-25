class_name PartyCannon extends SkillData

## 派对大炮装备技能：攻击后进行一次 D6 判定（难度 3），成功则恢复 1 点体力。
## 可开关被动：点击技能槽切换。
##
## 链条：PartyCannonRecovery → RollDiceEntry → [Calm?]RollDiceExecute → PartyCannonResult

func _init() -> void:
    id = "party_cannon_recovery"
    nice_name = "派对时间"
    category = SkillData.Category.Equipment
    skill_type = SkillData.SkillType.Passive
    description = "攻击后进行一次 D6 判定（难度 3），成功则恢复 1 点体力。可开关。"
    ignore_distance = false
    range = -1
    cooldown = 0
    max_uses_per_turn = 0
    needs_target = false

func on_attach(player: Player) -> void:
    if is_disabled():
        return
    var tree = _get_action_tree(player)
    if tree == null:
        return
    _create_action_node(tree,
        "res://source_codes/skills/actions/party_cannon_recovery.gd",
        "PartyCannonRecovery")
    _create_action_node(tree,
        "res://source_codes/skills/actions/party_cannon_result.gd",
        "PartyCannonResult")
    player.set_meta("party_cannon_enabled", true)

func on_detach(player: Player) -> void:
    player.remove_meta("party_cannon_enabled")
    super.on_detach(player)

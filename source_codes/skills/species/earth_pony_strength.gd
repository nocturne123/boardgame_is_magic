class_name EarthPonyStrength extends SkillData

## 蛮力（陆马种族技能）：打出攻击牌时掷骰，>=3 则伤害+1。
## 开关技能，默认开启。开启时在 UseCard→UseBaseplay 之间插入掷骰链。

var enabled: bool = true

func _init() -> void:
    id = "earth_pony_strength"
    nice_name = "蛮力"
    category = SkillData.Category.Species
    skill_type = SkillData.SkillType.Passive
    description = "打出攻击牌时，可以掷一个骰子，结果≥3则伤害+1"
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
    var entry = _create_action_node(tree,
        "res://source_codes/skills/actions/strength_roll_entry.gd", "StrengthRollEntry")
    var execute = _create_action_node(tree,
        "res://source_codes/skills/actions/strength_roll_execute.gd", "StrengthRollExecute")
    entry.next_action = execute
    tree.use_card.set_meta("strength_entry", entry)
    tree.use_card.set_meta("strength_execute", execute)

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree != null and tree.use_card:
        tree.use_card.remove_meta("strength_entry")
        tree.use_card.remove_meta("strength_execute")
    super.on_detach(player)

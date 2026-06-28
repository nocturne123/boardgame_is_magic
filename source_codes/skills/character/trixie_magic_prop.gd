class_name TrixieMagicProp extends SkillData

## 魔术道具（特丽克西角色技能）：
## 弃置武器/防具牌 → 选择攻击类型 → 造成对应属性伤害。
## 弃置效果牌 → 增加一次移动机会。
## 选牌和弃牌在 HUD 对话框完成，action 只处理武器/防具路径。

func _init() -> void:
    id = "trixie_magic_prop"
    nice_name = "魔术道具"
    category = SkillData.Category.Character
    skill_type = SkillData.SkillType.Active
    description = "弃置一张武器/防具牌视为打出指定类型攻击牌；弃置一张效果牌增加一次移动机会。"
    ignore_distance = true
    range = -1
    cooldown = 0
    max_uses_per_turn = 0
    needs_target = false
    needs_card_discard = false

func on_attach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree == null:
        return
    _create_action_node(tree,
        "res://source_codes/skills/actions/trixie_magic_prop_action.gd",
        "TrixieMagicPropAction")

func get_action_node(tree: ActionTree) -> BaseAction:
    return tree.get_node_or_null("TrixieMagicPropAction") as BaseAction

func on_detach(player: Player) -> void:
    super.on_detach(player)

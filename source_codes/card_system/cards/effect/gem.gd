class_name Gem extends BaseEffect

## 宝石：设置「下次心理攻击 +1 伤害并无视防具」的 buff，使用后进入收藏品栏。
## buff 由 ReceiveDamage 在下次心理攻击时自动消费并清零。

func _init() -> void:
    goes_to_collection_after_use = true

func format_description() -> String:
    return "下次心理攻击伤害+1，无视防具；使用后进入收藏品栏位"

func execute(source: Player, _target: Player, _card_manager: CardManager) -> bool:
    source.next_mental_bonus = 1
    source.next_mental_ignore_armor = true
    return true

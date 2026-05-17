class_name BaseRecovery extends BaseEffect

## 恢复牌：效果牌的子类，用于回复生命等恢复类效果。所有 type 为 Recovery 的卡牌可继承此类。
## 默认 resolve 返回 null，子类重写以实现具体恢复逻辑。

func resolve(_source: Player, _target: Player) -> Variant:
    return null

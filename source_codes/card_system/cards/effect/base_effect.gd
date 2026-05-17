class_name BaseEffect extends Baseplay

## 效果类卡牌的基类，所有 Effect 类型卡牌脚本应继承此类并实现 resolve。

func format_description() -> String:
    return description if description else ""

func resolve(_source: Player, _target: Player) -> Variant:
    return null

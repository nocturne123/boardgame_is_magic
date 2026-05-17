class_name EventTrigger extends Baseplay

## 事件触发牌。当玩家抽取到此牌时自动触发事件，事件结算完成后玩家再抽一张牌。
## 触发逻辑在战斗场景中根据 card_drawn 信号处理，此处 resolve 仅作打出时（若可打出）的占位。

func format_description() -> String:
    return "抽取时触发事件，结算后再抽一张牌"

func resolve(_source: Player, _target: Player) -> Variant:
    return null

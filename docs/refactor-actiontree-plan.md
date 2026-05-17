# Player 重构方案：ActionTree 统一操作入口

> 状态：方案阶段，待实施
> 更新：2026-06-19
> 目标：Player 瘦身为纯数据类，所有状态变更统一走 ActionTree 动作链

## 目标架构

```
HudBattle (协调层：UI + 输入 + 信号路由)
  │
  ├── 用户点击/按键 → 设置 Action 参数 → chain_of_actions(begin)
  │
  ├── TurnManager → 回合事件 → chain_of_actions(tree.turn_start)
  │
  └── 坐标系同步（cube_position）→ 动作链完成后由 HudBattle 处理

Player (纯数据类)
  ├── @export 数据字段（只读/外部写入）
  ├── 查询方法（get_hand, get_equipment_in_slot, ...）
  ├── 简单 setter（move_to_position 只设 map_position）
  └── card_manager 引用（只读依赖）

ActionTree (操作层)
  ├── MoveAction    — 移动：设置 map_position + 递减 move_chance
  ├── DrawCard      — 抽牌：从 card_manager 抽牌加入手牌
  ├── DiscardCard   — 弃牌：从手牌移除 + 移入弃牌堆
  ├── UseCard       — 用牌：execute/resolve 卡牌效果
  ├── TurnStart     — 回合开始：递增 turn_count + 重置次数 + 衔接 DrawCard
  ├── ReceiveDamage — 承伤：计算最终伤害值
  ├── DecreaseHealth— 扣血：护甲→HP（逻辑已内联到动作中，Player._apply_direct_damage 已删除）
  └── LivingUpdate  — 存活检查：HP≤0 → Dead
```

---

## 第一阶段：Player 瘦身

### 移除的方法（迁移到 ActionTree）

| 方法 | 当前位置 | 迁移到 |
|------|----------|--------|
| `draw_cards(count)` | Player | DrawCard.take_action() |
| `discard_card(card)` | Player | DiscardCard.take_action() |
| `apply_damage(damage)` | Player | ReceiveDamage + DecreaseHealth |
| `calculate_received_damage(damage)` | Player | ReceiveDamage（已有重复实现） |
| `_apply_direct_damage(amount, skip_armor)` | Player | ✅ DecreaseHealth（已内联） |
| `init_hand_from_nice_names()` | Player | 内联到 HudBattle._setup_players() |

### 保留的内容

- 所有 `@export var` 数据字段
- `equipment` / `hand` 容器
- 查询方法：`get_hand()`, `get_hand_size()`, `is_hand_at_max_capacity()`, `get_equipment_in_slot()`, `has_equipment_in_slot()`, `is_collection_item()`, `get_slot_of_card()`
- `add_card_to_hand()` / `remove_card_from_hand()` — 保留为基础操作，由 Action 调用
- `move_to_position(target)` — 简化为纯 setter：只设 `map_position`
- `card_manager` 引用

### 暂不碰的内容

- 装备系统 (`equip_to_slot`, `unequip_from_slot`, `move_to_collection_slot` 等)
- `collection_item_ids` 相关逻辑
- `next_attack_ignore_armor` / `next_attack_mental_plus`

---

## 第二阶段：Action 改造

### MoveAction

```
// 增强 take_action()
func take_action() -> void:
    if player == null:
        return
    player.move_to_position(target_cell)
    player.move_chance_in_turn -= 1
```

现状：逻辑已正确，HudBattle 绕过它直接调 Player。
改动：HudBattle 改为 `tree.chain_of_actions(tree.move_action)`。
cube_position 同步由 HudBattle 在动作链完成后处理。

### DrawCard

```
// 重写 take_action()
func take_action() -> void:
    if player == null or player.card_manager == null:
        return
    for _i in range(draw_num):
        if player.is_hand_at_max_capacity():
            return
        var cards = player.card_manager.take_from_draw_pile(1)
        if cards.is_empty():
            return
        player.add_card_to_hand(cards[0])
```

### DiscardCard

```
// 重写 take_action()
var card: CardData = null

func take_action() -> void:
    if player == null or card == null:
        return
    player.remove_card_from_hand(card)
    if player.card_manager:
        player.card_manager.receive_into_discard(card)
```

### ActionTree 默认链扩展

```
// 新增 TurnStart → DrawCard 链
func make_default_chain() -> void:
    receive_damage.next_action = decrease_health
    decrease_health.next_action = living_update
    turn_start.next_action = draw_card  # 新增
```

---

## 第三阶段：HudBattle 改造

### 移动流程

```
// 改造前
_on_move_requested(target_cell):
    _move_source.move_to_position(target_cell)
    _move_source.move_chance_in_turn -= 1
    _move_source.cube_position = map_node.map_to_cube(target_cell)
    ...

// 改造后
_on_move_requested(target_cell):
    var tree = _move_source.get_node("ActionTree")
    tree.move_action.target_cell = target_cell
    tree.chain_of_actions(tree.move_action)
    # 动作链完成后同步 cube（坐标系转换是 HudBattle 的职责）
    _move_source.cube_position = map_node.map_to_cube(target_cell)
    ...
```

### 抽牌流程

```
// 改造前
_on_turn_started(controller):
    controller.draw_cards(controller.draw_stage_card_number)
    ...

// 改造后：TurnManager._start_turn_for_player 已触发 TurnStart 链
// → TurnStart.take_action() 设置 turn_count + 重置次数
// → TurnStart.inform_next_action() 设置 draw_card.draw_num
// → DrawCard.take_action() 执行抽牌
// → HudBattle 只需处理 UI 更新，不直接调 draw_cards
_on_turn_started(controller):
    # 抽牌由 TurnStart→DrawCard 链自动完成
    _log("...")
    _update_all_ui()
```

### 用牌流程

```
// 不变：当前已正确走 ActionTree
_on_card_use_requested(card_data, source, target):
    var tree = source.get_node_or_null("ActionTree")
    if tree != null and tree.get("use_card") != null:
        tree.use_card.card = card_data
        tree.use_card.target = target
        tree.chain_of_actions(tree.use_card)
    ...
```

---

## 改动清单

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `player.gd` | 删除方法 | 移除 draw_cards, discard_card, apply_damage, calculate_received_damage, _apply_direct_damage, init_hand_from_nice_names |
| `player.gd` | 简化 | move_to_position 只设 map_position（去重已有的逻辑） |
| `MoveAction.gd` | 增强 | take_action 已有正确逻辑（可能无需改动） |
| `DrawCard.gd` | 重写 | 实现 take_action（从 card_manager 抽牌加入手牌） |
| `DiscardCard.gd` | 重写 | 实现 take_action（从手牌移除并移入弃牌堆） |
| `ActionTree.gd` | 扩展链 | make_default_chain 新增 turn_start → draw_card |
| `hud_battle.gd` | 改造 | _on_move_requested 走 ActionTree，_on_turn_started 删除 draw_cards 调用 |
| `hud_battle.gd` | 改造 | _setup_players 内联 init_hand_from_nice_names 逻辑 |

---

## 实施顺序

1. **DrawCard / DiscardCard 重写** — 先让这两个动作独立可用
2. **ActionTree 扩展链** — 加 TurnStart → DrawCard
3. **Player 瘦身** — 删除迁移掉的方法
4. **HudBattle 改造** — 改为通过 ActionTree 协调
5. **测试更新** — 修正直接调用 Player 方法的测试用例
6. **运行验证** — 确保 hud_battle 正常工作

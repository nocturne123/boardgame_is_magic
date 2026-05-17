# 事件系统设计文档

## 1. 系统概述

事件系统是独立于普通卡牌系统的全局机制。事件由**事件触发牌**或**技能**触发，可以影响所有玩家、地图、甚至其他事件。

### 核心概念

| 概念 | 说明 |
|------|------|
| **事件触发牌** | 在普通抽牌堆中，抽到时立即触发事件。触发后进普通弃牌堆 |
| **事件牌** | 在独立的事件牌堆中，事件触发时从中抽取。用后进事件弃牌堆 |
| **瞬时效果** | 事件触发时立即执行的效果（摸牌、移动、弃牌、伤害等） |
| **持续效果** | 注册到全局效果列表，在特定时机影响玩家（禁用技能、伤害修正等） |
| **事件级联** | 事件的瞬时效果可能触发其他事件（如摸牌摸到事件触发牌），按触发顺序依次结算 |
| **触发者** | 打出事件触发牌或触发事件的玩家 |
| **触发来源** | EVENT_TRIGGER_CARD（事件触发牌）/ SKILL（技能）/ OTHER（其他） |

### 事件触发牌的行为

1. 抽到事件触发牌时，**不进手牌**，立即触发事件
2. 事件触发牌执行两件事：
   - 从事件牌堆抽一张事件牌，执行其瞬时效果
   - 所有瞬时效果（含级联）结算完成后，触发者从普通抽牌堆摸 1 张牌
3. 如果事件触发者又摸到事件触发牌 → 再次触发（循环）
4. 技能触发的事件：只有瞬时效果，**没有**事件后抽牌

### 事件后抽牌的时机

```
事件触发牌打出
  → 从事件牌堆抽事件牌
  → 执行瞬时效果
    → 如果瞬时效果中摸牌摸到事件触发牌 → 级联触发新事件
    → 新事件的瞬时效果执行完
    → 回到上级继续执行
  → 所有瞬时效果结算完成
  → 触发者从普通抽牌堆摸 1 张牌
  → 如果摸到事件触发牌 → 再次触发（循环）
```

---

## 2. 架构设计

### 组件关系图

```
┌──────────────────────────────────────────────────────────────┐
│                        HudBattle                              │
│  - 初始化 EventManager / EventDeck                            │
│  - 全局效果面板 UI                                            │
│  - 事件牌堆 / 事件弃牌堆 sprite                               │
│  - 连接 event_triggered 信号 → 日志/UI 更新                   │
└──────┬───────────────────────────────────────┬───────────────┘
       │                                       │
       ▼                                       ▼
┌──────────────────┐              ┌─────────────────────────┐
│   EventManager    │              │      EventDeck           │
│   (logic 下)      │              │      (logic 下)          │
│                   │              │                         │
│ - active_effects  │◀────引用────│ - _event_pile           │
│ - trigger_event() │              │ - _event_discard_pile   │
│ - register_effect │              │ - draw_event()          │
│ - remove_effect   │              │ - discard_event()       │
│ - get_effects()   │              │ - shuffle()             │
└────┬──────────────┘              └─────────────────────────┘
     │
     ▼
┌──────────────────┐
│  GlobalEffect     │
│  (Resource)       │
│                   │
│ - effect_id       │
│ - event_id        │
│ - triggerer       │
│ - duration_type   │
│ - affected_players│
│ - apply()/remove()│
│ - on_turn_start() │
│ - is_expired()    │
└──────────────────┘
```

### 与现有系统的交互

```
TurnStart → DrawCard → EventTriggerPhase → (出牌阶段)
  │                        │
  │                        ▼
  │                   检查手牌中的事件触发牌
  │                   ┌─有→打出→触发事件→事件后抽牌→循环
  │                   └─无→出牌阶段开始
  │
  ▼
ReceiveDamage → DecreaseHealth → LivingUpdate
  │
  ▼ (检查 EventManager 全局效果)
RollDiceEntry → RollDiceExecute
MoveAction（单独触发）
UseCard（单独触发，通过箭头交互）
```

### 架构合规性

- **R2（状态变更走 ActionTree）**：事件瞬时效果通过 ActionTree 动作执行（DrawCard、MoveAction、DiscardCard 等），或通过 TriggerEvent action 节点编排
- **R7（不用回调钩子）**：持续效果通过 action 节点检查 EventManager.active_effects 实现（pull 模型），不是 connect 信号
- **EventManager 是协调者**，不是状态变更者。它管理效果列表（数据），实际状态变更由 action 节点完成

---

## 3. 核心组件

### 3.1 EventCardData (Resource)

```gdscript
class_name EventCardData extends Resource

enum DurationType {
    INSTANT,                    # 瞬时，无持续效果
    UNTIL_NEXT_TRIGGER_TURN,    # 到下个触发者回合开始（布里兹迁徙）
    UNTIL_END_OF_NEXT_OWN_TURN, # 到触发者下个回合结束（入戏太深）
    CUSTOM                      # 自定义（代码控制）
}

@export var event_id: String
@export var nice_name: String
@export var description: String
@export var duration_type: DurationType
@export var can_enter_hand: bool = false   # 魔法对决 = true
@export var instant_effect_script: String  # 效果脚本路径

## 执行瞬时效果。由 EventManager 调用。
func execute_instant(_triggerer: Player, _event_manager: EventManager, _all_players: Array) -> void:
    pass

## 创建持续效果（如果有）。由 EventManager 调用。
func create_global_effect(_triggerer: Player, _all_players: Array) -> GlobalEffect:
    return null
```

### 3.2 EventDeck (Node)

```gdscript
class_name EventDeck extends Node

var _event_pile: Array[EventCardData] = []
var _event_discard_pile: Array[EventCardData] = []
var _database: Array = []  # 原始 JSON

func load_database(path: String) -> void
func reset() -> void          # 从数据库重建牌堆，洗牌
func draw_event() -> EventCardData  # 抽一张事件牌
func discard_event(card: EventCardData) -> void  # 放入事件弃牌堆
func get_pile_size() -> int
func get_discard_size() -> int
```

- 事件牌堆**默认洗牌**（与普通抽牌堆不同）
- 事件牌用完后不自动洗弃牌堆（事件数量有限）

### 3.3 EventManager (Node)

```gdscript
class_name EventManager extends Node

signal event_triggered(event_card: EventCardData, triggerer: Player)
signal global_effect_added(effect: GlobalEffect)
signal global_effect_removed(effect: GlobalEffect)

var event_deck: EventDeck
var active_effects: Array[GlobalEffect] = []

## 触发事件。source 决定是否有事件后抽牌。
func trigger_event(event_id: String, triggerer: Player, source: int, all_players: Array) -> void:
    # 1. 从事件牌堆抽事件牌
    # 2. 执行瞬时效果
    # 3. 处理级联（瞬时效果中可能触发新事件）
    # 4. 如果 source == EVENT_TRIGGER_CARD，触发者摸 1 张牌
    #    - 摸牌可能再次抽到事件触发牌 → 递归

## 注册持续效果
func register_effect(effect: GlobalEffect) -> void
## 移除持续效果
func remove_effect(effect: GlobalEffect) -> void
## 查询指定类型的效果
func get_effects_of_type(type_name: String) -> Array[GlobalEffect]
## 查询指定玩家身上的伤害修正效果
func get_damage_modifiers(player: Player, damage_type: int) -> int
## 回合开始时检查效果过期
func on_turn_start(player: Player) -> void
```

### 3.4 GlobalEffect (Resource)

```gdscript
class_name GlobalEffect extends Resource

var effect_id: String          # 唯一实例 ID（自动生成）
var event_id: String           # 来源事件
var triggerer: Player          # 触发者
var duration_type: int         # DurationType
var affected_players: Array[Player]
var effect_type: String        # 类型标签，供查询用

## 效果注册时调用（修改玩家状态，通过 set_disabled 等）
func on_register(_event_manager: EventManager) -> void
## 效果移除时调用（恢复玩家状态）
func on_remove(_event_manager: EventManager) -> void
## 回合开始时检查，返回 true 表示过期
func check_expiry(current_player: Player, triggerer: Player) -> bool
```

### 3.5 EventTriggerCard (extends Baseplay)

事件触发牌是普通卡牌，在 `card_database.json` 中定义，在 `normal_drawpile.json` 中出现。

```gdscript
class_name EventTriggerCard extends Baseplay

## 事件触发牌不进手牌，不通过 UseCard 打出。
## DrawCard 抽到时检查类型，如果是 EventTriggerCard 则触发事件。
```

---

## 4. 事件触发流程

### 4.1 DrawCard（抽到事件触发牌直接打出）

DrawCard 抽到事件触发牌时不进手牌，直接打出：触发事件 → 事件后抽牌（递归级联）。

```
DrawCard._draw_one_card():
  1. 从抽牌堆抽 1 张牌
  2. 如果是事件触发牌:
     a. 进普通弃牌堆
     b. EventManager.trigger_event("", player, EVENT_TRIGGER_CARD, all_players)
     c. 事件后抽牌：_draw_one_card()  ← 递归（如果又抽到事件触发牌则继续打出）
  3. 否则: 进手牌
```

这样无论是回合开始 DrawCard 还是出牌阶段点击抽牌堆，抽到事件触发牌都会直接打出。

### 4.2 EventTriggerPhase（处理初始手牌中的事件触发牌）

初始手牌不经过 DrawCard（由 `_draw_initial_hands` 直接抽），事件触发牌会进手牌。
EventTriggerPhase 在 DrawCard 之后执行，循环检查手牌中的事件触发牌并打出：

```
EventTriggerPhase.take_action():
  loop:
    1. 在手牌中查找 EventTriggerCard
    2. 如果没有 → break（进入正常出牌阶段）
    3. 从手牌移除事件触发牌 → 进普通弃牌堆
    4. EventManager.trigger_event("", player, EVENT_TRIGGER_CARD, all_players)
    5. 事件后抽牌：调用 DrawCard._draw_one_card()
       └─ 如果抽到事件触发牌 → DrawCard 内部直接打出 + 递归
    6. 回到步骤 1（如果手牌中还有事件触发牌则继续）
```

### 4.3 EventManager.trigger_event 简化

EventManager 只负责执行事件效果，不负责事件后抽牌（由 EventTriggerPhase 处理）：

```
trigger_event(event_id, triggerer, source, all_players):
    1. event_card = event_deck.draw_event()  # 随机抽
    2. event_triggered 信号发射
    3. event_card.execute_instant(triggerer, self, all_players)
    4. 创建持续效果（如果有）→ register_effect()
    5. 非 can_enter_hand 的事件牌进事件弃牌堆
    # 不做事件后抽牌
```

技能触发的事件直接调用 `trigger_event`，没有事件后抽牌。

---

## 5. 全局效果系统

### 5.1 效果检查点

全局效果在以下 action 节点中被检查（pull 模型）：

| 检查点 | Action 节点 | 检查内容 |
|--------|------------|---------|
| 伤害结算前 | ReceiveDamage | 查询 `get_damage_modifiers(player, damage_type)` 修正伤害 |
| 回合开始 | TurnStart | 调用 `event_manager.on_turn_start(player)` 检查过期 |
| 技能使用 | UseCard | 查询是否有禁用技能的效果 |

### 5.2 ReceiveDamage 修改

```gdscript
func take_action():
    # ... 现有防御计算 ...
    
    # ★ 全局效果伤害修正
    var event_mgr = player.get_meta("event_manager")
    if event_mgr:
        received_damage += event_mgr.get_damage_modifiers(player, damage.type)
    
    if received_damage < 0:
        received_damage = 0
    out_put_num = received_damage
```

### 5.3 TurnStart 修改

```gdscript
func take_action():
    # ... 现有回合初始化 ...
    
    # ★ 全局效果过期检查
    var event_mgr = player.get_meta("event_manager")
    if event_mgr:
        event_mgr.on_turn_start(player)
```

### 5.4 过期逻辑

```gdscript
# EventManager
func on_turn_start(player: Player) -> void:
    var expired: Array[GlobalEffect] = []
    for effect in active_effects:
        if effect.check_expiry(player, effect.triggerer):
            expired.append(effect)
    for effect in expired:
        effect.on_remove(self)
        active_effects.erase(effect)
        global_effect_removed.emit(effect)
```

---

## 6. 五个事件设计

### 事件 1：龙卷供水

| 属性 | 值 |
|------|-----|
| event_id | `tornado_water_supply` |
| 类型 | 瞬时 |
| can_enter_hand | false |
| duration_type | INSTANT |

**效果**：场上所有天马（Pegasi）玩家移动到云宝家（固定地图位置），并立即摸 2 张牌。

**实现**：
```gdscript
func execute_instant(triggerer, event_manager, all_players):
    var cloudsdale_pos = Vector2i(...)  # 云宝家地图坐标
    for p in all_players:
        if p.species == Player.Species.Pegasi:
            # 移动（通过 MoveAction）
            p.move_to_position(cloudsdale_pos)
            # 摸 2 张牌（通过 DrawCard action，检查事件触发牌）
            var draw = p.get_node("ActionTree/DrawCard")
            draw.draw_num = 2
            draw.take_action()  # 同步执行，检查事件触发牌级联
```

**级联可能**：天马摸牌可能摸到事件触发牌 → 级联。

**待确认**：云宝家的地图坐标需要确定。

---

### 事件 2：布里兹迁徙

| 属性 | 值 |
|------|-----|
| event_id | `breezie_migration` |
| 类型 | 持续 |
| can_enter_hand | false |
| duration_type | UNTIL_NEXT_TRIGGER_TURN |

**效果**：到下个触发者回合开始时，所有玩家失去种族技能。

**实现**：
```gdscript
# 瞬时部分：注册 GlobalEffect
func execute_instant(triggerer, event_manager, all_players):
    var effect = BreezieMigrationEffect.new()
    effect.triggerer = triggerer
    effect.affected_players = all_players.duplicate()
    event_manager.register_effect(effect)

# GlobalEffect
func on_register(event_manager):
    # 禁用所有玩家的种族技能
    for p in affected_players:
        for skill in p.skills:
            if skill.category == SkillData.Category.Species:
                skill.set_disabled(true, p)

func on_remove(event_manager):
    # 恢复所有种族技能
    for p in affected_players:
        for skill in p.skills:
            if skill.category == SkillData.Category.Species:
                skill.set_disabled(false, p)

func check_expiry(current_player, triggerer):
    # 当触发者的回合再次开始时过期
    return current_player == triggerer
```

**注意**：使用 `set_disabled` 而非 `remove_skill`，技能仍在玩家身上但链条恢复默认。

---

### 事件 3：入戏太深

| 属性 | 值 |
|------|-----|
| event_id | `too_deep_in_character` |
| 类型 | 持续 |
| can_enter_hand | false |
| duration_type | UNTIL_END_OF_NEXT_OWN_TURN |

**效果**：从现在到触发者下个回合结束，触发者造成的心理伤害 +2。

> **确认**："你的心理伤害+2" = 触发者**造成**的心理伤害+2（攻击端修正），在 UseBaseplay 中检查。

**实现**：
```gdscript
# 瞬时部分：注册 GlobalEffect
func execute_instant(triggerer, event_manager, all_players):
    var effect = MentalDamageBoostEffect.new()
    effect.triggerer = triggerer
    effect.affected_players = [triggerer]
    event_manager.register_effect(effect)

# GlobalEffect
var boost_amount: int = 2
var _triggerer_had_turn: bool = false

func on_register(event_manager):
    pass  # 无即时效果，伤害修正通过 pull 模型在 UseBaseplay 中查询

func on_remove(event_manager):
    pass

func check_expiry(current_player, triggerer):
    if _triggerer_had_turn:
        return true  # 触发者的下个回合已过，效果过期
    if current_player == triggerer:
        _triggerer_had_turn = true  # 标记触发者的下个回合已开始
    return false

## 返回攻击端伤害修正（被 UseBaseplay 调用）
func get_outgoing_damage_modifier(player, damage_type) -> int:
    if player in affected_players and damage_type == Damage.DamageType.Mental:
        return boost_amount
    return 0
```

**UseBaseplay 修改**（攻击端检查）：
```gdscript
var result = card.resolve(player, target)
if result is Damage:
    if strength_bonus > 0:
        result.num += strength_bonus
    # ★ 全局效果：攻击端伤害修正（入戏太深）
    var event_mgr = player.get_meta("event_manager")
    if event_mgr:
        result.num += event_mgr.get_outgoing_damage_modifiers(player, result.type)
```

---

### 事件 4：魔法对决

| 属性 | 值 |
|------|-----|
| event_id | `magic_duel` |
| 类型 | 特殊（进手牌） |
| can_enter_hand | true |
| duration_type | INSTANT |

**效果**：事件牌进入触发者手牌。打出时（放入事件弃牌堆）选择攻击范围内的对手，如果手牌数大于对方，造成 3 点魔法伤害。

**实现**：

事件触发时，创建一个 `MagicDuelCard`（继承 CardData），加入触发者手牌：
```gdscript
func execute_instant(triggerer, event_manager, all_players):
    var card = MagicDuelCard.new()
    card.nice_name = "魔法对决"
    card.type = "Event"  # 特殊类型
    card.identity = "magic_duel"
    card.description = "选择攻击范围内的对手，如果手牌数大于他，造成3点魔法伤害"
    triggerer.add_card_to_hand(card)
```

打出时，UseCard 需要路由 Event 类型卡牌：
```gdscript
# UseCard.inform_next_action() 新增分支
if card is MagicDuelCard:
    child = get_node_or_null("UseEventCard")
```

`UseEventCard` action：
```gdscript
func take_action():
    # 检查攻击范围
    # 比较手牌数
    if player.get_hand_size() > target.get_hand_size():
        var damage = Damage.new()
        damage.type = Damage.DamageType.Magic
        damage.num = 3
        target_tree.receive_damage.damage = damage
        target_tree.chain_of_actions(target_tree.receive_damage)
    # 卡牌进入事件弃牌堆（不是普通弃牌堆）
    player.remove_card_from_hand(card)
    event_deck.discard_event(card)
```

---

### 事件 5：送冬迎春

| 属性 | 值 |
|------|-----|
| event_id | `winter_wrap_up` |
| 类型 | 瞬时 |
| can_enter_hand | false |
| duration_type | INSTANT |

**效果**：所有玩家弃掉手中的法术攻击牌。

**实现**：
```gdscript
func execute_instant(triggerer, event_manager, all_players):
    for p in all_players:
        var to_discard: Array[CardData] = []
        for card in p.hand:
            if card is BaseAttack:
                var attack = card as BaseAttack
                if attack.damage_type == Damage.DamageType.Magic:
                    to_discard.append(card)
        for card in to_discard:
            p.remove_card_from_hand(card)
            p.card_manager.receive_into_discard(card)
```

**待确认**：需要检查 BaseAttack 是否有 `damage_type` 字段标识物理/魔法/心理。

---

## 7. HUD 设计

### 7.1 事件牌堆 / 事件弃牌堆 Sprite

在 BottomHBox 中，现有 DrawPile 和 DiscardPile 旁边新增：
- `EventDeckSprite` (CardPileSprite) — 显示事件牌堆剩余数量
- `EventDiscardSprite` (CardPileSprite) — 显示事件弃牌堆数量

### 7.2 全局效果面板

在 TopBar 或 RightVBox 中新增 `GlobalEffectPanel`：
- 水平排列的效果图标列表
- 每个图标显示：事件名 + 持续类型 + 影响范围
- 点击显示详细描述
- EventManager 的 `global_effect_added` / `global_effect_removed` 信号驱动刷新

### 7.3 手牌中的事件牌

魔法对决进入手牌后，在 HandFan 中显示。需要：
- 特殊边框颜色（如紫色）区分事件牌
- 正常选牌 + 箭头交互流程
- 打出后进入事件弃牌堆而非普通弃牌堆

---

## 8. 数据格式

### 8.1 event_database.json

```json
[
  {
    "event_id": "tornado_water_supply",
    "nice_name": "龙卷供水",
    "description": "云宝组织所有的天马去给云中城供水，场上所有天马移动到云宝家，并立即摸两张牌。",
    "duration_type": "INSTANT",
    "can_enter_hand": false,
    "instant_effect_script": "res://source_codes/event_system/effects/tornado_water_supply.gd"
  },
  {
    "event_id": "breezie_migration",
    "nice_name": "布里兹迁徙",
    "description": "N年一度的布里兹迁徙开始了，到下个触发者回合，所有玩家失去种族技能。",
    "duration_type": "UNTIL_NEXT_TRIGGER_TURN",
    "can_enter_hand": false,
    "instant_effect_script": "res://source_codes/event_system/effects/breezie_migration.gd"
  },
  {
    "event_id": "too_deep_in_character",
    "nice_name": "入戏太深",
    "description": "下个回合前你受到的心理伤害+2，下个你的回合你的心理伤害+2。",
    "duration_type": "UNTIL_END_OF_NEXT_OWN_TURN",
    "can_enter_hand": false,
    "instant_effect_script": "res://source_codes/event_system/effects/too_deep_in_character.gd"
  },
  {
    "event_id": "magic_duel",
    "nice_name": "魔法对决",
    "description": "此牌收入手牌中，打出时选择攻击范围内的对手，如果手牌数大于他，对其造成3点魔法伤害。",
    "duration_type": "INSTANT",
    "can_enter_hand": true,
    "instant_effect_script": "res://source_codes/event_system/effects/magic_duel.gd"
  },
  {
    "event_id": "winter_wrap_up",
    "nice_name": "送冬迎春",
    "description": "所有玩家弃掉手中的法术攻击牌。",
    "duration_type": "INSTANT",
    "can_enter_hand": false,
    "instant_effect_script": "res://source_codes/event_system/effects/winter_wrap_up.gd"
  }
]
```

### 8.2 事件触发牌在 card_database.json 中

```json
{
  "identity": "EventTriggerCard",
  "nice_name": "事件触发牌",
  "type": "EventTrigger",
  "resource_script_path": "res://source_codes/event_system/event_trigger_card.gd",
  "description": "抽到时立即触发一个事件。事件结算后摸一张牌。"
}
```

### 8.3 normal_drawpile.json 中加入事件触发牌

在现有 16 张牌中加入若干张事件触发牌：
```json
[
  "物理攻击", "物理攻击", ..., "事件触发牌", "事件触发牌", ...
]
```

---

## 9. 文件清单

### 新建文件（15 个）

| 文件 | 职责 |
|------|------|
| `source_codes/event_system/event_card_data.gd` | 事件牌 Resource 基类 |
| `source_codes/event_system/event_deck.gd` | 事件牌堆管理 Node |
| `source_codes/event_system/event_manager.gd` | 事件协调 Node（触发/级联/效果管理） |
| `source_codes/event_system/global_effect.gd` | 持续效果 Resource 基类 |
| `source_codes/event_system/event_trigger_card.gd` | 事件触发牌（extends Baseplay） |
| `source_codes/event_system/trigger_source.gd` | 触发来源枚举（或内联） |
| `source_codes/event_system/effects/tornado_water_supply.gd` | 龙卷供水效果 |
| `source_codes/event_system/effects/breezie_migration.gd` | 布里兹迁徙效果 + GlobalEffect |
| `source_codes/event_system/effects/too_deep_in_character.gd` | 入戏太深效果 + GlobalEffect |
| `source_codes/event_system/effects/magic_duel.gd` | 魔法对决效果 + MagicDuelCard |
| `source_codes/event_system/effects/winter_wrap_up.gd` | 送冬迎春效果 |
| `source_codes/event_system/actions/UseEventCard.gd` | 打出事件手牌的 action |
| `source_codes/players/actions/EventTriggerPhase.gd` | 事件触发阶段 action（循环打出事件触发牌 + 事件后抽牌） |
| `source_codes/data/event_database.json` | 事件牌数据库 |
| `source_codes/hud/global_effect_panel.gd` | 全局效果面板 UI |
| `source_codes/hud/event_deck_sprite.gd` | 事件牌堆 sprite（或复用 CardPileSprite） |

### 修改文件（6 个）

| 文件 | 改动 |
|------|------|
| `source_codes/players/actions/ActionTree.gd` | 新增 event_trigger_phase 引用；默认链 TurnStart → DrawCard → EventTriggerPhase |
| `source_codes/players/actions/ReceiveDamage.gd` | 检查 EventManager 全局伤害修正（防御端，预留） |
| `source_codes/players/actions/TurnStart.gd` | 回合开始时检查效果过期 |
| `source_codes/players/actions/UseCard.gd` | 路由 Event 类型手牌到 UseEventCard |
| `source_codes/players/actions/UseBaseplay.gd` | 攻击端伤害修正（入戏太深） |
| `source_codes/hud/hud_battle.gd` | 初始化 EventManager/EventDeck，注入 player meta，事件信号处理 |
| `scenes/hud_battle.tscn` | 添加 EventManager/EventDeck 节点 |
| `scenes/player.tscn` | ActionTree 下新增 EventTriggerPhase 节点 |
| `source_codes/data/card_database.json` | 事件触发牌条目更新 |
| `source_codes/data/normal_drawpile.json` | 加入 3 张事件触发牌 |

---

## 10. 已确认参数

1. **云宝家坐标**：cube(2,0,-2)
2. **入戏太深**："你的心理伤害+2" = 触发者**造成**的心理伤害+2（攻击端修正，在 UseBaseplay 中检查，不是 ReceiveDamage）
3. **BaseAttack.damage_type**：已确认 BaseAttack 有 `damage_type: Damage.DamageType` 字段，送冬迎春用 `damage_type == Damage.DamageType.Magic` 判断法术攻击牌
4. **事件触发牌数量**：normal_drawpile.json 中放 3 张
5. **事件牌堆洗牌**：默认洗牌，抽空后自动洗弃牌堆（与普通抽牌堆相同）
6. **魔法对决**：打出时不消耗 attack_chance_in_turn
7. **事件触发牌**：触发随机事件（从事件牌堆抽），nice_name = "事件触发牌"

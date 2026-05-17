# 技能系统设计方案

## 一、数据模型

### SkillData（基类 Resource）

```
SkillData extends Resource
├── id: String                         # "earth_pony_strength"
├── nice_name: String                  # "蛮力"
├── category: enum {Species, Character, Equipment}
├── skill_type: enum {Active, Passive}
├── description: String
├── ignore_distance: bool              # 主动技能是否无视距离
├── range: int                         # 距离限制（-1 = 无限制）
├── cooldown: int                      # 冷却回合数（0 = 无冷却）
├── max_uses_per_turn: int             # 每回合使用次数（0 = 被动/无限制）
├── needs_target: bool                 # 主动技能是否需要选目标
│
│  ── 失效机制 ──
├── _disabled: bool                    # 失效状态（技能仍在玩家身上，但链条恢复默认）
├── disabled_changed 信号              # 通知 HUD 刷新半透明状态
├── is_disabled() -> bool
├── set_disabled(d: bool, player)      # 失效时调 on_detach，恢复时调 on_attach
│
│  ── 生命周期 ──
├── on_attach(player)                  # 子类重写：修改 ActionTree 链条
├── on_detach(player)                  # 子类重写：恢复默认链条。super 清理 _inserted_nodes
├── _inserted_nodes: Array[Node]       # 技能创建的 action 节点引用
│
│  ── 辅助 ──
├── _get_action_tree(player) -> ActionTree
└── _create_action_node(tree, script_path, name) -> Node  # 幂等创建
```

### Player.add_skill / remove_skill

**原则：链条修改逻辑写在技能自己的 .gd 里，Player 只负责调用。**

```gdscript
func add_skill(skill: SkillData) -> void:
    skills.append(skill)
    skill.on_attach(self)        # 技能自行修改 ActionTree 链条
    skill_added.emit(skill)

func remove_skill(skill: SkillData) -> void:
    skill.on_detach(self)        # 技能自行恢复链条
    skills.erase(skill)
    skill_removed.emit(skill)
```

---

## 二、Chain 暂停机制（核心重构）

当前 `chain_of_actions` 是同步 while 循环，一口气跑完。需要支持 action 暂停 chain 等待 HUD 交互。

### BaseAction 新增

```gdscript
var waiting: bool = false   # 设为 true 暂停 chain
```

### ActionTree 重构

```gdscript
signal chain_paused(action: BaseAction)

var _current_chain_action: BaseAction = null

func chain_of_actions(begin_action: BaseAction) -> void:
    _current_chain_action = begin_action
    _advance_chain()

func _advance_chain() -> void:
    while _current_chain_action != null:
        _current_chain_action.trigger()
        if _current_chain_action.waiting:
            chain_paused.emit(_current_chain_action)
            return
        _current_chain_action.inform_next_action()
        _current_chain_action.reset_property()
        _current_chain_action = _current_chain_action.next_action
    _current_chain_action = null

## HUD 交互完成后调用，恢复 chain
func resume_chain() -> void:
    if _current_chain_action == null:
        return
    _current_chain_action.waiting = false
    _current_chain_action.inform_next_action()
    _current_chain_action.reset_property()
    _current_chain_action = _current_chain_action.next_action
    _advance_chain()
```

### HudBattle 连接信号

```gdscript
func _setup_turn_system():
    # ...
    for p in players:
        var tree = p.get_node("ActionTree")
        tree.chain_paused.connect(_on_chain_paused)

func _on_chain_paused(action: BaseAction) -> void:
    # 根据 action 类型弹出对应 UI
    if action is ProspectEntry:
        _show_prospect_dialog(action)
    elif action is CalmRollExecute:
        _show_dice_choice_dialog(action)
```

---

## 三、RollDice 拆分

当前 `RollDice` 是单个节点。拆为两个节点，用 next_action 连接，设为默认链。

### RollDiceEntry.gd（入口）

```gdscript
class_name RollDiceEntry extends BaseAction

var purpose: String = ""        # 掷骰目的（"earth_pony_strength" 等）
var dice_result: int = 0        # 最终结果

func take_action():
    pass  # 入口，仅存储 purpose 和 dice_result

func inform_next_action():
    if next_action and next_action.get("purpose") != null:
        next_action.purpose = purpose
```

### RollDiceExecute.gd（实际投掷）

```gdscript
class_name RollDiceExecute extends BaseAction

var purpose: String = ""
var dice_result: int = 0

func take_action():
    dice_result = randi_range(1, 6)

func inform_next_action():
    # 把结果回传给 RollDiceEntry
    var tree = get_parent() as ActionTree
    var entry = tree.get_node_or_null("RollDiceEntry")
    if entry:
        entry.dice_result = dice_result
```

### ActionTree.make_default_chain 修改

```gdscript
func make_default_chain():
    receive_damage.next_action = decrease_health
    decrease_health.next_action = living_update
    turn_start.next_action = draw_card
    roll_dice_entry.next_action = roll_dice_execute   # NEW
```

---

## 四、三个技能的链条修改方式

### 默认链条（无技能时）

```
回合开始链: TurnStart → DrawCard → null

掷骰链: RollDiceEntry → RollDiceExecute → null
（按需触发，不是回合链的一部分）

伤害链: ReceiveDamage → DecreaseHealth → LivingUpdate → null
```

### 灰琪挂接三个技能后

```
回合开始链: TurnStart → 勘探Entry → DrawCard → 勘探Effect → null

掷骰链: RollDiceEntry → 冷静RollExecute → null

用牌链(攻击牌): UseCard → 蛮力RollEntry → 蛮力RollExecute → UseBaseplay → null
```

---

## 五、蛮力（开关技能，通过链条插入实现）

### earth_pony_strength.gd

```gdscript
class_name EarthPonyStrength extends SkillData

var enabled: bool = true   # 开关，默认开启

func on_attach(player: Player) -> void:
    var tree = _get_action_tree(player)
    var entry = _create_action_node(tree,
        "res://source_codes/skills/actions/strength_roll_entry.gd", "StrengthRollEntry")
    var execute = _create_action_node(tree,
        "res://source_codes/skills/actions/strength_roll_execute.gd", "StrengthRollExecute")
    entry.next_action = execute
    # 存到 UseCard 上供 inform_next_action 读取
    tree.use_card.set_meta("strength_entry", entry)
    tree.use_card.set_meta("strength_execute", execute)

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    tree.use_card.remove_meta("strength_entry")
    tree.use_card.remove_meta("strength_execute")
    super.on_detach(player)  # queue_free 插入的节点
```

### UseCard.inform_next_action 修改

```gdscript
func inform_next_action() -> void:
    # ... 确定 child (UseBaseplay 等) ...
    if child:
        child.player = player
        child.card = card
        child.target = target

        # 蛮力：攻击牌掷骰判定
        if card.type == "Attack" and has_meta("strength_entry"):
            var skill = _get_strength_skill(player)
            if skill and skill.enabled:
                var entry = get_meta("strength_entry")
                var execute = get_meta("strength_execute")
                execute.next_action = child   # 掷骰后继续 UseBaseplay
                next_action = entry
                return
        next_action = child

func _get_strength_skill(p: Player) -> SkillData:
    for s in p.skills:
        if s.id == "earth_pony_strength":
            return s
    return null
```

### StrengthRollEntry

```gdscript
class_name StrengthRollEntry extends BaseAction

var purpose: String = "earth_pony_strength"

func take_action():
    pass  # 入口节点，仅传递 purpose

func inform_next_action():
    if next_action and next_action.get("purpose") != null:
        next_action.purpose = purpose
```

### StrengthRollExecute

```gdscript
class_name StrengthRollExecute extends BaseAction

var purpose: String = ""
var dice_result: int = 0
var strength_bonus: int = 0

func take_action():
    dice_result = randi_range(1, 6)
    strength_bonus = 1 if dice_result >= 3 else 0

func inform_next_action():
    if next_action and next_action.get("strength_bonus") != null:
        next_action.strength_bonus = strength_bonus
```

### UseBaseplay 修改

```gdscript
var strength_bonus: int = 0   # 由 StrengthRollExecute 注入

func take_action() -> void:
    # ... card.execute / card.resolve ...
    if result is Damage:
        if strength_bonus > 0:
            (result as Damage).num += strength_bonus
        # 施加伤害 ...

func reset_property() -> void:
    card = null
    target = null
    strength_bonus = 0   # 重置
```

### 蛮力信息流

```
UseCard.inform_next_action
  → 检查攻击牌 + 蛮力开启
  → next_action = StrengthRollEntry
  → StrengthRollExecute.inform_next_action
    → UseBaseplay.strength_bonus = 1 或 0
  → UseBaseplay.take_action 使用 strength_bonus
```

---

## 六、勘探（链条插入 + HUD 暂停）

### 链条结构

```
默认:   TurnStart → DrawCard → null
勘探:   TurnStart → ProspectEntry → DrawCard → ProspectEffect → null
```

### maud_prospect.gd

```gdscript
func on_attach(player: Player) -> void:
    var tree = _get_action_tree(player)
    var entry = _create_action_node(tree,
        "res://source_codes/skills/actions/prospect_entry.gd", "ProspectEntry")
    var effect = _create_action_node(tree,
        "res://source_codes/skills/actions/prospect_effect.gd", "ProspectEffect")
    # 插入: TurnStart → ProspectEntry → DrawCard → ProspectEffect → null
    tree.turn_start.next_action = entry
    entry.next_action = tree.draw_card
    tree.draw_card.next_action = effect

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    # 恢复: TurnStart → DrawCard → null
    tree.turn_start.next_action = tree.draw_card
    tree.draw_card.next_action = null
    super.on_detach(player)
```

### ProspectEntry（勘探入口，TurnStart 和 DrawCard 之间）

```gdscript
class_name ProspectEntry extends BaseAction

var prospect_activated: bool = false

func take_action():
    # 暂停 chain，等 HUD 询问玩家
    waiting = true
    # ActionTree 发射 chain_paused(self)
    # → HudBattle 弹出 "是否使用勘探？"
    # → 玩家选 是/否 → 设 prospect_activated → tree.resume_chain()

func inform_next_action():
    # 如果激活，调整 DrawCard 抽牌数 -1
    if prospect_activated and next_action and next_action.get("draw_num") != null:
        next_action.draw_num = max(player.draw_stage_card_number - 1, 0)
```

### ProspectEffect（勘探效果，DrawCard 之后）

```gdscript
class_name ProspectEffect extends BaseAction

func take_action():
    var tree = get_parent() as ActionTree
    var entry = tree.get_node_or_null("ProspectEntry")
    if entry == null or not entry.prospect_activated:
        return

    var cm = player.card_manager
    var top_card = cm.peek_draw_pile()
    if top_card == null:
        return

    # 检查手牌是否有同 nice_name
    var has_match = false
    for cd in player.get_hand():
        if cd.nice_name == top_card.nice_name:
            has_match = true
            break

    if has_match:
        # 抽这张 + 下一张
        var cards = cm.take_from_draw_pile(2)
        for c in cards:
            if not player.is_hand_at_max_capacity():
                player.add_card_to_hand(c)
    else:
        player.armor = min(player.armor + 1, 4)
```

### HudBattle 对话框

```gdscript
func _on_chain_paused(action: BaseAction) -> void:
    if action is ProspectEntry:
        _show_prospect_dialog(action)

func _show_prospect_dialog(entry: ProspectEntry) -> void:
    var overlay = _create_dialog_overlay("勘探", "是否使用勘探？(少摸1张牌)")
    var btn_yes = overlay.get_node("VBox/BtnYes")
    var btn_no = overlay.get_node("VBox/BtnNo")
    var tree = entry.get_parent() as ActionTree
    btn_yes.pressed.connect(func():
        entry.prospect_activated = true
        overlay.queue_free()
        tree.resume_chain()
    )
    btn_no.pressed.connect(func():
        entry.prospect_activated = false
        overlay.queue_free()
        tree.resume_chain()
    )
```

### 勘探信息流

```
TurnStart → ProspectEntry (暂停, HUD 问是否使用)
  → resume → DrawCard (抽牌数 -1)
  → ProspectEffect (peek 堆顶, 判断, 抽牌或加护甲)
```

---

## 七、冷静（替换 RollDiceExecute + HUD 暂停）

### 链条结构

```
默认:   RollDiceEntry → RollDiceExecute (掷一次)
冷静:   RollDiceEntry → CalmRollExecute (掷两次，玩家选)
```

### maud_calm.gd

```gdscript
func on_attach(player: Player) -> void:
    var tree = _get_action_tree(player)
    var calm = _create_action_node(tree,
        "res://source_codes/skills/actions/calm_roll_execute.gd", "CalmRollExecute")
    # 替换: RollDiceEntry → CalmRollExecute (绕过默认 RollDiceExecute)
    tree.roll_dice_entry.next_action = calm

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    tree.roll_dice_entry.next_action = tree.roll_dice_execute
    super.on_detach(player)
```

### CalmRollExecute

```gdscript
class_name CalmRollExecute extends BaseAction

var roll1: int = 0
var roll2: int = 0
var chosen: int = 0

func take_action():
    var entry = _find_roll_entry()
    if entry == null:
        return
    # 陆马种族技能判定不生效
    if entry.purpose == "earth_pony_strength":
        entry.dice_result = randi_range(1, 6)
        return
    # 掷两次
    roll1 = randi_range(1, 6)
    roll2 = randi_range(1, 6)
    # 暂停 chain，等 HUD 让玩家选择
    waiting = true
    # → HudBattle 弹出 "选择: roll1 还是 roll2"
    # → 玩家选 → chosen = roll1 或 roll2 → tree.resume_chain()

func inform_next_action():
    var entry = _find_roll_entry()
    if entry and chosen > 0:
        entry.dice_result = chosen

func _find_roll_entry() -> BaseAction:
    var tree = get_parent() as ActionTree
    return tree.get_node_or_null("RollDiceEntry")
```

### 冷静信息流

```
RollDiceEntry → CalmRollExecute (掷两次, 暂停, HUD 让玩家选)
  → resume → RollDiceEntry.dice_result = chosen
```

---

## 八、初始化流程

### 新流程

```
_ready()
  → _setup_card_manager()        # 加载牌库 + 抽牌堆（不洗牌）
  → _setup_skill_manager()       # 加载技能库
  → _setup_players()             # 从 character_database.json 加载角色属性
  → _setup_skills()              # 初始化器：挂接种族/角色技能（技能 on_attach 修改链条）
  → _draw_initial_hands()        # 两个玩家从抽牌堆抽 start_game_draw 张
  → _create_tile_hud()
  → _deferred_start()
      → _setup_turn_system()     # 连接 chain_paused 信号
      → _start_game()            # TurnStart → (勘探Entry) → DrawCard → (勘探Effect)
```

### _setup_skills() 初始化器

```
对每个 player:
  1. species_skill_ids → 逐个 create_skill() → player.add_skill()
  2. character_skill_ids → 逐个 create_skill() → player.add_skill()

对卡牌库中每张装备牌:
  3. card 的 skill_ids → 创建 SkillData 实例存到 card 上
  （不挂接到 player，等装备时才挂接）
```

### _draw_initial_hands()

```
对每个 player:
  for i in range(player.start_game_draw):
    cards = card_mgr.take_from_draw_pile(1)
    if cards: player.add_card_to_hand(cards[0])
```

---

## 九、抽牌堆排列

CardManager 新增 `shuffle_draw_pile: bool = false`，默认不洗牌。`pop_back` 从尾部抽，JSON 数组末尾先抽。

### normal_drawpile.json

```json
[
  "物理攻击", "物理攻击", "物理攻击", "物理攻击",
  "物理攻击", "物理攻击",
  "宝石", "铠甲",
  "物理攻击", "物理攻击", "物理攻击", "物理攻击",
  "魔法攻击", "心理攻击", "偷牌", "物理攻击"
]
```

| 抽牌序 | 牌 | 归属 |
|--------|-----|------|
| 1-4 | 物理攻击, 偷牌, 心理攻击, 魔法攻击 | 灰琪初始手牌 |
| 5-8 | 4× 物理攻击 | 日光耀耀初始手牌 |
| 9-10 | 铠甲, 宝石 | 灰琪第一回合抽牌 |
| 11-16 | 6× 物理攻击 | 后续 |

---

## 十、装备技能挂接

### card_database.json 扩展

```json
{
  "nice_name": "花束",
  "type": "Weapon",
  "skill_ids": ["bouquet_charm"]
}
```

### BaseEquipment.on_equip / on_unequip

```gdscript
func on_equip(player: Player, _slot: int) -> void:
    for sid in skill_ids:
        var skill = SkillManager.create_skill(sid)
        if skill:
            player.add_skill(skill)

func on_unequip(player: Player, _slot: int) -> void:
    for sid in skill_ids:
        for s in player.skills:
            if s.id == sid:
                player.remove_skill(s)
                break
```

子类（Armor、Weapon）的 `on_equip` 调 `super` 继承技能挂接，再做自己的属性加成。

---

## 十一、技能 HUD

### 布局

EquipmentBar 的 EquipHBox 内，装备栏在左，技能栏在右，中间用 VSeparator 分隔：

```
EquipHBox (centered)
├── [武器] [防具] [元素]          ← 左侧装备栏
├── ← spacer expand →
├── ★收藏品 [槽0] [槽1] [槽2]    ← 收藏品
├── │                            ← VSeparator
└── (○)(○)(○)                   ← SkillTray (动态 SkillSlot)
```

### SkillSlot (`skill_slot.gd`)

- 56×56 圆形，`_draw()` 渲染
- **主动技能**：实线描边 + 内圈微光
- **被动技能**：虚线描边（12 段 dash）
- **失效状态**：alpha 降到 0.35
- **类别颜色**：种族=绿、角色=金、装备=紫
- 悬停发射 `skill_hovered` → HudBattle `_show_skill_detail()` 显示描述
- 监听 `disabled_changed` 自动重绘
- 暂无图标，显示技能名称文字

---

## 十二、文件清单

### 新建

| 文件 | 职责 |
|------|------|
| `skills/skill_data.gd` | 技能基类，含 disabled 机制 ✅ 已创建 |
| `skills/skill_manager.gd` | 技能库加载/查询/创建 |
| `data/skill_database.json` | 技能定义 |
| `data/character_database.json` | 角色定义（无 armor、无 start_hand） |
| `skills/species/earth_pony_strength.gd` | 蛮力：修改 UseCard 链条 |
| `skills/character/maud_prospect.gd` | 勘探：修改 TurnStart→DrawCard 链条 |
| `skills/character/maud_calm.gd` | 冷静：修改 RollDice 链条 |
| `skills/actions/prospect_entry.gd` | 勘探入口节点 |
| `skills/actions/prospect_effect.gd` | 勘探效果节点 |
| `skills/actions/calm_roll_execute.gd` | 冷静掷骰节点 |
| `skills/actions/strength_roll_entry.gd` | 蛮力掷骰入口 |
| `skills/actions/strength_roll_execute.gd` | 蛮力掷骰执行 |
| `hud/skill_slot.gd` | 圆形技能槽 UI ✅ 已创建 |

### 修改

| 文件 | 改动 | 状态 |
|------|------|------|
| `player.gd` | +skills 数组, +add/remove_skill, armor clamp 0-4 | ✅ 已完成 |
| `BaseAction.gd` | +waiting 属性 | 待实现 |
| `ActionTree.gd` | chain 暂停机制 + RollDice 拆分 + make_default_chain | 待实现 |
| `RollDice.gd` | 拆成 RollDiceEntry.gd + RollDiceExecute.gd | 待实现 |
| `card_data.gd` | +skill_ids 字段 | 待实现 |
| `card_manager.gd` | +shuffle_draw_pile, +peek_draw_pile, _create_card_data 加载 skill_ids | 待实现 |
| `base_equipment.gd` | on_equip/on_unequip 挂接/卸下技能 | 待实现 |
| `hud_battle.gd` | 从 JSON 加载角色, 初始化器, 抽初始手牌, chain_paused 信号, 技能 UI | 部分完成 |
| `hud_battle.tscn` | +SkillSeparator + SkillTray | ✅ 已完成 |
| `equipment_bar.gd` | +技能栏管理 | ✅ 已完成 |
| `UseCard.gd` | inform_next_action 检查蛮力标记 | 待实现 |
| `UseBaseplay.gd` | +strength_bonus, take_action 读取蛮力掷骰结果 | 待实现 |
| `normal_drawpile.json` | 重新排列 | 待实现 |

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A My Little Pony fan-made turn-based tactical card battler on a hexagonal grid, built with **Godot 4.7** (GDScript). Interactive battle prototype — two characters (灰琪 Maud Pie vs 日光耀耀 Sun Burst) in `hud_battle.tscn` with full HUD, card play, hex movement, turn management, equipment system, skill system, and event system.

**Addons** (under `addons/`): hexagon_tilemaplayer v2.5.2 | dialogue_manager v3.10.1 | vfx_library v1.0.0

## Running the Game

Godot binary is at `../Godot_v4.6.3-stable_win64.exe` (relative to project root). All commands run from the project root.

```bash
# Interactive HUD battle — this is the active development scene
../Godot_v4.6.3-stable_win64.exe --path .

# Headless unit test suite
../Godot_v4.6.3-stable_win64.exe --headless --path . test/test_runner.tscn
```

The headless test output can be redirected: `... --headless ... test/test_runner.tscn > test/test.txt`

---

## Architecture Requirements (架构硬性要求)

> **本节所有条目均为硬性约束（HARD CONSTRAINTS），不可违反、不可变通、不可"为了方便"绕过。**
> 任何代码变更如果与以下条目冲突，必须先修改方案使其符合架构要求，再写代码。
> Code review 时必须逐条检查，发现违规必须拒绝合并并修正。

### 1. 三层分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                        HudBattle (UI + 协调)                  │
│  - 场景化管理 UI（tscn 静态布局 + 代码动态元素）                 │
│  - 处理输入（键盘/鼠标）                                       │
│  - 通过信号启动 ActionTree 对应动作节点                         │
│  - 坐标系转换（CanvasLayer ↔ tile ↔ cube）                    │
│  - 战斗日志 / 卡牌详情 / 技能详情 / 面板显示                    │
└──────┬──────────────────────┬────────────────────────────────┘
       │ 信号驱动              │ 信号驱动
       ▼                      ▼
┌──────────────┐     ┌─────────────────────────────────┐
│  TurnManager │     │          ActionTree              │
│              │     │                                 │
│ - 回合/轮次   │     │  链式自动流转：                   │
│   总调度      │     │  trigger() → inform_next() →    │
│ - 接收回合结  │     │  reset() → next_action          │
│   束信号      │     │                                 │
│ - 向下一个玩  │     │  默认链：                        │
│   家发回合开  │     │  TurnStart → DrawCard            │
│   始信号      │     │      → EventTriggerPhase         │
│              │     │  ReceiveDamage → DecreaseHealth  │
│              │     │      → LivingUpdate              │
│              │     │  RollDiceEntry → RollDiceExecute │
│              │     │  MoveAction（单独触发）            │
│              │     │  UseCard（单独触发，通过箭头交互） │
└──────┬───────┘     └──────────────┬──────────────────┘
       │ turn_started               │ 读写 Player 数据
       ▼                             ▼
┌─────────────────────────────────────────────────────────────┐
│                     Player (纯数据类)                          │
│                                                             │
│  数据：@export 属性 + equipment + hand + skills + card_manager │
│  查询：get_hand() / get_skills() / has_equipment 等           │
│  手牌管理：hand 数组 + add_card_to_hand / remove_card_from_hand │
│  技能管理：skills 数组 + add_skill / remove_skill              │
│  信号：hand/equipment/skill 变更信号                          │
│                                                             │
│  ✗ 不含任何回合/轮次逻辑（turn_count 等由 ActionTree 修改）     │
│  ✗ 不含 draw_cards / discard_card / apply_damage              │
└─────────────────────────────────────────────────────────────┘
```

### 2. 各层职责硬性约束

以下为各层的 MUST / MUST NOT 约束。违反任意一条即为架构违规。

#### Player 层

- **MUST** 作为纯数据类，仅存储 `@export` 属性、`equipment`、`hand`、`skills`、`card_manager` 引用。
- **MUST** 提供容器管理方法：`add_card_to_hand()` / `remove_card_from_hand()` / `add_skill()` / `remove_skill()`。这些方法只维护容器本身，不触发游戏逻辑。
- **MUST** 通过信号通知变更：`card_added_to_hand` / `card_removed_from_hand` / `hand_updated` / `equipment_changed` / `skill_added` / `skill_removed`。
- **MUST NOT** 包含抽牌逻辑（`draw_cards`）。
- **MUST NOT** 包含弃牌逻辑（`discard_card`）。
- **MUST NOT** 包含伤害计算或扣血逻辑（`apply_damage`）。
- **MUST NOT** 包含移动逻辑。
- **MUST NOT** 包含回合计数逻辑（`turn_count` / `round_count` 的递增）。
- **MUST NOT** 直接修改自身的战斗状态字段（`health`、`armor`、`move_chance_in_turn`、`attack_chance_in_turn`、`turn_count`、`round_count`、`living_state`）。这些字段的写入只能由 ActionTree 动作完成。

> **例外**：`armor` 的 setter 做 clamp(0,4) 是数据完整性保护，不算游戏逻辑。`add_skill()` 调用 `skill.on_attach(self)` 是容器管理的委托，不算游戏逻辑。

#### ActionTree 层

- **MUST** 承担所有玩家运行时状态变更：扣血、抽牌、弃牌、移动、回合计数、装备装/卸。
- **MUST** 通过链式流转执行：`trigger()` → `inform_next_action()` → `reset_property()` → `next_action`。
- **MUST** 支持链暂停机制：`BaseAction.waiting` + `ActionTree.chain_paused` 信号 + `ActionTree.resume_chain()`。
- **MUST NOT** 处理 UI 输入（键盘/鼠标事件）。
- **MUST NOT** 管理回合调度（哪个玩家何时行动由 TurnManager 决定）。
- **MUST NOT** 做坐标系转换（CanvasLayer ↔ tile ↔ cube）。

#### TurnManager 层

- **MUST** 维护存活玩家有序链表，按 player-relative 轮次调度。
- **MUST** 通过 `turn_started` / `turn_ended` 信号驱动回合流转。
- **MUST NOT** 直接修改 Player 的任何数据字段。
- **MUST NOT** 直接调用 ActionTree 的动作节点。

#### HudBattle 层

- **MUST** 管理所有 UI 节点（tscn 静态布局 + 代码动态创建）。
- **MUST** 处理所有用户输入（键盘/鼠标），将输入翻译为 ActionTree 动作参数。
- **MUST** 负责坐标系转换（CanvasLayer ↔ tile ↔ cube）。
- **MUST** 通过 `chain_of_actions()` 启动动作链，通过连接信号监听结果。
- **MUST NOT** 直接修改 Player 的战斗状态字段（`health`、`armor`、`move_chance_in_turn`、`attack_chance_in_turn`、`turn_count`、`round_count`、`living_state`）。
- **MUST NOT** 绕过 ActionTree 直接调用 Player 的状态变更方法。

> **例外**：`_setup_players()` 中的初始化赋值（从 JSON 设置角色属性、初始手牌、挂接技能）不走 ActionTree，这是初始化阶段，不是运行时状态变更。

#### CardManager（独立组件）

- **MUST** 独立于三层架构，仅管理抽牌堆和弃牌堆。
- **MUST** 通过 `player.card_manager` 引用被 ActionTree 动作访问。
- **MUST NOT** 管理手牌（手牌由 Player 自身的 `hand` 数组管理）。
- **MUST NOT** 触发 UI 更新或回合逻辑。

### 3. 信号流（硬性路径）

所有用户操作必须通过以下路径，不得跳过任何环节：

```
用户操作 → HudBattle 处理输入
  ├── 选牌 + 点击目标 → 设置 UseCard 参数 → chain_of_actions(use_card)
  ├── 移动模式点击格子 → 设置 MoveAction 参数 → chain_of_actions(move_action)
  ├── 点击抽牌堆 → 设置 DrawCard 参数 → chain_of_actions(draw_card)
  └── 结束回合按钮 → turn_mgr.end_current_turn()
                         │
                         ▼
                    TurnManager.turn_started 信号
                         │
                         ▼
                    chain_of_actions(turn_start)
                         │
                    TurnStart → DrawCard → EventTriggerPhase (链式自动流转)
                         │
                    TurnStart: 回合初始化 + 全局效果过期检查
                    DrawCard: 抽牌（抽到事件触发牌直接打出）
                    EventTriggerPhase: 打出初始手牌中的事件触发牌
```

```
用牌流程：
  用户选牌 → 箭头激活 → 点击目标角色
    → HudBattle 设置 use_card.card + use_card.target
    → chain_of_actions(use_card)
      → UseCard（调度器，仅路由）
        → card is BaseEquipment  → UseEquipment（收藏品占用检查 + 装备 + 旧牌处理 + 技能挂接）
        → card is BaseEffect     → UseEffect（Gem/Recovery，execute → 手牌移除 → 去向）
        → else                   → UseBaseplay（Attack/Steal，execute → resolve fallback → 去向）
        → (攻击牌) → 触发目标 ActionTree 的 ReceiveDamage → DecreaseHealth → LivingUpdate 链
```

### 4. 初始化规则

- 初始化（设置属性值、初始手牌、挂接技能）**不走 ActionTree**，由 HudBattle 在 `_setup_players()` 和 `_setup_skills()` 中直接完成。
- ActionTree 只处理运行时状态变更。
- 初始化完成后，所有后续状态变更必须走 ActionTree。

---

## Architecture Rules (编码硬性规约)

> 以下 12 条规则为不可违反的硬性约束。每条规则标注违反检查点，用于 code review。

### R1. HudBattle 禁止修改 Player 战斗状态

**规则**：HudBattle 不得直接修改 Player 的以下字段：`health`、`armor`、`move_chance_in_turn`、`attack_chance_in_turn`、`turn_count`、`round_count`、`living_state`。

**允许**：只读查询（`player.health`）、初始化赋值（`_setup_players()` 中从 JSON 设置 `max_health` 等）。

**检查点**：在 `hud_battle.gd` 中搜索 `player.health =`、`player.armor =`、`player.move_chance`、`player.attack_chance`、`player.turn_count`、`player.round_count`、`player.living_state`，除了 `_setup_players()` 中的初始化赋值，不应出现任何写入。

### R2. 所有运行时状态变更必须通过 ActionTree

**规则**：如果需要修改 Player 的战斗状态，必须通过 ActionTree 动作节点完成。如果现有动作不满足需求，**创建新动作节点**，而不是在 HudBattle 中直接操作。

**检查点**：HudBattle 中不应出现对 Player 战斗状态的直接赋值（初始化除外）。新功能如果需要修改状态，必须有对应的 Action 节点。

### R3. TurnManager 禁止写 Player 数据

**规则**：TurnManager 只负责回合/轮次调度，只发信号，不写 Player 任何数据。

**检查点**：`turn_manager.gd` 中不应出现对 Player 属性的赋值操作。

### R4. Player 保留手牌容器管理

**规则**：Player 保留 `add_card_to_hand()` / `remove_card_from_hand()` / `hand` 数组。这是数据类自身的容器维护，不算游戏逻辑。ActionTree 的 DrawCard 动作通过 `player.add_card_to_hand()` 添加卡牌。

**检查点**：DrawCard 动作应调用 `player.add_card_to_hand()`，而不是直接操作 `player.hand` 数组。

### R5. 卡牌类型必须准确

**规则**：新卡牌的 `type` 必须准确使用：Attack / Steal / Event / Effect / Recovery / Weapon / Armor / Element。不得复用 Attack 类型给非攻击牌。

**检查点**：新增卡牌时检查 `card_database.json` 中的 `type` 字段与卡牌实际功能是否匹配。

### R6. 坐标系转换属于 HudBattle

**规则**：坐标系转换（CanvasLayer ↔ tile ↔ cube）只在 HudBattle 中做。MoveAction 只设 `map_position`，`cube_position` 同步由 HudBattle 在动作链完成后处理。

**检查点**：ActionTree 动作节点中不应出现 `map_to_cube()` / `cube_to_map()` / `local_to_map()` / `map_to_local()` 调用。

### R7. 技能通过修改 ActionTree 链条实现效果

**规则**：技能不使用回调钩子。技能的 `on_attach(player)` / `on_detach(player)` 在技能自己的 .gd 文件里，负责修改/恢复 ActionTree 链条。Player 只管调用 `add_skill()` / `remove_skill()`。

**禁止模式**：
```gdscript
# ✗ 违规：回调钩子
signal on_damage_taken
func on_attach(player):
    player.damage_taken.connect(_on_damage)
```

**正确模式**：
```gdscript
# ✓ 合规：修改链条
func on_attach(player):
    var tree = player.get_node("ActionTree")
    var use_card = tree.get_node("UseCard")
    use_card.inform_next_action = _my_roll_entry  # 插入节点
```

**检查点**：技能 .gd 文件中不应出现 `connect()` 连接 Player 或 ActionTree 的信号来触发技能效果（`disabled_changed` 信号用于 HUD 更新，不算违规）。

### R8. armor 是可消耗吸收层

**规则**：`armor` 是可消耗吸收层，最大 4 点（clamp 0-4），默认 0。受伤时先扣 armor，扣完才扣血。与 `defence`（固定减伤）是两套独立机制。

**检查点**：`DecreaseHealth` 动作中，伤害应先扣除 `player.armor`，armor 归零后才扣 `player.health`。`player.armor` 的 setter 应 clamp 到 0-4。

### R9. 收藏品不进弃牌堆

**规则**：收藏品（`is_collection_item(identity)` 为 true 的卡牌）永远不进入弃牌堆。装备卸下时如果是收藏品，移到 Collection 槽位而非弃牌堆。

**检查点**：`UnequipAction` 中，收藏品应触发 `unequip_blocked` 信号而非进入弃牌堆。`MoveEquipmentToCollection` / `EquipFromCollection` 按 `card_identity` 查找指定收藏品。

### R10. 装备技能挂接走 on_equip / on_unequip

**规则**：装备牌的 `skill_ids` 字段在 `on_equip` 时挂接（调 `player.add_skill()`），`on_unequip` 时卸下（调 `player.remove_skill()`）。子类的 `on_equip` 必须调 `super` 继承技能挂接，再做自己的属性加成。

**检查点**：`BaseEquipment.on_equip()` 遍历 `skill_ids` 调 `add_skill`。子类（如 `Armor.gd`）的 `on_equip` 第一行必须是 `super.on_equip(player)`。

### R11. 抽牌堆默认不洗牌

**规则**：`CardManager.shuffle_draw_pile` 默认 `false`，按 JSON 文件中的顺序抽牌。需要洗牌时显式设为 `true`。

**检查点**：`card_manager.gd` 中 `shuffle_draw_pile` 默认值必须为 `false`。`normal_drawpile.json` 中的卡牌顺序即为抽牌顺序。

### R12. 初始化不走 ActionTree

**规则**：初始化阶段（`_setup_players()` 设置角色属性、`_draw_initial_hands()` 抽初始手牌、`_setup_skills()` 挂接技能）不走 ActionTree。初始化完成后，所有后续状态变更必须走 ActionTree。

**检查点**：`_setup_players()` / `_draw_initial_hands()` / `_setup_skills()` 中不应出现 `chain_of_actions()` 调用。`_start_game()` 之后的任何状态变更必须通过 ActionTree。

---

## Addons

| 插件 | 版本 | 用途 |
|------|------|------|
| **hexagon_tilemaplayer** | v2.5.2 | 六边形网格、cube 坐标、A* 寻路 |
| **dialogue_manager** | v3.10.1 | 对话系统 |
| **vfx_library** | v1.0.0 | 粒子效果（35+ 粒子 + 17+ Shader） |

**hexagon_tilemaplayer UID 修复**：addon 原有的 `preload("uid://chl4qyjdth4vj")` 硬编码 UID 在清空 `.godot/` 缓存后会失效。已改为相对路径引用（`preload("hexagon_tilemaplayer.svg")`），修了 `plugin.gd`、`toolbar.gd`、`hexagon_tilemaplayer.gd` 三处。`demo/` 文件夹已禁用（移到 `_demo_disabled/`），zip 包已删除。

---

## Core Systems (under `source_codes/`)

### Card System (`card_system/`)

Data-driven from JSON files split into subdirectories under `source_codes/data/`. `CardManager` manages only the **draw pile** and **discard pile**, plus card creation from database and queries. Uses `_normal_paths` and `_bonus_paths` arrays to load from multiple subdirectories.

**Data directory structure**:
```
source_codes/data/
├── character/          # 角色数据库（按种族拆分）
│   ├── earthpony/earthpony_database.json + earthpony_skill_database.json
│   ├── pegasus/pegasus_database.json + pegasus_skill_database.json
│   ├── unicorn/unicorn_database.json + unicorn_skill_database.json
│   ├── alicorn/alicorn_database.json + alicorn_skill_database.json
│   └── species_skill_database.json
├── normalcard/         # 普通卡牌（按类型拆分）
│   ├── weapon_database.json, armor_database.json, element_database.json
│   ├── baseplay_database.json, effect_database.json, recovery_database.json
├── bonuscard/          # 奖励卡牌
│   ├── bonus_weapon_database.json, bonus_armor_database.json
│   ├── bonus_effect_database.json, bonus_recovery_database.json
├── event/              # event_database.json
└── cardpile/hudbattle_pile/  # 牌堆配置
    ├── drawpile_database.json
    ├── bonus_database.json
    └── event_pile_database.json
```
- Card creation via `CardManager.create_card(nice_name)` loads the script from `resource_script_path` and copies all JSON fields onto the new resource.
- Card type hierarchy: `CardData` (Resource) → `Baseplay` / `BaseEquipment` → `BaseWeapon`, `BaseArmor`, `BaseElement` / `BaseEffect` → `BaseRecovery`, `Gem` | `Baseplay` → `BaseAttack` (物理/魔法/心理攻击的参数化基类) / `StealCard` / `EventTriggerCard` (事件触发牌)
- Cards use two execution paths: `execute(source, target, card_manager) -> bool` and `resolve(source, target) -> Variant`.
- **CardData** has `skill_ids: Array[String]` field — 装备牌从 JSON 加载，装备时通过 `on_equip` 挂接对应技能。
- **Equipment cards**: `execute()` equips to slot, sets `replaced_old_card`. `on_equip` / `on_unequip` hooks — 子类调 `super` 继承技能挂接，再做自己的属性加成。
- **Armor card** (铠甲): `on_equip` adds +1 `physical_defence` and +1 `magic_defence`; `on_unequip` removes them. **NOT** the `armor` consumable buffer.
- **Collection items**: Each player has `collection_item_ids: Array[String]`. Collection items NEVER go to discard pile. `is_collection_item(identity)` checks against this list.
- `CardManager.peek_draw_pile()` — 翻看抽牌堆顶牌（不抽出），供勘探技能使用。
- `CardManager._create_card_data()` — 加载 JSON 时把 `skill_ids` 字段复制到 CardData。

### Player System (`players/`)

`Player` extends `Sprite2D`. **Pure data class**.

- Data: `@export` stats, `equipment: Dictionary` (maps `EquipmentSlotType` → `Array[CardData]`), `hand: Array[CardData]`, `skills: Array[SkillData]`, `card_manager` reference.
- `armor: int = 0` — 可消耗吸收层，setter clamp 到 0-4。角色初始化默认 0，character_database.json 不含此字段。
- Hand management: `add_card_to_hand()`, `remove_card_from_hand()`, signals `card_added_to_hand`, `card_removed_from_hand`, `hand_updated`.
- Equipment methods: `_add_to_slot()`, `_remove_from_slot()`, `move_to_collection_slot()`, `move_from_collection_to_slot()`, `is_slot_occupied_by_collection()`, `is_collection_item()`, `get_equipment_in_slot()`, `has_equipment_in_slot()`.
- Equipment signals: `equipment_changed(slot: EquipmentSlotType)`.
- **Skill management**: `skills: Array[SkillData]`, `add_skill(skill)` (调 `skill.on_attach(self)`), `remove_skill(skill)` (调 `skill.on_detach(self)`), `get_skills()`, `has_skill(id)`. Signals: `skill_added`, `skill_removed`.
- **Collection tracking**: `collection_completed: bool` (集齐 3 个收藏品时置 true), `_owned_collectible_ids: Array[String]` (去重), signal `collection_completed()`.
- **Does NOT contain**: draw/discard/apply_damage/move_chance logic (→ migrated to ActionTree actions).

### ActionTree (`players/actions/`)

Each Player scene has an `ActionTree` node. `chain_of_actions(begin)` walks: `trigger()` → `inform_next_action()` → `reset_property()` → `next_action`.

**Chain 暂停机制**（用于 HUD 交互）:
- `BaseAction.waiting: bool` — 设为 true 暂停 chain
- `ActionTree.chain_paused` 信号 — 暂停时发射，HudBattle 监听
- `ActionTree.resume_chain()` — HUD 交互完成后调用，恢复 chain

Default chains:
- `TurnStart → DrawCard → EventTriggerPhase` — triggered by TurnManager on turn start
- `ReceiveDamage → DecreaseHealth → LivingUpdate` — damage processing chain
- `HealEntry → HealExecute` — 恢复链（默认到此结束，技能可动态插入后续节点）
- `RollDiceEntry → RollDiceExecute` — 掷骰链（按需触发）

**ActionTree 信号**:
- `chain_paused(action)` — action 设 waiting=true 暂停时发射
- `action_executed(message)` — 每个 action trigger 后调 _get_action_info()，非空则发射（HudBattle 连接一次即可，替代旧的逐节点连接）

Active actions:

| 动作 | 触发方式 | 说明 |
|------|---------|------|
| `UseCard` | HudBattle 选牌+点击目标 | **调度器**：`inform_next_action()` 按 `is BaseEquipment`/`is BaseEffect`/`type=="Event"` 分发到子节点 |
| `UseEquipment` | UseCard 分发 | 收藏品占用检查 → `execute()` 装备 + 技能挂接 → 旧牌处理 |
| `UseEffect` | UseCard 分发 | `execute()` → 手牌移除 → 去向 |
| `UseBaseplay` | UseCard 分发 | `execute()` → `resolve()` fallback（Attack → Damage 链，含蛮力/事件伤害修正）→ 手牌移除 → 去向 → 攻击次数递减 |
| `UseEventCard` | UseCard 分发 (type=="Event") | 打出事件手牌（魔法对决）。不消耗 attack_chance。用完进事件弃牌堆 |
| `MoveAction` | HudBattle 移动模式 | 设 `map_position`，递减 `move_chance_in_turn`。**钩入地形系统**：通知 TerrainManager.on_player_moved |
| `DrawCard` | HudBattle 点击抽牌堆 / TurnStart 链 | 抽牌到手牌。**抽到事件触发牌直接打出**（进弃牌堆 → 触发事件 → 事件后抽牌，递归级联） |
| `EventTriggerPhase` | TurnStart 链（DrawCard 之后） | 循环检查手牌中的事件触发牌（来自初始手牌），依次打出。事件后抽牌调 `DrawCard._draw_one_card()` |
| `DiscardCard` | — | 从手牌弃入弃牌堆 |
| `RollDiceEntry` | 按需触发 | 掷骰入口，存储 `purpose` 和 `dice_result` |
| `RollDiceExecute` | RollDiceEntry 链 | 实际掷骰，结果回传给 RollDiceEntry |
| `UnequipAction` | 装备栏拖拽到 DiscardZone | 主动卸下非收藏品装备 → 弃牌堆（收藏品拒绝 → `unequip_blocked` 信号） |
| `MoveEquipmentToCollection` | 装备栏拖拽 | 收藏品从装备栏移到 Collection 槽位。按 `card_identity` 查找指定收藏品 |
| `EquipFromCollection` | 收藏品拖拽 | Weapon/Armor 收藏品从 Collection 移回装备栏。按 `card_identity` 查找 + 类型安全检查 |
| `HealEntry` | 恢复链入口 | 接收 `heal_amount`，通过 `inform_next_action` 传递给 HealExecute |
| `HealExecute` | 恢复链生效 | 修改 player.health（不超 max_health），记录实际恢复量传给下游 |
| `CrystalMarkTrigger` | 水晶洗礼动态插入 | 恢复链最后一环：检查 meta `crystal_marks`，有则移除后造成等量真实伤害链 |
| `CrystalShineExecute` | 水晶洗礼主动使用 | 弃置一张手牌 + 调用 skill.add_mark(target)。由 HudBattle 在点技能→选目标后触发 |

`UseCard` 的四个子节点（UseEquipment / UseEffect / UseBaseplay / UseEventCard）由 `UseCard._ready()` 动态创建。其他动作节点若场景中不存在，由 `EquipmentBar._send_action()` / `EquipmentBar._get_or_create_action()` 动态加载脚本创建。

### Skill System (`skills/`)

技能分三种来源：种族技能（Species）、角色技能（Character）、装备技能（Equipment）。分两种类型：主动（Active）、被动（Passive）。

**SkillData** (`skills/skill_data.gd`) — 基类 Resource:
- `id`, `nice_name`, `category`, `skill_type`, `description`
- `ignore_distance: bool`, `range: int` (-1=无限制), `cooldown: int`, `max_uses_per_turn: int`, `needs_target: bool`
- **disabled 机制**: `is_disabled()` / `set_disabled(d, player)` — 失效时调 `on_detach` 恢复链条，恢复时调 `on_attach` 重新修改链条。`disabled_changed` 信号通知 HUD。
- `on_attach(player)` / `on_detach(player)` — 子类重写，修改/恢复 ActionTree 链条。`on_detach` 的 `super` 调用清理 `_inserted_nodes`。
- `_create_action_node(tree, script_path, name)` — 幂等创建 action 节点（同名已存在则返回已有的）。

**技能与 ActionTree 链条的交互方式**:
- 技能不使用回调钩子，而是直接修改 ActionTree 的 action 链条
- `on_attach` 时插入 action 节点到链条中，`on_detach` 时恢复默认链条
- 需要玩家交互的 action 节点设 `waiting = true` 暂停 chain，HudBattle 通过 `chain_paused` 信号响应

**六个已实现的技能**:

| 技能 | 类型 | 来源 | 链条修改方式 |
|------|------|------|-------------|
| 蛮力 | 被动（开关） | EarthPony 种族 | 在 UseCard→UseBaseplay 之间插入 StrengthRollEntry→StrengthRollExecute。默认开启，关闭后跳过掷骰 |
| 魔法触及 | 被动 | Unicorn 种族 | on_attach 设 meta "attack_range_bonus"=1（攻击距离+1），on_detach 移除 |
| 自由翱翔 | 被动（开关） | Pegasus 种族 | on_attach 设 meta "terrain_immune"=true。点击技能槽切换地形免疫开关 |
| 勘探 | 主动 | 灰琪角色 | 在 TurnStart→DrawCard 之间插入 ProspectEntry（暂停等 HUD 问是否使用），DrawCard 之后插入 ProspectEffect |
| 冷静 | 被动 | 灰琪角色 | 替换 RollDiceExecute 为 CalmRollExecute（掷两次，暂停等 HUD 让玩家选，陆马种族判定不生效） |
| 水晶洗礼 | 主动 | 日光耀耀角色 | 弃手牌对目标 add_mark。首次标记时在目标 ActionTree 上动态插入 CrystalMarkTrigger 到 HealExecute 之后。技能失效/on_detach 时恢复链条+清除所有印记 |

**SkillManager** (`skills/skill_manager.gd`) — 节点，放在 `logic` 下:
- 加载 `skill_database.json`
- `get_skill(id)` 返回模板实例
- `create_skill(id)` 返回新实例（挂接到 player 用）

**装备技能挂接**:
- `card_database.json` 中装备牌加 `skill_ids` 字段
- `CardData` 有 `skill_ids: Array[String]`
- `BaseEquipment.on_equip` / `on_unequip` 遍历 `skill_ids`，调 `player.add_skill()` / `player.remove_skill()`
- 子类的 `on_equip` 调 `super` 继承技能挂接

**技能库 JSON** (`data/skill_database.json`):
```json
[{"id": "...", "nice_name": "...", "category": "Species|Character|Equipment",
   "skill_type": "Active|Passive", "description": "...", "script_path": "res://...",
   "ignore_distance": false, "range": -1, "cooldown": 0, "max_uses_per_turn": 0, "needs_target": false}]
```

**角色库 JSON** (`data/character_database.json`):
```json
[{"name": "灰琪", "species": "EarthPony", "max_health": 14, "speed": 1,
   "physical_ability": 2, "magic_ability": 1, "mental_ability": 1,
   "physical_defence": 2, "magic_defence": 0, "mental_defence": 0,
   "draw_stage_card_number": 2, "start_game_draw": 4,
   "collection_item_ids": ["派对大炮", "衣服", "宝石"],
   "character_skill_ids": ["maud_prospect", "maud_calm"],
   "species_skill_ids": ["earth_pony_strength"]}]
```
- **不含 `armor`**（默认 0）和 **不含 `start_hand`**（由 HudBattle 从抽牌堆抽）

### Turn Manager (`turn_manager.gd`)

存活玩家有序链表，player-relative 轮次计数。
- `setup(players)` + `start_game(index)` → `turn_started` signal
- `end_current_turn()` → `turn_ended` signal → `_advance_to_next_alive()` → `turn_started`
- `remove_player(p)` — 玩家死亡时移除，`player_eliminated` 信号。只剩 1 人时 `last_player_standing` 信号
- 胜利条件：最后存活（收藏品胜利条件已移除，`collection_completed` 信号仅记录日志）

### Event System (`event_system/`)

独立于普通卡牌系统的全局事件机制。事件由**事件触发牌**或**技能**触发，可以影响所有玩家、地图、甚至其他事件。

**核心概念**:
- **事件触发牌** (`EventTriggerCard`): 在普通抽牌堆中，nice_name="事件触发牌"。抽到时直接打出（不进手牌），触发随机事件。触发后进普通弃牌堆。
- **事件牌** (`EventCardData`): 在独立的事件牌堆中，事件触发时随机抽取。用后进事件弃牌堆。
- **瞬时效果**: 事件触发时立即执行（摸牌、移动、弃牌、伤害等）。
- **持续效果** (`GlobalEffect`): 注册到 EventManager.active_effects，在特定时机影响玩家（pull 模型）。
- **事件后抽牌**: 事件触发牌触发的事件，瞬时效果结算后触发者从普通抽牌堆摸 1 张牌（可能级联）。
- **级联**: 事件后抽牌如果抽到事件触发牌 → 再次触发（递归）。

**事件触发牌处理（两个入口）**:

| 场景 | 入口 | 行为 |
|------|------|------|
| 回合开始 / 出牌阶段点击抽牌堆 / 卡牌效果抽牌 | `DrawCard._draw_one_card()` | 抽到事件触发牌 → 进弃牌堆 → 触发事件 → 事件后抽牌（递归级联） |
| 初始手牌 | `EventTriggerPhase` | 循环检查手牌中的事件触发牌 → 依次打出 → 事件后抽牌调 `DrawCard._draw_one_card()` |

**默认链**: `TurnStart → DrawCard → EventTriggerPhase`

**组件**:

- **EventManager** (`event_manager.gd`) — 节点，放在 `logic` 下:
  - `trigger_event(event_id, triggerer, source, all_players)` — 触发事件（随机抽事件牌 → 执行瞬时效果 → 注册持续效果）
  - `register_effect(effect)` / `remove_effect(effect)` — 管理持续效果列表
  - `get_outgoing_damage_modifiers(player, damage_type)` — 攻击端伤害修正（被 UseBaseplay pull 查询）
  - `on_turn_start(player)` — 回合开始时检查效果过期（被 TurnStart pull 调用）
  - `reposition_player(player, cube_pos)` — 请求移动玩家（通过信号通知 HudBattle 做坐标转换）
  - 信号: `event_triggered`, `global_effect_added`, `global_effect_removed`, `player_repositioned`

- **EventDeck** (`event_deck.gd`) — 节点，放在 `logic` 下:
  - 独立于 CardManager，管理事件牌堆和事件弃牌堆
  - **默认洗牌**（与普通抽牌堆不洗牌不同）
  - 抽空后自动洗弃牌堆（只有 EventCardData 才洗回，MagicDuelCard 等非事件牌移出游戏）
  - `draw_event()` — 随机抽一张事件牌
  - `discard_event(card)` — 放入事件弃牌堆
  - `create_event_by_id(id)` — 按 event_id 创建（技能触发用）

- **EventCardData** (`event_card_data.gd`) — 事件牌 Resource 基类:
  - `DurationType` 枚举: INSTANT / UNTIL_NEXT_TRIGGER_TURN / UNTIL_END_OF_NEXT_OWN_TURN / CUSTOM
  - `execute_instant(triggerer, event_manager, all_players)` — 子类重写，执行瞬时效果
  - `create_global_effect(triggerer, all_players)` — 子类重写，创建持续效果
  - `can_enter_hand: bool` — true=进触发者手牌（魔法对决）

- **GlobalEffect** (`global_effect.gd`) — 持续效果 Resource 基类:
  - `on_register(event_manager)` / `on_remove(event_manager)` — 注册/移除时调用
  - `check_expiry(current_player, triggerer)` — 回合开始时检查过期（被 TurnStart → EventManager.on_turn_start 调用）
  - `get_outgoing_damage_modifier(player, damage_type)` — 攻击端伤害修正（pull 模型）
  - **不使用回调钩子**（R7 合规），通过 pull 模型被 action 节点查询

**五个事件**:

| 事件 | 类型 | 效果 |
|------|------|------|
| 龙卷供水 | 瞬时 | 所有天马移动到 cube(2,0,-2) + 摸 2 张牌 |
| 布里兹迁徙 | 持续 (UNTIL_NEXT_TRIGGER_TURN) | 注册 GlobalEffect 禁用所有种族技能，触发者下回合开始时过期 |
| 入戏太深 | 持续 (UNTIL_END_OF_NEXT_OWN_TURN) | 注册 GlobalEffect，触发者造成的心理伤害+2，下个回合结束后过期 |
| 魔法对决 | 进手牌 (can_enter_hand) | MagicDuelCard 进触发者手牌。打出时比较手牌数，大于对方则 3 点魔法伤害。不消耗 attack_chance |
| 送冬迎春 | 瞬时 | 所有玩家弃掉手中的法术攻击牌（BaseAttack.damage_type == Magic） |

**事件库 JSON** (`data/event_database.json`):
```json
[{"event_id": "...", "nice_name": "...", "description": "...",
  "duration_type": "INSTANT|UNTIL_NEXT_TRIGGER_TURN|...",
  "can_enter_hand": false, "instant_effect_script": "res://..."}]
```

**架构合规**:
- **R2**: 事件瞬时效果通过 ActionTree 动作执行（DrawCard 摸牌、MoveAction 移动等）
- **R6**: 坐标转换在 HudBattle（EventManager 发信号 → HudBattle 做坐标同步）
- **R7**: 持续效果用 pull 模型（UseBaseplay/TurnStart 查询 EventManager），不用回调钩子
- **R12**: 初始化不走 ActionTree，EventTriggerPhase 处理初始手牌中的事件触发牌

### Terrain System (`terrain/`)

地形效果通过 pull 模型实现。MoveAction 进入/离开格子时通知 TerrainManager，TurnStart 检查回合开始效果。

**TerrainEffect** (`terrain/terrain_effect.gd`) — 基类 Resource:
- `terrain_name: String`
- `on_enter(player)` / `on_exit(player)` / `on_turn_start(player)` / `on_turn_end(player)` — 子类重写

**TerrainManager** (`terrain/terrain_manager.gd`) — 节点，放在 `logic` 下:
- `add_terrain(cell, effect)` — 注册地形
- `on_player_moved(player, new_cell)` — 离开旧地形 + 进入新地形
- `on_turn_start(player)` — 回合开始效果
- `is_recovery_blocked(player)` / `get_attack_range_mod(player)` — 查询地形影响
- 天马免疫：检查 meta `terrain_immune`，跳过所有效果

**两个地形**:

| 地形 | 文件 | 效果 | 实现 |
|------|------|------|------|
| 森林 | `forest_terrain.gd` | 攻击距离 -1 | on_enter 设 meta `terrain_attack_range_mod`=-1 |
| 雪地 | `snow_terrain.gd` | 不能使用恢复牌 | on_enter 设 meta `terrain_blocks_recovery`=true |

**初始化**: HudBattle._setup_terrain() 在地图上放两个地形（森林: cube(1,0,-1)，雪地: cube(-1,0,1)），注入 `terrain_manager` meta 到每个 Player，tile_hud 渲染地形颜色（深绿 / 浅蓝半透明填充）。

**钩子位置**:
- MoveAction.take_action() → TerrainManager.on_player_moved
- TurnStart.take_action() → TerrainManager.on_turn_start
- UseEffect.take_action() → 检查 is_recovery_blocked（雪地阻止 Recovery 牌）

### Save Manager (`save_manager.gd`)

Autoload singleton. `store_var`/`get_var` to `user://savegame.save`.

### Damage Resource (`special_resource/damage.gd`)

`DamageType` enum: Physical, Magic, Mental, Real. Fields: type, num, ignore_armor.

### Layer System (`source_codes/layer_control/`)

- `MapLayer` — CanvasLayer for TileMap. Mouse-wheel zoom, middle-double-click reset.
- `CardLayer` / `PlayerLayer` — Placeholder CanvasLayers.

---

## HUD System (`source_codes/hud/`)

UI 布局在 `hud_battle.tscn` 场景中。`HudLayer` 下的节点树：

```
HudLayer/HudContainer/Margin/MainVBox (sep=0)
  ├── TopBar — 轮次/回合/当前玩家 / 移动指示器 / 结束按钮
  ├── VSplitter1 ← 拖拽改变 TopBar 高度
  ├── MiddleHBox (sep=0, 垂直拉伸)
  │   ├── LeftPanel (PlayerInfoPanel)
  │   ├── HSplitter1 ← 拖拽改变 LeftPanel 宽度
  │   ├── MapSpacer (鼠标穿透透明区)
  │   ├── HSplitter2 ← 拖拽改变 RightVBox 宽度
  │   └── RightVBox (sep=0)
  │       ├── CardDetailPanel → CardDetailLabel (卡牌/技能详情)
  │       ├── VSplitter2 ← 拖拽改变 CardDetailPanel 高度
  │       └── LogPanel → LogScroll → LogLabel
  ├── VSplitter3 ← 拖拽改变 BottomArea 高度
  └── BottomArea
      └── BottomVBox (sep=4)
          ├── SkillRow → SkillTray (技能栏，在手牌上方)
          └── BottomHBox (居中)
              ├── DrawPile (CardPileSprite)
              ├── HandFan (手牌扇形区, 弹性)
              ├── EquipmentBar → EquipGrid (3列2行)
              │   ├── 上排: WeaponSlot | ArmorSlot | ElementSlot
              │   └── 下排: CollectionSlot0 | CollectionSlot1 | CollectionSlot2
              └── DiscardPile (CardPileSprite)
```

动态元素（代码创建）：
- `CardArrow` — 卡牌指向箭头
- `TilemapHUD` — 六边形描边叠加层 + 地形颜色渲染
- HandFan 内卡牌 — 通过 `hand_fan.add_card()` 动态增删
- SkillTray 内 SkillSlot — 通过 `equipment_bar._refresh_skills()` 动态增删
- DiscardZone — 拖拽装备时滑入/滑出的弃置区
- CrystalMarkTrigger — 水晶洗礼技能在目标 ActionTree 上动态创建/移除
- UISplitter — 6 个可拖拽分割条（3 个 VSplitter + 2 个 HSplitter + 1 个 CardDetail/Log 之间的 VSplitter）

### Equipment Bar (`equipment_bar.gd` + `equipment_slot.gd`)

装备栏 + 收藏品栏的 HUD 组件，现在为紧凑的 3×2 网格布局。技能栏已分离到 BottomArea 顶部。

- **EquipmentBar**: PanelContainer，监听 `Player.equipment_changed` + `Player.skill_added` + `Player.skill_removed` 信号自动刷新。`setup(player, hud)` 绑定当前玩家。`set_skill_tray(tray)` 注入外部技能栏容器。DiscardZone 拖拽管理。
- **EquipmentSlot**: 紧凑方框（60×56），名称居中显示。`@export slot_type` + `@export is_collection_slot`。Godot 原生拖拽。后续可替换为小图标。
- **SkillSlot** (`skill_slot.gd`): 圆形技能槽（56×56），放在 BottomVBox/SkillRow/SkillTray 中（而非 EquipmentBar 内）。EquipmentBar 通过外部注入的 `_skill_tray` 引用管理技能槽的增删刷。
- **拖拽规则**：装备→收藏品（仅收藏品）触发 `MoveEquipmentToCollection`；收藏品→装备（仅 Weapon/Armor 类型匹配）触发 `EquipFromCollection`；装备→DiscardZone 触发 `UnequipAction`。
- **EquipmentSlot export 属性必须在 tscn 中显式设置**：ArmorSlot `slot_type=1`，ElementSlot `slot_type=2`，CollectionSlot0-2 `slot_type=3, is_collection_slot=true`。WeaponSlot 默认值已正确（slot_type=0）。
- `_on_slot_drop` 传递 `card: CardData`，Action 按 `card_identity` 查找指定收藏品（不再取第一个）。
- `_show_skill_detail(skill)` / `_clear_detail()` — HudBattle 中显示/清空技能详情。

### Hex Grid

**HexagonTileMapLayer** addon (Zehir, v2.5.2, MIT). Key API on `$MapLayer/Layer0`:

| Method | Description |
|--------|-------------|
| `map_to_cube(Vector2i) → Vector3i` | Offset → cube |
| `cube_to_map(Vector3i) → Vector2i` | Cube → offset |
| `cube_distance(a, b) → int` | Manhattan hex distance |
| `cube_range(center, N) → Array[Vector3i]` | Hexes within N steps |
| `cube_neighbors(cube) → Array[Vector3i]` | 6 adjacent hexes |
| `cube_linedraw(a, b) → Array[Vector3i]` | LOS line |
| `local_to_map(Vector2) → Vector2i` | Pixel → tile |
| `map_to_local(Vector2i) → Vector2` | Tile → pixel |

Tileset: even-r offset, horizontal axis. Map rendered at scale (2,2).

### Game Rules (`游戏规则.md`)

Full rulebook v4.1 in Chinese. Covers: win conditions, turn phases, terrain effects, equipment rules, collectibles, faint/revive, turn ordering with teams, card distribution (206 total cards).

### Tests (`test/`)

212 tests across 21 categories. Run: `../Godot_v4.6.3-stable_win64.exe --headless --path . test/test_runner.tscn`

Pattern: preload class_name scripts as `const` (bypasses headless class DB), `_test_*()` methods, `_assert(condition, name, detail)`.

---

## Refactoring Status (2026-06-24)

核心重构已完成。已解决的历史违规见 git log。

**本次更新已完成**：
- 数据库拆分：`card_database.json` + `character_database.json` + `skill_database.json` + `event_database.json` + `normal_drawpile.json` 从单文件拆为按种族/类型的子目录结构
- CardManager 改用 `_normal_paths` + `_bonus_paths` 数组加载多目录
- hexagon_tilemaplayer UID 修复（3 个 .gd 文件）、demo 禁用、zip 删除
- 新增 dialogue_manager v3.10.1、vfx_library v1.0.0 插件
- 角色精灵从 5 张扩展到 50 张（来自 mlpvector.club），放在 `assets/raw_character/mlp_vector_club/`
- Godot 升级到 4.7

剩余未解决：

| 文件 | 事项 | 说明 |
|------|------|------|
| normalcard/effect_database.json + recovery_database.json | 51 张 Effect 牌 + 10 张 Recovery 牌 | 占位空壳，无实际 execute/resolve 逻辑 |
| cardpile/hudbattle_pile/drawpile_database.json | 仅 19 张（含 3 张事件触发牌） | 规则要求 148 张摸牌堆，需扩充 |
| `EquipmentBar._swap_equipment` | 同类型拖拽交换占位 | 场景中每种槽只有 1 个，此路径暂不可达 |
| 攻击距离校验 | 未实现 | BaseWeapon.attack_range 存在但 UseCard 不检查。unicorn_magic_reach 技能提供了 attack_range_bonus meta |
| 事件系统 HUD | 未实现 | 事件牌堆/弃牌堆 sprite、全局效果面板 UI |
| 天马角色 | 未实装 | pegasus_freedom 技能已就绪，character_database 中暂无天马角色 |
| Recovery 牌实现 | 空壳 | 10 张 Recovery 牌的 execute/resolve 为占位 |

---

## Key Patterns

- **Signals** for cross-system communication.
- **Resources** (`.gd` extending `Resource`) for data objects — `CardData`, `Damage`, `SkillData`, `EventCardData`, `GlobalEffect`.
- **Identity strings** as card/skill/event keys (e.g., `"PhysicalAttack"`, `"earth_pony_strength"`, `"tornado_water_supply"`).
- **Chinese** is the primary language for UI text, card names, comments, and game rules.
- **技能通过修改 ActionTree 链条实现效果**，不使用回调钩子。链条修改逻辑写在技能自己的 .gd 里。
- **事件持续效果通过 pull 模型实现**，action 节点主动查询 EventManager，不使用回调钩子。
- **`CardManager` injection**: Battle scene creates CardManager, injects into each Player.
- **`EventManager` injection**: Battle scene creates EventManager, injects into each Player via `set_meta("event_manager", ...)`.
- **`Node.get(\"name\")` is `Object.get()`** — accesses GDScript properties, NOT child nodes.

---

## Godot 4 Gotchas

1. **`@onready var x = %UniqueName` fails** for programmatic nodes.
2. **CanvasLayer is not Control** — insert plain `Control` between CanvasLayer and containers.
3. **`Container.set_size()` is unreliable** — Containers respect child minimum sizes.
4. **`class_name` not available in headless** — Preload scripts as `const`.
5. Use `get_global_transform_with_canvas().affine_inverse() * global_pos` to convert global mouse → local space.
6. **EquipmentSlot export 属性**: Godot 不序列化等于默认值的属性。必须在 tscn 中显式设置非默认值。

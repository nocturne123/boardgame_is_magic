class_name ActionTree extends Node

## 链式动作调度器。支持暂停（waiting）和恢复（resume_chain）。

signal chain_paused(action: BaseAction)

# 默认动作
@onready var decrease_health = $DecreaseHealth
@onready var receive_damage = $ReceiveDamage
@onready var living_update = $LivingUpdate
@onready var draw_card = $DrawCard
@onready var turn_start = $TurnStart
@onready var event_trigger_phase = $EventTriggerPhase
@onready var discard_card = $DiscardCard
@onready var use_card = $UseCard
@onready var roll_dice_entry = $RollDiceEntry
@onready var roll_dice_execute = $RollDiceExecute
@onready var move_action = $MoveAction

var _current_chain_action: BaseAction = null

## 执行动作链。遇到 waiting=true 的 action 时暂停，发射 chain_paused 信号。
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

## HUD 交互完成后调用，恢复被暂停的 chain。
func resume_chain() -> void:
    if _current_chain_action == null:
        return
    _current_chain_action.waiting = false
    _current_chain_action.inform_next_action()
    _current_chain_action.reset_property()
    _current_chain_action = _current_chain_action.next_action
    _advance_chain()

# 添加默认链条
func make_default_chain():
    receive_damage.next_action = decrease_health
    decrease_health.next_action = living_update
    turn_start.next_action = draw_card
    draw_card.next_action = event_trigger_phase
    roll_dice_entry.next_action = roll_dice_execute

func _ready():
    make_default_chain()

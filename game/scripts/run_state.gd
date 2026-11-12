# RunState — mutable state for a single run. Created fresh on every restart,
# so no stale timers, signals, or references survive between runs.
extends RefCounted
class_name RunState

var balance: Balance

var hp: int
var max_hp: int
var score := 0
var time := 0.0
var wave := 1
var boss_spawned := false
var boss_alive := false
var finished := false

# Upgrade stacks applied this run.
var stacks := {
	"damage": 0,
	"rate": 0,
	"hp": 0,
	"speed": 0,
	"aoe": 0,
	"cd": 0,
}


func _init(b: Balance) -> void:
	balance = b
	max_hp = b.player_max_hp
	hp = max_hp


func damage() -> int:
	return balance.bullet_damage + stacks["damage"] * 4


func attack_interval() -> float:
	return maxf(0.12, balance.auto_attack_interval * pow(0.82, stacks["rate"]))


func move_speed() -> float:
	return balance.player_speed * (1.0 + 0.12 * stacks["speed"])


func aoe_damage() -> int:
	return balance.aoe_damage + stacks["damage"] * 6


func aoe_radius() -> float:
	return balance.aoe_radius * (1.0 + 0.18 * stacks["aoe"])


func aoe_cooldown() -> float:
	return maxf(2.0, balance.aoe_cooldown * pow(0.85, stacks["cd"]))


func add_upgrade(id: String) -> void:
	if stacks.has(id):
		stacks[id] += 1
		if id == "hp":
			max_hp += 20
			hp = mini(max_hp, hp + 20)


## Returns upgrade ids that still have capacity left.
func available_upgrades() -> Array[String]:
	var out: Array[String] = []
	var limits := {
		"damage": balance.max_stack_damage,
		"rate": balance.max_stack_rate,
		"hp": balance.max_stack_hp,
		"speed": balance.max_stack_speed,
		"aoe": balance.max_stack_aoe,
		"cd": balance.max_stack_cd,
	}
	for id in limits.keys():
		if stacks[id] < limits[id]:
			out.append(id)
	return out


func take_damage(amount: int) -> void:
	if finished:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		finished = true


func wave_for_time(t: float) -> int:
	if t < balance.wave_duration:
		return 1
	if t < balance.wave_duration * 2.0:
		return 2
	return 3

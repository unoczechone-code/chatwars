# Balance — single source of truth for gameplay numbers.
# Values are initial guesses, NOT tested economy. Tune after the first device playtest.
extends Resource
class_name Balance

@export_group("Run")
@export var run_duration := 180.0
@export var wave_duration := 60.0
@export var boss_spawn_time := 120.0
@export var upgrade_times: Array[float] = [60.0, 120.0]

@export_group("Player")
@export var player_max_hp := 100
@export var player_speed := 620.0
@export var player_move_zone_top := 0.66
@export var auto_attack_interval := 0.42
@export var bullet_speed := 1150.0
@export var bullet_damage := 10
@export var bullet_lifetime := 2.0
@export var player_hit_invuln := 0.35

@export_group("AoE")
@export var aoe_damage := 26
@export var aoe_radius := 200.0
@export var aoe_cooldown := 6.0

@export_group("Enemies")
@export var faller_hp := 30
@export var faller_speed := 190.0
@export var faller_damage := 8
@export var faller_score := 10

@export var weaver_hp := 22
@export var weaver_speed := 260.0
@export var weaver_damage := 7
@export var weaver_score := 15
@export var weaver_amplitude := 90.0
@export var weaver_frequency := 3.2

@export var brute_hp := 90
@export var brute_speed := 95.0
@export var brute_damage := 18
@export var brute_score := 30

@export var boss_hp := 900
@export var boss_speed := 70.0
@export var boss_damage := 22
@export var boss_score := 250
@export var boss_burst_count := 7
@export var boss_burst_interval := 2.6
@export var boss_sweep_interval := 6.5

@export_group("Spawn")
@export var spawn_interval_start := 1.15
@export var spawn_interval_end := 0.55
@export var max_enemies := 60
@export var max_projectiles := 120

@export_group("Limits")
@export var max_stack_damage := 5
@export var max_stack_rate := 4
@export var max_stack_hp := 4
@export var max_stack_speed := 3
@export var max_stack_aoe := 3
@export var max_stack_cd := 3

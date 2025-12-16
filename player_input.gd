class_name PlayerInput
extends RefCounted

var move: Vector2 = Vector2.ZERO # left stick
var aim: Vector2 = Vector2.ZERO # right stick

var turbo: bool = false

var build_wall: bool = false
var build_harvester: bool = false
var build_turret: bool = false
var boost_shield: bool = false

func update(_player, _delta): pass

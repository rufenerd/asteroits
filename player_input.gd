class_name PlayerInput
extends RefCounted

var move := Vector2.ZERO   # left stick
var aim := Vector2.ZERO    # right stick

var fire := false
var turbo := false

var build_wall := false
var build_harvester := false
var build_turret := false
var boost_shield := false

func update(_player, _delta): pass

extends Node
class_name SimClock

# Manages simulation time.
# The SimClock increases its current time each frame based on delta and time_scale.
# You can connect to the 'tick' signal to be notified of time updates.

signal tick(delta_time: float, current_time: float)

var current_time: float = 0.0
var time_scale: float = 1.0
# Placeholder for emballage delay semantics; to be implemented in later stages.
var emballage_delay: float = 0.0

func _process(delta: float) -> void:
    var scaled_delta = delta * time_scale
    current_time += scaled_delta
    emit_signal("tick", scaled_delta, current_time)

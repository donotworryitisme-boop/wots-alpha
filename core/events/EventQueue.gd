extends Node
class_name EventQueue

# A simple event queue that schedules and executes callbacks at specified simulation times.

var queue: Array = []

func schedule_event_at(time: float, callback: Callable) -> void:
	# Schedule a callback to run at an absolute simulation time.
	queue.append({"time": time, "callback": callback})
	# Sort queue by time ascending using a single Callable.
	queue.sort_custom(Callable(self, "_sort_events"))

func schedule_event_in(delay: float, callback: Callable, sim_clock: SimClock) -> void:
	# Schedule a callback relative to the current simulation time.
	var event_time = sim_clock.current_time + delay
	schedule_event_at(event_time, callback)

func _sort_events(a: Dictionary, b: Dictionary) -> bool:
	return a["time"] < b["time"]

func process_events(current_time: float) -> void:
	# Process all events whose scheduled time has passed.
	var idx := 0
	while idx < queue.size():
		var ev = queue[idx]
		if ev["time"] <= current_time:
			var cb: Callable = ev["callback"]
			# Remove event before calling to avoid reprocessing if it schedules new events.
			queue.remove_at(idx)
			if cb != null:
				cb.call()
			# Do not increment idx since we removed current element.
			continue
		idx += 1

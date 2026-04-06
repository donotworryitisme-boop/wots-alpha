class_name FadeSystem
extends RefCounted

## Manages full-screen fade and crossfade/slide transitions.
## Extracted from BayUI to keep it under the 800-line limit.

var _ui: BayUI

# --- FADE TRANSITIONS ---
const FADE_DURATION: float = 0.855
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null

# --- CROSSFADE / SLIDE ---
const XFADE_DURATION: float = 0.15
const SLIDE_DURATION: float = 0.28
const SLIDE_OFFSET: float = 50.0
var _xfade_tween: Tween = null
var _xfade_mid_cb: Callable = Callable()
var _xfade_target: Control = null


func _init(ui: BayUI) -> void:
	_ui = ui


func build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 19
	_fade_layer.name = "BayFadeOverlay"
	_ui.add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = UITokens.CLR_TRANSPARENT
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


func fade_transition(mid_callback: Callable) -> void:
	if _fade_rect == null:
		if mid_callback.is_valid(): mid_callback.call()
		return
	if _fade_tween != null and _fade_tween.is_valid(): _fade_tween.kill()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = _ui.create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func() -> void:
		if mid_callback.is_valid(): mid_callback.call()
	)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func() -> void:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


func crossfade(target: Control, mid_callback: Callable) -> void:
	if target == null:
		if mid_callback.is_valid(): mid_callback.call()
		return
	if _xfade_tween != null and _xfade_tween.is_valid():
		_xfade_tween.kill()
		var pending: Callable = _xfade_mid_cb
		_xfade_mid_cb = Callable()
		if _xfade_target != null and is_instance_valid(_xfade_target):
			_xfade_target.modulate.a = 1.0
		if pending.is_valid(): pending.call()
	_xfade_target = target
	_xfade_mid_cb = mid_callback
	_xfade_tween = _ui.create_tween()
	_xfade_tween.tween_property(target, "modulate:a", 0.0, XFADE_DURATION)
	_xfade_tween.tween_callback(func() -> void:
		_xfade_mid_cb = Callable()
		if mid_callback.is_valid(): mid_callback.call()
	)
	_xfade_tween.tween_property(target, "modulate:a", 1.0, XFADE_DURATION)
	_xfade_tween.tween_callback(func() -> void:
		_xfade_target = null
	)

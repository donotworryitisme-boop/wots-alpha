extends Node
class_name UITokens

# Execution 8.8.1 — UI Token Sheet (single source of truth)
# NOTE: This is foundational. UI scenes should rely on the Theme + these constants.
# Neutral naming; no gameplay implications.

# Colors
const COLOR_BG: Color = Color(0.06, 0.07, 0.08, 1.0)
const COLOR_SURFACE: Color = Color(0.10, 0.11, 0.13, 1.0)
const COLOR_BORDER: Color = Color(0.22, 0.24, 0.28, 1.0)
const COLOR_TEXT_PRIMARY: Color = Color(0.94, 0.95, 0.97, 1.0)
const COLOR_TEXT_META: Color = Color(0.70, 0.73, 0.78, 1.0)
const COLOR_ACCENT_BLUE: Color = Color(0.25, 0.75, 1.00, 1.0)

# Spacing / radii
const SPACING_8: int = 8
const SPACING_16: int = 16
const SPACING_24: int = 24
const RADIUS: int = 8

# Fonts (Godot built-in default font family)
# We keep this as a lightweight token sheet without introducing new font assets.
# Sizes are applied in UITheme.tres.
const FONT_BODY_SIZE: int = 16
const FONT_BODY_MEDIUM_SIZE: int = 16
const FONT_META_SIZE: int = 13

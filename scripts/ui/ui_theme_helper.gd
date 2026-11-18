class_name UIThemeHelper
extends RefCounted
## Builds a shared bamboo-and-wood pixel art Theme for all menus and gameplay modals.

static var _cached_theme: Theme


static func get_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme

	var t := Theme.new()
	t.default_font_size = 8

	var panel_sb := _make_nine_slice("res://assets/ui/bamboo_panel.png", Color(0.95, 0.85, 0.68), Color(0.48, 0.32, 0.16))
	var btn_norm := _make_nine_slice("res://assets/ui/wood_button.png", Color(0.77, 0.54, 0.29), Color(0.38, 0.22, 0.10))
	var btn_hover := _make_nine_slice("res://assets/ui/wood_button.png", Color(0.88, 0.65, 0.36), Color(0.38, 0.22, 0.10))
	var btn_press := _make_nine_slice("res://assets/ui/wood_button.png", Color(0.64, 0.42, 0.21), Color(0.38, 0.22, 0.10))

	t.set_stylebox("panel", "PanelContainer", panel_sb)
	t.set_stylebox("panel", "Panel", panel_sb)
	t.set_stylebox("normal", "Button", btn_norm)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_press)
	t.set_stylebox("focus", "Button", btn_hover)

	var dark_ink := Color(0.20, 0.12, 0.08)
	t.set_color("font_color", "Label", dark_ink)
	t.set_color("font_color", "Button", dark_ink)
	t.set_color("font_hover_color", "Button", dark_ink)
	t.set_color("font_pressed_color", "Button", dark_ink)

	_cached_theme = t
	return t


static func _make_nine_slice(tex_path: String, fallback_bg: Color, fallback_border: Color) -> StyleBox:
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex != null:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			sb.texture_margin_left = 4
			sb.texture_margin_right = 4
			sb.texture_margin_top = 4
			sb.texture_margin_bottom = 4
			sb.content_margin_left = 6
			sb.content_margin_right = 6
			sb.content_margin_top = 5
			sb.content_margin_bottom = 5
			return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = fallback_bg
	flat.border_color = fallback_border
	flat.set_border_width_all(2)
	flat.set_content_margin_all(6)
	return flat

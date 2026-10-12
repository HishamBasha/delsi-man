extends Control
## Pepsiman-style start menu: the screen opens straight onto its content with
## the theme song already playing, one START button begins the run, and
## language/assist/sound sit behind a gear button that stays in the corner.

signal start_requested
signal language_requested
signal assist_requested
signal sound_requested
signal beep(hz: float, seconds: float)

const LOGO_EN = preload("res://assets/ui/English Delsi Cola Logo.png")
const LOGO_AR = preload("res://assets/ui/Arabic Delsi Cola Logo.png")
const THEME_SONG = preload("res://audio/music/theme_song.mp3")
const MUSIC_PLAY_DB := -16.0
const MUSIC_SILENT_DB := -80.0
const MUSIC_FADE_DB := 55.0

var lang := "en"
var assist := false
var sound_on := true
var phase := "main"
var blink := 0.0
var music: AudioStreamPlayer
var logo: TextureRect
var title_label: Label
var subtitle: Label
var main_panel: PanelContainer
var settings_panel: PanelContainer
var start_button: Button
var gear_button: Button
var lang_button: Button
var assist_button: Button
var sound_button: Button
var back_button: Button
var hint: Label
var settings_hint: Label
var footer: Label
var main_buttons: Array[Button] = []
var settings_buttons: Array[Button] = []

## Default font plus a system-font fallback so Arabic glyphs actually render.
## The symbol fonts at the end cover the gear mark on the settings button.
static func ui_font() -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray([
		"Segoe UI Arabic", "Segoe UI", "Arial", "Tahoma", "Times New Roman",
		"Noto Sans Arabic", "Noto Naskh Arabic", "Geeza Pro", "Arabic Typesetting",
		"Segoe UI Symbol", "Segoe UI Emoji", "Noto Sans Symbols 2", "DejaVu Sans",
	])
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.fallbacks = [sys]
	return variation

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_background()
	build_content()
	music = AudioStreamPlayer.new()
	var song: Variant = THEME_SONG
	if "loop" in song:
		song.loop = true
	music.stream = song
	music.volume_db = MUSIC_SILENT_DB
	add_child(music)
	visible = false
	refresh_phase()

func outlined(text_value: String, size: int, color: Color, outline: Color, outline_size: int) -> Label:
	var n = Label.new()
	n.text = text_value
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	n.add_theme_color_override("font_outline_color", outline)
	n.add_theme_constant_override("outline_size", outline_size)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

func plain(text_value: String, size: int, color: Color) -> Label:
	var n = Label.new()
	n.text = text_value
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

func build_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color("0a2740")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var band = ColorRect.new()
	band.color = Color("17528e", 0.55)
	band.size = Vector2(1700, 210)
	band.position = Vector2(-210, 120)
	band.rotation = -0.09
	band.pivot_offset = band.size * 0.5
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var strip = ColorRect.new()
	strip.color = Color("061a2d", 0.85)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -46
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

func panel_style() -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.07, 0.13, 0.92)
	box.border_color = Color("3f7fbf")
	box.set_border_width_all(2)
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 22
	box.content_margin_bottom = 18
	return box

func item_button(text_value: String, on_press: Callable) -> Button:
	var b = Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(470, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("cfe4ff"))
	b.add_theme_color_override("font_hover_color", Color("ffe9a8"))
	b.add_theme_color_override("font_focus_color", Color("ffe9a8"))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.04)
	normal.set_content_margin_all(10)
	normal.set_content_margin(Side.SIDE_LEFT, 24)
	normal.set_content_margin(Side.SIDE_RIGHT, 24)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	b.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("hover", hover)
	var focus = normal.duplicate()
	focus.bg_color = Color("14508c", 0.9)
	focus.border_color = Color("ffd75e")
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	var pressed = normal.duplicate()
	pressed.bg_color = Color("ffd75e", 0.35)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(func():
		beep.emit(760.0, 0.05)
		on_press.call())
	b.focus_entered.connect(func(): beep.emit(640.0, 0.035))
	return b

func build_content() -> void:
	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	logo = TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(360, 150)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(logo)
	title_label = outlined("DELSI MAN", 62, Color.WHITE, Color("04121f"), 9)
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(title_label)
	subtitle = plain("A YEMENI FLAVOR ADVENTURE", 16, Color("6bd7d4"))
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(subtitle)
	main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_panel.add_theme_stylebox_override("panel", panel_style())
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(main_panel)
	var main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 10)
	main_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_child(main_box)
	start_button = item_button("PRESS TO PLAY", func(): start_requested.emit())
	start_button.add_theme_font_size_override("font_size", 34)
	main_box.add_child(start_button)
	main_buttons.append(start_button)
	hint = plain("Press any key · ⚙ settings", 14, Color("8fb9d8"))
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_box.add_child(hint)
	settings_panel = PanelContainer.new()
	settings_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_panel.add_theme_stylebox_override("panel", panel_style())
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(settings_panel)
	var settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	settings_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_panel.add_child(settings_box)
	lang_button = item_button("LANG: EN / العربية", func(): language_requested.emit())
	settings_box.add_child(lang_button)
	settings_buttons.append(lang_button)
	assist_button = item_button("ASSIST: OFF", func(): assist_requested.emit())
	settings_box.add_child(assist_button)
	settings_buttons.append(assist_button)
	sound_button = item_button("SOUND: ON", func(): sound_requested.emit())
	settings_box.add_child(sound_button)
	settings_buttons.append(sound_button)
	back_button = item_button("← BACK", func(): close_settings())
	settings_box.add_child(back_button)
	settings_buttons.append(back_button)
	settings_hint = plain("Esc back · ↑↓ select", 14, Color("8fb9d8"))
	settings_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_box.add_child(settings_hint)
	gear_button = Button.new()
	gear_button.text = "⚙"
	gear_button.tooltip_text = "Settings"
	gear_button.custom_minimum_size = Vector2(54, 54)
	gear_button.add_theme_font_size_override("font_size", 28)
	gear_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear_button.offset_left = -68.0
	gear_button.offset_right = -14.0
	gear_button.offset_top = 14.0
	gear_button.offset_bottom = 68.0
	gear_button.pressed.connect(func():
		beep.emit(760.0, 0.05)
		toggle_settings())
	add_child(gear_button)
	footer = plain("Original development build · Brand artwork pending approval", 12, Color("8699aa"))
	footer.anchor_left = 0.0
	footer.anchor_right = 1.0
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -40.0
	footer.offset_bottom = -8.0
	add_child(footer)

func refresh_phase() -> void:
	var in_settings = phase == "settings"
	main_panel.visible = not in_settings
	settings_panel.visible = in_settings
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null and not focused.is_visible_in_tree():
		focused.release_focus()

func active_buttons() -> Array[Button]:
	return settings_buttons if phase == "settings" else main_buttons

func toggle_settings() -> void:
	if phase == "settings":
		close_settings()
	else:
		enter_settings()

func enter_settings() -> void:
	if phase == "settings":
		return
	phase = "settings"
	refresh_phase()
	if not settings_buttons.is_empty():
		settings_buttons[0].grab_focus()

func close_settings() -> void:
	if phase != "settings":
		return
	phase = "main"
	refresh_phase()
	start_button.grab_focus()
	beep.emit(440.0, 0.05)

func sync(new_lang: String, new_assist: bool, new_sound: bool) -> void:
	lang = new_lang
	assist = new_assist
	sound_on = new_sound
	layout_direction = Control.LAYOUT_DIRECTION_RTL if lang == "ar" else Control.LAYOUT_DIRECTION_LTR
	apply_texts()

func open() -> void:
	var reopening := visible
	visible = true
	if not reopening:
		phase = "main"
	apply_texts()
	refresh_phase()
	start_music()
	if not reopening:
		start_button.grab_focus()

## The song is part of the screen: it comes up at full level the moment the
## menu appears instead of waiting on a fade from silence.
func start_music() -> void:
	if music == null:
		return
	if not sound_on:
		music.volume_db = MUSIC_SILENT_DB
		return
	music.volume_db = MUSIC_PLAY_DB
	if not music.playing:
		music.play()

func apply_texts() -> void:
	var ar = lang == "ar"
	logo.texture = LOGO_AR if ar else LOGO_EN
	title_label.text = "ديلسي مان" if ar else "DELSI MAN"
	subtitle.text = "مغامرة نكهة يمنية" if ar else "A YEMENI FLAVOR ADVENTURE"
	start_button.text = "اضغط للعب" if ar else "PRESS TO PLAY"
	lang_button.text = "اللغة: AR / English" if ar else "LANG: EN / العربية"
	assist_button.text = ("المساعدة: " + ("نعم" if assist else "لا")) if ar else ("ASSIST: " + ("ON" if assist else "OFF"))
	sound_button.text = ("الصوت: مفعّل" if sound_on else "الصوت: مطفأ") if ar else ("SOUND: ON" if sound_on else "SOUND: OFF")
	back_button.text = "← رجوع" if ar else "← BACK"
	hint.text = "اضغط أي مفتاح · ⚙ الإعدادات" if ar else "Press any key · ⚙ settings"
	settings_hint.text = "Esc رجوع · ↑↓ اختيار" if ar else "Esc back · ↑↓ select"
	footer.text = "نسخة تطوير أصلية · هوية العلامة بانتظار الموافقة" if ar else "Original development build · Brand artwork pending approval"
	gear_button.tooltip_text = "الإعدادات" if ar else "Settings"

func move_focus(step: int) -> void:
	var list = active_buttons()
	if list.is_empty():
		return
	var index = 0
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		index = list.find(focus_owner)
		if index < 0:
			index = 0
	list[wrapi(index + step, 0, list.size())].grab_focus()

func press_to_play() -> void:
	beep.emit(880.0, 0.06)
	start_requested.emit()

func _gui_input(event: InputEvent) -> void:
	if phase == "main" and event is InputEventMouseButton and event.pressed:
		accept_event()
		press_to_play()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.echo:
		return
	if phase == "settings" and event.is_action_pressed("pause"):
		accept_unhandled()
		close_settings()
		return
	if phase == "main" and event.is_pressed() and not event.is_action_pressed("pause"):
		if event is InputEventKey or event is InputEventJoypadButton:
			accept_unhandled()
			press_to_play()
			return
	if event.is_action_pressed("jump") and event is InputEventKey and event.physical_keycode == KEY_W:
		accept_unhandled()
		move_focus(-1)
	elif event.is_action_pressed("slide") and event is InputEventKey and event.physical_keycode == KEY_S:
		accept_unhandled()
		move_focus(1)

func accept_unhandled() -> void:
	get_viewport().set_input_as_handled()

func update_music(dt: float) -> void:
	if music == null:
		return
	var needed = visible and sound_on
	if needed and not music.playing:
		music.volume_db = MUSIC_PLAY_DB
		music.play()
	if music.playing:
		var target = MUSIC_PLAY_DB if needed else MUSIC_SILENT_DB
		music.volume_db = move_toward(music.volume_db, target, MUSIC_FADE_DB * dt)
		if not visible and music.volume_db <= MUSIC_SILENT_DB + 0.5:
			music.stop()

func _process(dt: float) -> void:
	update_music(dt)
	if not visible:
		return
	blink += dt
	if phase == "main" and start_button != null:
		start_button.modulate.a = 1.0 if fmod(blink, 1.0) < 0.62 else 0.25

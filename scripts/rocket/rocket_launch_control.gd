extends Control

class RocketPreview extends Control:
	var launch_progress: float = 0.0
	var flames_active: bool = false

	func _draw() -> void:
		var offset := Vector2(0.0, -launch_progress * 170.0)

		# Main vehicle body and nose cone.
		draw_rect(Rect2(Vector2(88, 94) + offset, Vector2(54, 132)), Color("#dce5ed"))
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(88, 96), Vector2(115, 48), Vector2(142, 96)
			]) + PackedVector2Array([offset, offset, offset]),
			Color("#f4f7fa")
		)
		draw_rect(Rect2(Vector2(88, 94) + offset, Vector2(54, 10)), Color("#8999aa"))
		draw_rect(Rect2(Vector2(94, 117) + offset, Vector2(42, 18)), Color("#3978a8"))
		draw_rect(Rect2(Vector2(100, 120) + offset, Vector2(10, 12)), Color("#8bd5e8"))
		draw_rect(Rect2(Vector2(120, 120) + offset, Vector2(10, 12)), Color("#8bd5e8"))
		draw_rect(Rect2(Vector2(88, 208) + offset, Vector2(54, 18)), Color("#68788a"))

		# Side boosters.
		draw_rect(Rect2(Vector2(61, 122) + offset, Vector2(20, 102)), Color("#b9c5d1"))
		draw_rect(Rect2(Vector2(145, 122) + offset, Vector2(20, 102)), Color("#b9c5d1"))
		draw_rect(Rect2(Vector2(61, 122) + offset, Vector2(20, 12)), Color("#dce5ed"))
		draw_rect(Rect2(Vector2(145, 122) + offset, Vector2(20, 12)), Color("#dce5ed"))
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(61, 224), Vector2(81, 224), Vector2(72, 244)
			]) + PackedVector2Array([offset, offset, offset]),
			Color("#7e8b99")
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(145, 224), Vector2(165, 224), Vector2(154, 244)
			]) + PackedVector2Array([offset, offset, offset]),
			Color("#7e8b99")
		)

		if flames_active:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(96, 226), Vector2(134, 226),
					Vector2(128, 265), Vector2(115, 248), Vector2(102, 265)
				]) + PackedVector2Array([offset, offset, offset, offset, offset]),
				Color("#ff9f43")
			)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(108, 228), Vector2(122, 228),
					Vector2(115, 253)
				]) + PackedVector2Array([offset, offset, offset]),
				Color("#fff0a6")
			)


const SYSTEMS := [
	{"name": "Propulsion", "cost": 10, "heat": 4},
	{"name": "Electrical", "cost": 8, "heat": 2},
	{"name": "Thermal Control", "cost": 8, "heat": -8},
	{"name": "Navigation", "cost": 10, "heat": 1},
	{"name": "Communications", "cost": 6, "heat": 1}
]

const INITIAL_RESOURCES := {
	"Fuel": 100.0,
	"Power": 100.0,
	"Thermal Load": 24.0,
	"Oxygen": 100.0
}
const MOON_SCENE_PATH := "res://scenes/moon_base.tscn"

var resources: Dictionary = INITIAL_RESOURCES.duplicate()
var subsystem_ready: Dictionary = {}
var resource_bars: Dictionary = {}
var resource_values: Dictionary = {}
var system_status_labels: Dictionary = {}
var system_buttons: Dictionary = {}

var rocket_preview: RocketPreview
var status_label: Label
var readiness_label: Label
var countdown_label: Label
var launch_button: Button
var service_button: Button
var service_charges: int = 2
var launch_in_progress: bool = false
var mission_complete: bool = false
var launch_tween: Tween
var launch_sequence_id: int = 0


func _ready() -> void:
	for system in SYSTEMS:
		subsystem_ready[system.name] = false

	_build_interface()
	_refresh_interface()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#08111f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)

	var heading_column := VBoxContainer.new()
	heading_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_column)

	var heading := _make_label("LUNAR MISSION CONTROL", 27, Color("#edf4fb"))
	heading_column.add_child(heading)
	heading_column.add_child(_make_label("FLIGHT SYSTEMS  /  PRE-LAUNCH OPERATIONS", 12, Color("#8fa7bd")))

	status_label = _make_label("INITIALIZING VEHICLE...", 14, Color("#f3c969"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(status_label)

	var separator := HSeparator.new()
	page.add_child(separator)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 16)
	page.add_child(main_row)

	var vehicle_panel := _make_panel()
	vehicle_panel.custom_minimum_size.x = 280
	main_row.add_child(vehicle_panel)

	var vehicle_column := VBoxContainer.new()
	vehicle_column.add_theme_constant_override("separation", 10)
	vehicle_panel.add_child(vehicle_column)
	vehicle_column.add_child(_make_label("VEHICLE OVERVIEW", 16, Color("#dce8f3")))

	rocket_preview = RocketPreview.new()
	rocket_preview.custom_minimum_size = Vector2(220, 290)
	rocket_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rocket_preview.clip_contents = true
	vehicle_column.add_child(rocket_preview)

	vehicle_column.add_child(_make_label("LUNAR ASCENT VEHICLE", 13, Color("#dce8f3")))
	vehicle_column.add_child(_make_label("Payload: Communications satellite", 11, Color("#8fa7bd")))
	vehicle_column.add_child(_make_label("Mission: Lunar orbit deployment", 11, Color("#8fa7bd")))

	var systems_panel := _make_panel()
	systems_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.add_child(systems_panel)

	var systems_column := VBoxContainer.new()
	systems_column.add_theme_constant_override("separation", 12)
	systems_panel.add_child(systems_column)

	systems_column.add_child(_make_label("VEHICLE RESOURCES", 16, Color("#dce8f3")))
	_add_resource_row(systems_column, "Fuel")
	_add_resource_row(systems_column, "Power")
	_add_resource_row(systems_column, "Thermal Load")
	_add_resource_row(systems_column, "Oxygen")

	var resource_actions := HBoxContainer.new()
	resource_actions.add_theme_constant_override("separation", 8)
	systems_column.add_child(resource_actions)

	service_button = _make_button("SERVICE VEHICLE (2)", Color("#294866"))
	service_button.pressed.connect(_on_service_pressed)
	resource_actions.add_child(service_button)

	var resource_note := _make_label("Service restores reserves; limited uses.", 10, Color("#8fa7bd"))
	resource_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resource_actions.add_child(resource_note)

	var system_separator := HSeparator.new()
	systems_column.add_child(system_separator)
	systems_column.add_child(_make_label("FLIGHT SYSTEM CHECKLIST", 16, Color("#dce8f3")))
	systems_column.add_child(_make_label("Complete each check before requesting launch.", 11, Color("#8fa7bd")))

	for system in SYSTEMS:
		_add_system_row(systems_column, system)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)

	var mission_column := VBoxContainer.new()
	mission_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(mission_column)

	readiness_label = _make_label("READINESS: CHECKS REQUIRED", 14, Color("#f3c969"))
	mission_column.add_child(readiness_label)
	countdown_label = _make_label("Awaiting launch authorization.", 11, Color("#8fa7bd"))
	mission_column.add_child(countdown_label)

	var reset_button := _make_button("RESET SCENARIO", Color("#26384b"))
	reset_button.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_button)

	launch_button = _make_button("INITIATE LAUNCH", Color("#236b63"))
	launch_button.custom_minimum_size = Vector2(190, 46)
	launch_button.pressed.connect(_on_launch_pressed)
	footer.add_child(launch_button)


func _add_resource_row(parent: VBoxContainer, resource_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var name_label := _make_label(resource_name, 12, Color("#c6d5e3"))
	name_label.custom_minimum_size.x = 105
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = float(resources[resource_name])
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 14
	row.add_child(bar)

	var value_label := _make_label("%d%%" % int(resources[resource_name]), 11, Color("#dce8f3"))
	value_label.custom_minimum_size.x = 42
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	resource_bars[resource_name] = bar
	resource_values[resource_name] = value_label


func _add_system_row(parent: VBoxContainer, system: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_label := _make_label(system.name, 13, Color("#dce8f3"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var state_label := _make_label("NOT CHECKED", 10, Color("#d59b62"))
	state_label.custom_minimum_size.x = 95
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(state_label)
	system_status_labels[system.name] = state_label

	var button := _make_button("RUN CHECK", Color("#294866"))
	button.custom_minimum_size.x = 112
	button.pressed.connect(_on_system_check_pressed.bind(system))
	row.add_child(button)
	system_buttons[system.name] = button


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111f30")
	style.border_color = Color("#2a4057")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _make_button(button_text: String, fill_color: Color) -> Button:
	var button := Button.new()
	button.text = button_text
	button.add_theme_color_override("font_color", Color("#f2f6fa"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _button_style(fill_color))
	button.add_theme_stylebox_override("hover", _button_style(fill_color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _button_style(fill_color.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#263342")))
	return button


func _button_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _on_system_check_pressed(system: Dictionary) -> void:
	if launch_in_progress or mission_complete:
		return

	var system_name: String = system.name
	var power_cost: float = float(system.cost)
	if float(resources["Power"]) < power_cost:
		status_label.text = "INSUFFICIENT POWER FOR %s CHECK" % system_name.to_upper()
		return

	resources["Power"] = float(resources["Power"]) - power_cost
	resources["Thermal Load"] = clampf(
		float(resources["Thermal Load"]) + float(system.heat), 0.0, 100.0
	)
	subsystem_ready[system_name] = true
	system_status_labels[system_name].text = "ONLINE"
	system_status_labels[system_name].add_theme_color_override("font_color", Color("#76d6a2"))
	system_buttons[system_name].text = "COMPLETE"
	system_buttons[system_name].disabled = true
	status_label.text = "%s SYSTEM CHECK PASSED" % system_name.to_upper()
	_refresh_interface()


func _on_service_pressed() -> void:
	if launch_in_progress or mission_complete or service_charges <= 0:
		return

	resources["Fuel"] = minf(float(resources["Fuel"]) + 25.0, 100.0)
	resources["Power"] = minf(float(resources["Power"]) + 25.0, 100.0)
	resources["Thermal Load"] = maxf(float(resources["Thermal Load"]) - 20.0, 0.0)
	resources["Oxygen"] = minf(float(resources["Oxygen"]) + 20.0, 100.0)
	service_charges -= 1
	status_label.text = "VEHICLE SERVICE COMPLETE"
	_refresh_interface()


func _can_launch() -> bool:
	if launch_in_progress or mission_complete:
		return false

	for system in SYSTEMS:
		if not bool(subsystem_ready[system.name]):
			return false

	return (
		float(resources["Fuel"]) >= 70.0
		and float(resources["Power"]) >= 30.0
		and float(resources["Thermal Load"]) <= 80.0
		and float(resources["Oxygen"]) >= 40.0
	)


func _refresh_interface() -> void:
	for resource_name in resources:
		var value: float = float(resources[resource_name])
		resource_bars[resource_name].value = value
		resource_values[resource_name].text = "%d%%" % int(round(value))

	service_button.text = "SERVICE VEHICLE (%d)" % service_charges
	service_button.disabled = service_charges <= 0 or launch_in_progress or mission_complete

	var all_checks_complete := true
	for system in SYSTEMS:
		if not bool(subsystem_ready[system.name]):
			all_checks_complete = false
			break

	if mission_complete:
		readiness_label.text = "MISSION STATUS: LUNAR TRANSFER"
		readiness_label.add_theme_color_override("font_color", Color("#76d6a2"))
		status_label.text = "FLIGHT CONFIRMED"
		status_label.add_theme_color_override("font_color", Color("#76d6a2"))
		launch_button.text = "ENTER MOON BASE"
		launch_button.disabled = false
	elif _can_launch():
		readiness_label.text = "READINESS: GO FOR LAUNCH"
		readiness_label.add_theme_color_override("font_color", Color("#76d6a2"))
		status_label.text = "GO FOR LAUNCH"
		status_label.add_theme_color_override("font_color", Color("#76d6a2"))
		launch_button.text = "INITIATE LAUNCH"
		launch_button.disabled = false
	elif all_checks_complete:
		readiness_label.text = "READINESS: RESOURCE LIMITS NOT MET"
		readiness_label.add_theme_color_override("font_color", Color("#f3c969"))
		status_label.text = "RESOURCE LIMITS NOT MET"
		status_label.add_theme_color_override("font_color", Color("#f3c969"))
		launch_button.disabled = true
	else:
		readiness_label.text = "READINESS: %d / %d SYSTEMS CHECKED" % [
			_count_ready_systems(), SYSTEMS.size()
		]
		readiness_label.add_theme_color_override("font_color", Color("#f3c969"))
		status_label.add_theme_color_override("font_color", Color("#f3c969"))
		launch_button.disabled = true


func _count_ready_systems() -> int:
	var count := 0
	for system in SYSTEMS:
		if bool(subsystem_ready[system.name]):
			count += 1
	return count


func _on_launch_pressed() -> void:
	if mission_complete:
		_enter_moon_base()
		return
	if not _can_launch():
		return

	launch_sequence_id += 1
	var current_sequence_id := launch_sequence_id
	launch_in_progress = true
	launch_button.disabled = true
	service_button.disabled = true
	rocket_preview.flames_active = true
	rocket_preview.queue_redraw()
	status_label.text = "LAUNCH SEQUENCE INITIATED"
	countdown_label.text = "Flight computer executing countdown..."

	launch_tween = create_tween()
	launch_tween.tween_method(_set_rocket_progress, 0.0, 1.0, 5.0)

	for seconds in range(5, 0, -1):
		countdown_label.text = "LIFTOFF IN T-%02d" % seconds
		await get_tree().create_timer(1.0).timeout
		if current_sequence_id != launch_sequence_id:
			return

	if current_sequence_id != launch_sequence_id:
		return

	_complete_launch()
	countdown_label.text = "Flight confirmed. Lunar insertion in 2 seconds..."
	await get_tree().create_timer(2.0).timeout
	if current_sequence_id != launch_sequence_id or not mission_complete:
		return
	_enter_moon_base()


func _enter_moon_base() -> void:
	var moon_scene := load(MOON_SCENE_PATH) as PackedScene
	if moon_scene == null:
		status_label.text = "MOON SCENE LOAD FAILED"
		readiness_label.text = "Could not load the lunar base scene. Check the Godot Output panel."
		push_error("Unable to load lunar base scene: %s" % MOON_SCENE_PATH)
		return

	var scene_error := get_tree().change_scene_to_packed(moon_scene)
	if scene_error != OK:
		status_label.text = "MOON SCENE CHANGE FAILED"
		readiness_label.text = "Could not enter the lunar base. Check the Godot Output panel."
		push_error("Unable to change to lunar base scene: %s" % error_string(scene_error))


func _set_rocket_progress(value: float) -> void:
	rocket_preview.launch_progress = value
	rocket_preview.queue_redraw()


func _complete_launch() -> void:
	launch_tween = null
	launch_in_progress = false
	mission_complete = true
	rocket_preview.flames_active = false
	rocket_preview.queue_redraw()

	resources["Fuel"] = maxf(float(resources["Fuel"]) - 70.0, 0.0)
	resources["Power"] = maxf(float(resources["Power"]) - 30.0, 0.0)
	resources["Oxygen"] = maxf(float(resources["Oxygen"]) - 15.0, 0.0)
	resources["Thermal Load"] = minf(float(resources["Thermal Load"]) + 15.0, 100.0)

	status_label.text = "FLIGHT CONFIRMED"
	countdown_label.text = "Transfer confirmed. Crew cleared for lunar surface operations."
	_refresh_interface()


func _on_reset_pressed() -> void:
	# Invalidate any countdown still awaiting a timer and stop its animation.
	launch_sequence_id += 1
	if launch_tween != null:
		launch_tween.kill()
		launch_tween = null

	launch_in_progress = false
	mission_complete = false
	resources = INITIAL_RESOURCES.duplicate()
	service_charges = 2
	rocket_preview.launch_progress = 0.0
	rocket_preview.flames_active = false
	rocket_preview.queue_redraw()

	for system in SYSTEMS:
		subsystem_ready[system.name] = false
		system_status_labels[system.name].text = "NOT CHECKED"
		system_status_labels[system.name].add_theme_color_override("font_color", Color("#d59b62"))
		system_buttons[system.name].text = "RUN CHECK"
		system_buttons[system.name].disabled = false

	status_label.text = "VEHICLE SYSTEMS RESET"
	countdown_label.text = "Awaiting launch authorization."
	_refresh_interface()

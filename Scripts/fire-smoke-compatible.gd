class_name FireSmokeCompatible
extends Node2D

@onready var tmp_display_viewport: SubViewport = $TmpDisplayViewport

@onready var particles_to_grid_texture_rect: TextureRect = $ParticlesToGridViewport/TextureRect
@onready var velocity_sprite: Sprite2D = $VelocityViewport/Sprite2D
@onready var splash_mask_sprite: Sprite2D = $SplashMaskViewport/Sprite2D
@onready var fire_fuel_smoke_density_splash_sprite: Sprite2D = $FireFuelSmokeDensitySplashViewport/Sprite2D
@onready var fire_smoke_temperature_sprite: Sprite2D = $FireSmokeTemperatureViewport/Sprite2D
@onready var fire_fuel_burn_sprite: Sprite2D = $FireFuelBurnViewport/Sprite2D
@onready var fire_temperature_cool_sprite: Sprite2D = $FireTemperatureCoolViewport/Sprite2D
@onready var fire_temperature_extinguish_sprite: Sprite2D = $FireTemperatureExtinguishViewport/Sprite2D
@onready var extinguish_mask_sprite: Sprite2D = $ExtinguishMaskViewport/Sprite2D
@onready var velocity_forces_sprite: Sprite2D = $VelocityForcesViewport/Sprite2D
@onready var pressure_init_sprite: Sprite2D = $PressureInitViewport/Sprite2D
@onready var velocity_div_free_sprite: Sprite2D = $VelocityDivFreeViewport/Sprite2D
@onready var fire_smoke_temperature_advect_sprite: Sprite2D = $FireSmokeTemperatureAdvectViewport/Sprite2D
@onready var fire_fuel_smoke_density_advect_sprite: Sprite2D = $FireFuelSmokeDensityAdvectViewport/Sprite2D
@onready var plancks_law_sprite: Sprite2D = $PlancksLawViewport/Sprite2D
@onready var smoke_vis_sprite: Sprite2D = $SmokeVisViewport/Sprite2D
@onready var grid_to_particles_texture_rect: TextureRect = $GridToParticlesViewport/TextureRect

@onready var particles_to_grid_viewport: SubViewport = $ParticlesToGridViewport
@onready var obstacles_raw_viewport: SubViewport = $ObstaclesRawViewport
@onready var obstacles_edges_viewport: SubViewport = $ObstaclesEdgesViewport
@onready var splash_mask_helper_viewport: SubViewport = $SplashMaskHelperViewport
@onready var extinguish_mask_helper_viewport: SubViewport = $ExtinguishMaskHelperViewport
@onready var divergence_viewport: SubViewport = $DivergenceViewport
@onready var pressure_init_viewport: SubViewport = $PressureInitViewport
@onready var velocity_div_free_viewport: SubViewport = $VelocityDivFreeViewport
@onready var fire_smoke_temperature_advect_viewport: SubViewport = $FireSmokeTemperatureAdvectViewport
@onready var fire_fuel_smoke_density_advect_viewport: SubViewport = $FireFuelSmokeDensityAdvectViewport
@onready var plancks_law_viewport: SubViewport = $PlancksLawViewport
@onready var smoke_vis_viewport: SubViewport = $SmokeVisViewport
@onready var fire_smoke_together_viewport: SubViewport = $FireSmokeTogetherViewport
@onready var grid_to_particles_viewport: SubViewport = $GridToParticlesViewport

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var display: Sprite2D = $Display
@onready var top_margin_container: MarginContainer = $CanvasLayer/VBoxContainer/TopMarginContainer
@onready var fire_bottom_margin_container: MarginContainer = $CanvasLayer/VBoxContainer/FireBottomMarginContainer
@onready var smoke_bottom_margin_container: MarginContainer = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer
@onready var mode_label: Label = $CanvasLayer/VBoxContainer/TopMarginContainer/HBoxContainer/ModeLabel
@onready var label: Label = $CanvasLayer/VBoxContainer/TopMarginContainer/HBoxContainer/Label
@onready var fps_label: Label = $CanvasLayer/VBoxContainer/TopMarginContainer/HBoxContainer/FPSLabel

@onready var fire_disturbance_radius_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireDisturbanceRadiusHBoxContainer/FireDisturbanceRadiusValue
@onready var fire_disturbance_strength_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireDisturbanceStrengthHBoxContainer/FireDisturbanceStrengthValue
@onready var fire_splash_radius_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireSplashRadiusHBoxContainer/FireSplashRadiusValue
@onready var fire_splash_strength_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireSplashStrengthHBoxContainer/FireSplashStrengthValue
@onready var fire_fuel_dissipation_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireFuelDissipationHBoxContainer/FireFuelDissipationValue
@onready var fire_fuel_burn_strength_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireFuelBurnStrengthHBoxContainer/FireFuelBurnStrengthValue
@onready var fire_temperature_dissipation_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireTemperatureDissipationHBoxContainer/FireTemperatureDissipationValue
@onready var fire_temperature_cool_exponent_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireTemperatureCoolExponentHBoxContainer/FireTemperatureCoolExponentValue
@onready var fire_vorticity_scale_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireVorticityScaleHBoxContainer/FireVorticityScaleValue
@onready var fire_buoyancy_strength_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireBuoyancyStrengthHBoxContainer/FireBuoyancyStrengthValue
@onready var fire_vel_abs_val_limit_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireVelAbsValLimitHBoxContainer/FireVelAbsValLimitValue
@onready var fire_water_heating_speed_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireWaterHeatingSpeedHBoxContainer/FireWaterHeatingSpeedValue
@onready var fire_water_vaporization_speed_value: Label = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireWaterVaporizationSpeedHBoxContainer/FireWaterVaporizationSpeedValue

@onready var fire_disturbance_radius_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireDisturbanceRadiusHBoxContainer/FireDisturbanceRadiusMarginContainer/FireDisturbanceRadiusHSlider
@onready var fire_disturbance_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireDisturbanceStrengthHBoxContainer/FireDisturbanceStrengthMarginContainer/FireDisturbanceStrengthHSlider
@onready var fire_splash_radius_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireSplashRadiusHBoxContainer/FireSplashRadiusMarginContainer/FireSplashRadiusHSlider
@onready var fire_splash_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireSplashStrengthHBoxContainer/FireSplashStrengthMarginContainer/FireSplashStrengthHSlider
@onready var fire_fuel_dissipation_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireFuelDissipationHBoxContainer/FireFuelDissipationMarginContainer/FireFuelDissipationHSlider
@onready var fire_fuel_burn_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireFuelBurnStrengthHBoxContainer/FireFuelBurnStrengthMarginContainer/FireFuelBurnStrengthHSlider
@onready var fire_temperature_dissipation_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireTemperatureDissipationHBoxContainer/FireTemperatureDissipationMarginContainer/FireTemperatureDissipationHSlider
@onready var fire_temperature_cool_exponent_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireTemperatureCoolExponentHBoxContainer/FireTemperatureCoolExponentMarginContainer/FireTemperatureCoolExponentHSlider
@onready var fire_vorticity_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireVorticityScaleHBoxContainer/FireVorticityScaleMarginContainer/FireVorticityScaleHSlider
@onready var fire_buoyancy_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireBuoyancyStrengthHBoxContainer/FireBuoyancyStrengthMarginContainer/FireBuoyancyStrengthHSlider
@onready var fire_vel_abs_val_limit_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireVelAbsValLimitHBoxContainer/FireVelAbsValLimitMarginContainer/FireVelAbsValLimitHSlider
@onready var fire_water_heating_speed_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireWaterHeatingSpeedHBoxContainer/FireWaterHeatingSpeedMarginContainer/FireWaterHeatingSpeedHSlider
@onready var fire_water_vaporization_speed_h_slider: HSlider = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireWaterVaporizationSpeedHBoxContainer/FireWaterVaporizationSpeedMarginContainer/FireWaterVaporizationSpeedHSlider

@onready var fire_obstacle_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireObstacleToggleHBoxContainer/FireObstacleToggleMarginContainer/FireObstacleToggleCheckBox
@onready var fire_baked_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireColorPickerHBoxContainer/FireBakedToggleMarginContainer/FireBakedToggleHBoxContainer/FireBakedToggleCheckBox
@onready var fire_custom_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireColorPickerHBoxContainer/FireCustomToggleMarginContainer/FireCustomToggleHBoxContainer/FireCustomToggleCheckBox

@onready var fire_gradient_editor: GradientEditor = $CanvasLayer/VBoxContainer/FireBottomMarginContainer/FirePanelContainer/FireMarginContainer/FireVBoxContainer/FireColorPickerHBoxContainer/FireCustomToggleMarginContainer/FireCustomToggleHBoxContainer/FireGradientEditorMarginContainer/FireGradientEditor

@onready var smoke_disturbance_radius_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDisturbanceRadiusHBoxContainer/SmokeDisturbanceRadiusValue
@onready var smoke_disturbance_strength_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDisturbanceStrengthHBoxContainer/SmokeDisturbanceStrengthValue
@onready var smoke_density_and_heating_splash_radius_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDensityAndHeatingSplashRadiusHBoxContainer/SmokeDensityAndHeatingSplashRadiusValue
@onready var smoke_density_and_heating_splash_strength_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDensityAndHeatingSplashStrengthHBoxContainer/SmokeDensityAndHeatingSplashStrengthValue
@onready var smoke_cooling_splash_radius_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeCoolingSplashRadiusHBoxContainer/SmokeCoolingSplashRadiusValue
@onready var smoke_cooling_splash_strength_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeCoolingSplashStrengthHBoxContainer/SmokeCoolingSplashStrengthValue
@onready var smoke_density_dissipation_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDensityDissipationHBoxContainer/SmokeDensityDissipationValue
@onready var smoke_temperature_dissipation_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeTemperatureDissipationHBoxContainer/SmokeTemperatureDissipationValue
@onready var smoke_vorticity_scale_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVorticityScaleHBoxContainer/SmokeVorticityScaleValue
@onready var smoke_dense_down_force_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDenseDownForceHBoxContainer/SmokeDenseDownForceValue
@onready var smoke_hot_up_force_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeHotUpForceHBoxContainer/SmokeHotUpForceValue
@onready var smoke_vel_abs_val_limit_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVelAbsValLimitHBoxContainer/SmokeVelAbsValLimitValue
@onready var smoke_vapor_density_splash_strength_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVaporDensitySplashStrengthHBoxContainer/SmokeVaporDensitySplashStrengthValue
@onready var smoke_vapor_heating_splash_strength_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVaporHeatingSplashStrengthHBoxContainer/SmokeVaporHeatingSplashStrengthValue
@onready var smoke_min_albedo_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeMinAlbedoHBoxContainer/SmokeMinAlbedoValue
@onready var smoke_max_albedo_value: Label = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeMaxAlbedoHBoxContainer/SmokeMaxAlbedoValue

@onready var smoke_disturbance_radius_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDisturbanceRadiusHBoxContainer/SmokeDisturbanceRadiusMarginContainer/SmokeDisturbanceRadiusHSlider
@onready var smoke_disturbance_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDisturbanceStrengthHBoxContainer/SmokeDisturbanceStrengthMarginContainer/SmokeDisturbanceStrengthHSlider
@onready var smoke_density_and_heating_splash_radius_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDensityAndHeatingSplashRadiusHBoxContainer/SmokeDensityAndHeatingSplashRadiusMarginContainer/SmokeDensityAndHeatingSplashRadiusHSlider
@onready var smoke_density_and_heating_splash_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDensityAndHeatingSplashStrengthHBoxContainer/SmokeDensityAndHeatingSplashStrengthMarginContainer/SmokeDensityAndHeatingSplashStrengthHSlider
@onready var smoke_cooling_splash_radius_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeCoolingSplashRadiusHBoxContainer/SmokeCoolingSplashRadiusMarginContainer/SmokeCoolingSplashRadiusHSlider
@onready var smoke_cooling_splash_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeCoolingSplashStrengthHBoxContainer/SmokeCoolingSplashStrengthMarginContainer/SmokeCoolingSplashStrengthHSlider
@onready var smoke_density_dissipation_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDensityDissipationHBoxContainer/SmokeDensityDissipationMarginContainer/SmokeDensityDissipationHSlider
@onready var smoke_temperature_dissipation_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeTemperatureDissipationHBoxContainer/SmokeTemperatureDissipationMarginContainer/SmokeTemperatureDissipationHSlider
@onready var smoke_vorticity_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVorticityScaleHBoxContainer/SmokeVorticityScaleMarginContainer/SmokeVorticityScaleHSlider
@onready var smoke_dense_down_force_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeDenseDownForceHBoxContainer/SmokeDenseDownForceMarginContainer/SmokeDenseDownForceHSlider
@onready var smoke_hot_up_force_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeHotUpForceHBoxContainer/SmokeHotUpForceMarginContainer/SmokeHotUpForceHSlider
@onready var smoke_vel_abs_val_limit_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVelAbsValLimitHBoxContainer/SmokeVelAbsValLimitMarginContainer/SmokeVelAbsValLimitHSlider
@onready var smoke_vapor_density_splash_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVaporDensitySplashStrengthHBoxContainer/SmokeVaporDensitySplashStrengthMarginContainer/SmokeVaporDensitySplashStrengthHSlider
@onready var smoke_vapor_heating_splash_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeVaporHeatingSplashStrengthHBoxContainer/SmokeVaporHeatingSplashStrengthMarginContainer/SmokeVaporHeatingSplashStrengthHSlider
@onready var smoke_min_albedo_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeMinAlbedoHBoxContainer/SmokeMinAlbedoMarginContainer/SmokeMinAlbedoHSlider
@onready var smoke_max_albedo_h_slider: HSlider = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeMaxAlbedoHBoxContainer/SmokeMaxAlbedoMarginContainer/SmokeMaxAlbedoHSlider

@onready var smoke_obstacle_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeObstacleToggleHBoxContainer/SmokeObstacleToggleMarginContainer/SmokeObstacleToggleCheckBox
@onready var smoke_grayscale_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeColorPickerHBoxContainer/SmokeGrayscaleToggleMarginContainer/SmokeGrayscaleToggleHBoxContainer/SmokeGrayscaleToggleCheckBox
@onready var smoke_custom_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeColorPickerHBoxContainer/SmokeCustomToggleMarginContainer/SmokeCustomToggleHBoxContainer/SmokeCustomToggleCheckBox

@onready var smoke_custom_color_picker_button: ColorPickerButton = $CanvasLayer/VBoxContainer/SmokeBottomMarginContainer/SmokePanelContainer/SmokeMarginContainer/SmokeVBoxContainer/SmokeColorPickerHBoxContainer/SmokeCustomToggleMarginContainer/SmokeCustomToggleHBoxContainer/SmokeCustomColorPickerButton

@onready var obstacle_polygon_2d: Polygon2D = $ObstaclesRawViewport/Polygon2D

@export var pressure_jacobi_iterations: int = 25
@export var viewport_size: Vector2i = Vector2i(1152, 648)
@export var pg_gp_size: Vector2i = Vector2i(256, 256)
@export var fire_temp_ambient: float = 300.0
@export var fire_temp_max: float = 2000.0
@export var fire_temp_burn: float = 2000.0
@export var fire_temp_extinguish: float = 300.0
@export var smoke_temp_ambient: float = 300.0
@export var smoke_temp_max: float = 500.0
@export var particle_temp_ambient: float = 300.0
@export var particle_temp_max: float = 373.0

var empty_shader: Shader = load("res://Fragment Shaders/empty.gdshader")
var clamp_shader: Shader = load("res://Fragment Shaders/clamp.gdshader")
var pressure_jacobi_n_shader: Shader = load("res://Fragment Shaders/pressure_jacobi_n.gdshader")
var pressure_boundary_n_shader: Shader = load("res://Fragment Shaders/pressure_constant_boundary_n.gdshader")

var pressure_init_viewport_idx: int = 13    # child index of the root node, counted from the top
var pressure_boundary_last: SubViewport = null

var left_button_clicked: bool = false
var right_button_clicked: bool = false
var middle_button_clicked: bool = false
var shift_key_pressed: bool = false

var prev_mouse_pos: Vector2 = Vector2(-INF, -INF)
var curr_mouse_pos: Vector2 = Vector2(-INF, -INF)

var disturbance_direction: Vector2 = Vector2(-INF, -INF)

var curr_textures: Array[ViewportTexture]    # textures to display in the simulation
var curr_labels: Array[String]    # labels visible in the top-left corner
var curr_shaders: Array[Shader]    # shaders used to somehow visualize float values stored in textures (empty shader or clamp shader)
var curr_use_r: Array[bool]    # whether to remap the r channel or not in the clamp shaders
var curr_use_g: Array[bool]    # whether to remap the g channel or not in the clamp shaders
var curr_use_b: Array[bool]    # whether to remap the b channel or not in the clamp shaders
var curr_use_a: Array[bool]    # whether to remap the a channel or not in the clamp shaders
var curr_max_values: Array[float]    # maximum possible values visualized by their respective clamp shaders, -1.0 in case of empty shader
var curr_min_values: Array[float]    # minimum possible values visualized by their respective clamp shaders, -1.0 in case of empty shader

var fire_plus_smoke_textures: Array[ViewportTexture]
var fire_plus_smoke_labels: Array[String]
var fire_plus_smoke_shaders: Array[Shader]
var fire_plus_smoke_use_r: Array[bool]
var fire_plus_smoke_use_g: Array[bool]
var fire_plus_smoke_use_b: Array[bool]
var fire_plus_smoke_use_a: Array[bool]
var fire_plus_smoke_max_values: Array[float]
var fire_plus_smoke_min_values: Array[float]

var fire_textures: Array[ViewportTexture]
var fire_labels: Array[String]
var fire_shaders: Array[Shader]
var fire_use_r: Array[bool]
var fire_use_g: Array[bool]
var fire_use_b: Array[bool]
var fire_use_a: Array[bool]
var fire_max_values: Array[float]
var fire_min_values: Array[float]

var smoke_textures: Array[ViewportTexture]
var smoke_labels: Array[String]
var smoke_shaders: Array[Shader]
var smoke_use_r: Array[bool]
var smoke_use_g: Array[bool]
var smoke_use_b: Array[bool]
var smoke_use_a: Array[bool]
var smoke_max_values: Array[float]
var smoke_min_values: Array[float]

var fire_plus_smoke_mode_label_text: String = "[Fire + Smoke]"
var fire_mode_label_text: String = "[Fire]"
var smoke_mode_label_text: String = "[Smoke]"

# if (fire == true) and (smoke == true) -> [Fire + Smoke]
# if (fire == true) and (smoke == false) -> [Fire]
# if (fire == false) and (smoke == true) -> [Smoke]
# if (fire == false) and (smoke == false) -> error, this case should never happen
var fire_interaction_mode: bool
var smoke_interaction_mode: bool

var curr_mode_label_text: String = ""
var curr_display_index: int = -1
var curr_params_panel: MarginContainer = null

var fire_default_disturbance_radius: float = 0.005
var fire_default_disturbance_strength: float = 2.5
var fire_default_splash_radius: float = 0.1
var fire_default_splash_strength: float = 10.0
var fire_default_fuel_dissipation: float = 0.925
var fire_default_fuel_burn_strength: float = 0.01
var fire_default_temperature_dissipation: float = 5000.0
var fire_default_temperature_cool_exponent: float = 1.0
var fire_default_vorticity_scale: float = 5.0
var fire_default_buoyancy_strength: float = 10.0
var fire_default_vel_abs_val_limit: float = 1.0
var fire_default_water_heating_speed: float = 100.0
var fire_default_water_vaporization_speed: float = 250.0

var fire_default_obstacle_toggled_on: bool = false
var fire_default_baked_color_toggled_on: bool = true
var fire_default_custom_color_toggled_on: bool = false

var fire_curr_disturbance_radius: float = fire_default_disturbance_radius
var fire_curr_disturbance_strength: float = fire_default_disturbance_strength
var fire_curr_splash_radius: float = fire_default_splash_radius
var fire_curr_splash_strength: float = fire_default_splash_strength
var fire_curr_fuel_dissipation: float = fire_default_fuel_dissipation
var fire_curr_fuel_burn_strength: float = fire_default_fuel_burn_strength
var fire_curr_temperature_dissipation: float = fire_default_temperature_dissipation
var fire_curr_temperature_cool_exponent: float = fire_default_temperature_cool_exponent
var fire_curr_vorticity_scale: float = fire_default_vorticity_scale
var fire_curr_buoyancy_strength: float = fire_default_buoyancy_strength
var fire_curr_vel_abs_val_limit: float = fire_default_vel_abs_val_limit
var fire_curr_water_heating_speed = fire_default_water_heating_speed
var fire_curr_water_vaporization_speed = fire_default_water_vaporization_speed

var fire_curr_obstacle_toggled_on: bool = fire_default_obstacle_toggled_on
var fire_curr_baked_color_toggled_on: bool = fire_default_baked_color_toggled_on
var fire_curr_custom_color_toggled_on: bool = fire_default_custom_color_toggled_on

var smoke_default_disturbance_radius: float = 0.005
var smoke_default_disturbance_strength: float = 2.5
var smoke_default_density_and_heating_splash_radius: float = 0.05
var smoke_default_density_and_heating_splash_strength: float = 10.0
var smoke_default_cooling_splash_radius: float = 0.2
var smoke_default_cooling_splash_strength: float = 10.0
var smoke_default_density_dissipation: float = 0.05
var smoke_default_temperature_dissipation: float = 0.05
var smoke_default_vorticity_scale: float = 5.0
var smoke_default_dense_down_force: float = 0.1
var smoke_default_hot_up_force: float = 2.0
var smoke_default_vel_abs_val_limit: float = 1.0
var smoke_default_vapor_density_splash_strength: float = 10.0
var smoke_default_vapor_heating_splash_strength: float = 10.0
var smoke_default_min_albedo: float = 0.0
var smoke_default_max_albedo: float = 0.1

var smoke_default_obstacle_toggled_on: bool = false
var smoke_default_grayscale_color_toggled_on: bool = true
var smoke_default_custom_color_toggled_on: bool = false

var smoke_default_custom_color: Color = Color.WHITE

var smoke_curr_disturbance_radius: float = smoke_default_disturbance_radius
var smoke_curr_disturbance_strength: float = smoke_default_disturbance_strength
var smoke_curr_density_and_heating_splash_radius: float = smoke_default_density_and_heating_splash_radius
var smoke_curr_density_and_heating_splash_strength: float = smoke_default_density_and_heating_splash_strength
var smoke_curr_cooling_splash_radius: float = smoke_default_cooling_splash_radius
var smoke_curr_cooling_splash_strength: float = smoke_default_cooling_splash_strength
var smoke_curr_density_dissipation: float = smoke_default_density_dissipation
var smoke_curr_temperature_dissipation: float = smoke_default_temperature_dissipation
var smoke_curr_vorticity_scale: float = smoke_default_vorticity_scale
var smoke_curr_dense_down_force: float = smoke_default_dense_down_force
var smoke_curr_hot_up_force: float = smoke_default_hot_up_force
var smoke_curr_vel_abs_val_limit: float = smoke_default_vel_abs_val_limit
var smoke_curr_vapor_density_splash_strength: float = smoke_default_vapor_density_splash_strength
var smoke_curr_vapor_heating_splash_strength: float = smoke_default_vapor_heating_splash_strength
var smoke_curr_min_albedo: float = smoke_default_min_albedo
var smoke_curr_max_albedo: float = smoke_default_max_albedo

var smoke_curr_obstacle_toggled_on: bool = smoke_default_obstacle_toggled_on
var smoke_curr_grayscale_color_toggled_on: bool = smoke_default_grayscale_color_toggled_on
var smoke_curr_custom_color_toggled_on: bool = smoke_default_custom_color_toggled_on

var smoke_curr_custom_color: Color = smoke_default_custom_color

var slider_callbacks_dict: Dictionary = {}
var toggle_callbacks_dict: Dictionary = {}
var color_picker_button_callbacks_dict: Dictionary = {}

var particle_mass: float
var particle_specific_heat_capacity: float
var particle_specific_latent_heat_vaporization: float
var particle_heating_energy_cost: float
var particle_vaporization_energy_cost: float
var particle_total_energy_cost: float

func fire_smoke_ready() -> void:
	Engine.max_fps = 120
	
	assert(pressure_jacobi_iterations > 0, "At least one iteration is required for pressure solving")
	
	for vp in get_tree().get_nodes_in_group("ViewportPipeline"):
		# this line affects only the viewports created manually, not the ones created in this script
		vp.size = viewport_size
	
	particles_to_grid_viewport.size = pg_gp_size
	particles_to_grid_texture_rect.size = pg_gp_size
	grid_to_particles_viewport.size = pg_gp_size
	grid_to_particles_texture_rect.size = pg_gp_size
	
	#set_up_pressure_jacobi()
	set_up_pressure_jacobi_faster()
	
	# after ensuring correct initialization of some important textures, we connect them to the rest of the viewport pipeline
	velocity_sprite.texture = velocity_div_free_viewport.get_texture()
	splash_mask_sprite.texture = splash_mask_helper_viewport.get_texture()
	fire_fuel_smoke_density_splash_sprite.texture = fire_fuel_smoke_density_advect_viewport.get_texture()
	fire_smoke_temperature_sprite.texture = fire_smoke_temperature_advect_viewport.get_texture()
	extinguish_mask_sprite.texture = extinguish_mask_helper_viewport.get_texture()
	pressure_init_sprite.texture = pressure_boundary_last.get_texture()
	velocity_div_free_sprite.texture = pressure_boundary_last.get_texture()
	
	particles_to_grid_texture_rect.material.set("shader_parameter/u_particle_temp_ambient", particle_temp_ambient)
	particles_to_grid_texture_rect.material.set("shader_parameter/u_particle_temp_max", particle_temp_max)
	fire_fuel_smoke_density_splash_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_init_state", false)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_fire_temp_burn", fire_temp_burn)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_smoke_temp_ambient", smoke_temp_ambient)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_smoke_temp_max", smoke_temp_max)
	fire_temperature_cool_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	fire_temperature_cool_sprite.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_particle_temp_ambient", particle_temp_ambient)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_particle_temp_max", particle_temp_max)
	fire_temperature_extinguish_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	fire_temperature_extinguish_sprite.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	extinguish_mask_sprite.material.set("shader_parameter/u_fire_temp_extinguish", fire_temp_extinguish)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_temp_ambient", smoke_temp_ambient)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_temp_max", smoke_temp_max)
	fire_smoke_temperature_advect_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	fire_smoke_temperature_advect_sprite.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	fire_smoke_temperature_advect_sprite.material.set("shader_parameter/u_smoke_temp_ambient", smoke_temp_ambient)
	fire_smoke_temperature_advect_sprite.material.set("shader_parameter/u_smoke_temp_max", smoke_temp_max)
	plancks_law_sprite.material.set("shader_parameter/u_custom_fire_temp", fire_gradient_editor.gradient_texture)
	plancks_law_sprite.material.set("shader_parameter/u_fire_temp_ambient", fire_temp_ambient)
	plancks_law_sprite.material.set("shader_parameter/u_fire_temp_max", fire_temp_max)
	
	top_margin_container.visible = true
	fire_bottom_margin_container.visible = false
	smoke_bottom_margin_container.visible = false
	
	fire_interaction_mode = true
	smoke_interaction_mode = true
	
	init_display_configs()
	set_curr_display_config()
	
	init_display()
	set_display()
	
	init_mode_label()
	set_mode_label()
	
	init_params_panel()
	set_params_panel()
	
	init_slider_callbacks()
	init_toggle_callbacks()
	init_color_picker_button_callbacks()
	
	for ps in get_tree().get_nodes_in_group("ParamSlider"):
		if ps is HSlider:
			ps.value_changed.connect(Callable(self, "_on_slidervalue_changed").bind(ps.name))
	
	for pt in get_tree().get_nodes_in_group("ParamToggle"):
		if pt is CheckBox:
			pt.toggled.connect(Callable(self, "_on_togglevalue_changed").bind(pt.name))
	
	for pcpb in get_tree().get_nodes_in_group("ParamColorPickerButton"):
		if pcpb is ColorPickerButton:
			pcpb.color_changed.connect(Callable(self, "_on_colorpickerbuttonvalue_changed").bind(pcpb.name))
	
	reset_params()

func fire_smoke_process(delta: float) -> void:
	velocity_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_fuel_smoke_density_splash_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_fuel_burn_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_temperature_cool_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_temperature_extinguish_sprite.material.set("shader_parameter/u_timestep", delta)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_timestep", delta)
	velocity_forces_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_smoke_temperature_advect_sprite.material.set("shader_parameter/u_timestep", delta)
	fire_fuel_smoke_density_advect_sprite.material.set("shader_parameter/u_timestep", delta)
	
	grid_to_particles_texture_rect.material.set("shader_parameter/u_water_heating_speed", fire_curr_water_heating_speed)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_water_vaporization_speed", fire_curr_water_vaporization_speed)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_disturbance_radius", fire_curr_disturbance_radius)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_disturbance_strength", fire_curr_disturbance_strength)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_vorticity_scale", fire_curr_vorticity_scale)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_beta", fire_curr_buoyancy_strength)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_disturbance_radius", smoke_curr_disturbance_radius)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_disturbance_strength", smoke_curr_disturbance_strength)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_vorticity_scale", smoke_curr_vorticity_scale)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_alpha", smoke_curr_dense_down_force)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_beta", smoke_curr_hot_up_force)
	splash_mask_sprite.material.set("shader_parameter/u_fuel_splash_radius", fire_curr_splash_radius)
	splash_mask_sprite.material.set("shader_parameter/u_fuel_splash_strength", fire_curr_splash_strength)
	splash_mask_sprite.material.set("shader_parameter/u_density_heating_splash_radius", smoke_curr_density_and_heating_splash_radius)
	splash_mask_sprite.material.set("shader_parameter/u_density_heating_splash_strength", smoke_curr_density_and_heating_splash_strength)
	splash_mask_sprite.material.set("shader_parameter/u_cooling_splash_radius", smoke_curr_cooling_splash_radius)
	splash_mask_sprite.material.set("shader_parameter/u_cooling_splash_strength", smoke_curr_cooling_splash_strength)
	fire_fuel_smoke_density_splash_sprite.material.set("shader_parameter/u_vapor_density_splash_strength", smoke_curr_vapor_density_splash_strength)
	fire_fuel_smoke_density_splash_sprite.material.set("shader_parameter/u_density_dissipation_rate", smoke_curr_density_dissipation)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_smoke_temp_dissipation_rate", smoke_curr_temperature_dissipation)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_vapor_heating_splash_strength", smoke_curr_vapor_heating_splash_strength)
	fire_fuel_burn_sprite.material.set("shader_parameter/u_gamma_fuel", fire_curr_fuel_dissipation)
	fire_fuel_burn_sprite.material.set("shader_parameter/u_burn_strength", fire_curr_fuel_burn_strength)
	fire_temperature_cool_sprite.material.set("shader_parameter/u_sigma_cool", fire_curr_temperature_dissipation)
	fire_temperature_cool_sprite.material.set("shader_parameter/u_exponent", fire_curr_temperature_cool_exponent)
	velocity_div_free_sprite.material.set("shader_parameter/fire_vel_abs_val_limit", fire_curr_vel_abs_val_limit)
	velocity_div_free_sprite.material.set("shader_parameter/smoke_vel_abs_val_limit", smoke_curr_vel_abs_val_limit)
	plancks_law_sprite.material.set("shader_parameter/u_use_custom_fire_temp", int(fire_curr_custom_color_toggled_on))
	smoke_vis_sprite.material.set("shader_parameter/u_use_custom_density_color", int(smoke_curr_custom_color_toggled_on))
	smoke_vis_sprite.material.set("shader_parameter/u_density_color", Vector3(smoke_curr_custom_color.r, smoke_curr_custom_color.g, smoke_curr_custom_color.b))
	smoke_vis_sprite.material.set("shader_parameter/u_min_albedo", Vector3(smoke_curr_min_albedo, smoke_curr_min_albedo, smoke_curr_min_albedo))
	smoke_vis_sprite.material.set("shader_parameter/u_max_albedo", Vector3(smoke_curr_max_albedo, smoke_curr_max_albedo, smoke_curr_max_albedo))
	
	if !curr_params_panel.visible:
		prev_mouse_pos = curr_mouse_pos
		curr_mouse_pos = get_global_mouse_position()
		disturbance_direction = (curr_mouse_pos - prev_mouse_pos).normalized()
		
		if fire_interaction_mode:
			
			if right_button_clicked:
				disturb_fire_velocity(screen_to_uv(display), disturbance_direction)
			else:
				stop_disturbing_fire_velocity()
			
			if left_button_clicked:
				splash_fire_fuel(screen_to_uv(display), !shift_key_pressed)
			else:
				stop_splashing_fire_fuel()
		
		if smoke_interaction_mode:
			
			if right_button_clicked:
				disturb_smoke_velocity(screen_to_uv(display), disturbance_direction)
			else:
				stop_disturbing_smoke_velocity()
			
			if left_button_clicked:
				splash_smoke_density_heat_smoke_temperature(screen_to_uv(display), !shift_key_pressed)
			else:
				stop_splashing_smoke_density_heating_smoke_temperature()
			
			if middle_button_clicked:
				cool_smoke_temperature(screen_to_uv(display), !shift_key_pressed)
			else:
				stop_cooling_smoke_temperature()
	
	fps_label.text = str(Engine.get_frames_per_second()) + " FPS"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			left_button_clicked = true
		else:
			left_button_clicked = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			right_button_clicked = true
		else:
			right_button_clicked = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			middle_button_clicked = true
		else:
			middle_button_clicked = false
	elif event is InputEventKey and event.keycode == KEY_SHIFT:
		if event.pressed:
			shift_key_pressed = true
		else:
			shift_key_pressed = false
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_RIGHT:
			curr_display_index = (curr_display_index + 1) % curr_textures.size()
			set_display()
		elif event.keycode == KEY_LEFT:
			curr_display_index = (curr_display_index - 1) % curr_textures.size()
			set_display()
		elif event.keycode == KEY_Z:
			if curr_params_panel.visible and fire_interaction_mode and smoke_interaction_mode:
				curr_params_panel.visible = false
				swap_curr_params_panel()
				curr_params_panel.visible = true
		elif event.keycode == KEY_T:
			curr_params_panel.visible = !curr_params_panel.visible
		elif event.keycode == KEY_H:
			top_margin_container.visible = !top_margin_container.visible
		elif event.keycode == KEY_1:
			fire_interaction_mode = true
			smoke_interaction_mode = true
			set_curr_display_config()
			set_display()
			set_mode_label()
			set_params_panel()
		elif event.keycode == KEY_2:
			fire_interaction_mode = true
			smoke_interaction_mode = false
			set_curr_display_config()
			set_display()
			set_mode_label()
			set_params_panel()
		elif event.keycode == KEY_3:
			fire_interaction_mode = false
			smoke_interaction_mode = true
			set_curr_display_config()
			set_display()
			set_mode_label()
			set_params_panel()
		elif event.keycode == KEY_R:
			reset_params()
		elif event.keycode == KEY_P:
			print()
			for _i in self.get_children():
				print(_i)
			print()

func _on_slidervalue_changed(new_value: float, slider_name: String) -> void:
	if slider_callbacks_dict.has(slider_name):
		slider_callbacks_dict[slider_name].call(new_value)

func _on_togglevalue_changed(toggled_on: bool, toggle_name: String) -> void:
	if toggle_callbacks_dict.has(toggle_name):
		toggle_callbacks_dict[toggle_name].call(toggled_on)

func _on_colorpickerbuttonvalue_changed(new_color: Color, color_picker_button_name: String) -> void:
	if color_picker_button_callbacks_dict.has(color_picker_button_name):
		color_picker_button_callbacks_dict[color_picker_button_name].call(new_color)

func init_slider_callbacks() -> void:
	# for each slider we define its corresponding callable
	# callables are stored in a dictionary
	# the keys are the names of the sliders
	
	slider_callbacks_dict["FireDisturbanceRadiusHSlider"] = func(new_value: float) -> void:
		fire_disturbance_radius_value.text = str(new_value)
		fire_disturbance_radius_h_slider.value = new_value
		fire_curr_disturbance_radius = new_value
	
	slider_callbacks_dict["FireDisturbanceStrengthHSlider"] = func(new_value: float) -> void:
		fire_disturbance_strength_value.text = str(new_value)
		fire_disturbance_strength_h_slider.value = new_value
		fire_curr_disturbance_strength = new_value
	
	slider_callbacks_dict["FireSplashRadiusHSlider"] = func(new_value: float) -> void:
		fire_splash_radius_value.text = str(new_value)
		fire_splash_radius_h_slider.value = new_value
		fire_curr_splash_radius = new_value
	
	slider_callbacks_dict["FireSplashStrengthHSlider"] = func(new_value: float) -> void:
		fire_splash_strength_value.text = str(new_value)
		fire_splash_strength_h_slider.value = new_value
		fire_curr_splash_strength = new_value
	
	slider_callbacks_dict["FireFuelDissipationHSlider"] = func(new_value: float) -> void:
		fire_fuel_dissipation_value.text = str(new_value)
		fire_fuel_dissipation_h_slider.value = new_value
		fire_curr_fuel_dissipation = new_value
	
	slider_callbacks_dict["FireFuelBurnStrengthHSlider"] = func(new_value: float) -> void:
		fire_fuel_burn_strength_value.text = str(new_value)
		fire_fuel_burn_strength_h_slider.value = new_value
		fire_curr_fuel_burn_strength = new_value
	
	slider_callbacks_dict["FireTemperatureDissipationHSlider"] = func(new_value: float) -> void:
		fire_temperature_dissipation_value.text = str(new_value)
		fire_temperature_dissipation_h_slider.value = new_value
		fire_curr_temperature_dissipation = new_value
	
	slider_callbacks_dict["FireTemperatureCoolExponentHSlider"] = func(new_value: float) -> void:
		fire_temperature_cool_exponent_value.text = str(new_value)
		fire_temperature_cool_exponent_h_slider.value = new_value
		fire_curr_temperature_cool_exponent = new_value
	
	slider_callbacks_dict["FireVorticityScaleHSlider"] = func(new_value: float) -> void:
		fire_vorticity_scale_value.text = str(new_value)
		fire_vorticity_scale_h_slider.value = new_value
		fire_curr_vorticity_scale = new_value
	
	slider_callbacks_dict["FireBuoyancyStrengthHSlider"] = func(new_value: float) -> void:
		fire_buoyancy_strength_value.text = str(new_value)
		fire_buoyancy_strength_h_slider.value = new_value
		fire_curr_buoyancy_strength = new_value
	
	slider_callbacks_dict["FireVelAbsValLimitHSlider"] = func(new_value: float) -> void:
		fire_vel_abs_val_limit_value.text = str(new_value)
		fire_vel_abs_val_limit_h_slider.value = new_value
		fire_curr_vel_abs_val_limit = new_value
	
	slider_callbacks_dict["FireWaterHeatingSpeedHSlider"] = func(new_value: float) -> void:
		fire_water_heating_speed_value.text = str(new_value)
		fire_water_heating_speed_h_slider.value = new_value
		fire_curr_water_heating_speed = new_value
	
	slider_callbacks_dict["FireWaterVaporizationSpeedHSlider"] = func(new_value: float) -> void:
		fire_water_vaporization_speed_value.text = str(new_value)
		fire_water_vaporization_speed_h_slider.value = new_value
		fire_curr_water_vaporization_speed = new_value
	
	slider_callbacks_dict["SmokeDisturbanceRadiusHSlider"] = func(new_value: float) -> void:
		smoke_disturbance_radius_value.text = str(new_value)
		smoke_disturbance_radius_h_slider.value = new_value
		smoke_curr_disturbance_radius = new_value
	
	slider_callbacks_dict["SmokeDisturbanceStrengthHSlider"] = func(new_value: float) -> void:
		smoke_disturbance_strength_value.text = str(new_value)
		smoke_disturbance_strength_h_slider.value = new_value
		smoke_curr_disturbance_strength = new_value
	
	slider_callbacks_dict["SmokeDensityAndHeatingSplashRadiusHSlider"] = func(new_value: float) -> void:
		smoke_density_and_heating_splash_radius_value.text = str(new_value)
		smoke_density_and_heating_splash_radius_h_slider.value = new_value
		smoke_curr_density_and_heating_splash_radius = new_value
	
	slider_callbacks_dict["SmokeDensityAndHeatingSplashStrengthHSlider"] = func(new_value: float) -> void:
		smoke_density_and_heating_splash_strength_value.text = str(new_value)
		smoke_density_and_heating_splash_strength_h_slider.value = new_value
		smoke_curr_density_and_heating_splash_strength = new_value
	
	slider_callbacks_dict["SmokeCoolingSplashRadiusHSlider"] = func(new_value: float) -> void:
		smoke_cooling_splash_radius_value.text = str(new_value)
		smoke_cooling_splash_radius_h_slider.value = new_value
		smoke_curr_cooling_splash_radius = new_value
	
	slider_callbacks_dict["SmokeCoolingSplashStrengthHSlider"] = func(new_value: float) -> void:
		smoke_cooling_splash_strength_value.text = str(new_value)
		smoke_cooling_splash_strength_h_slider.value = new_value
		smoke_curr_cooling_splash_strength = new_value
	
	slider_callbacks_dict["SmokeDensityDissipationHSlider"] = func(new_value: float) -> void:
		smoke_density_dissipation_value.text = str(new_value)
		smoke_density_dissipation_h_slider.value = new_value
		smoke_curr_density_dissipation = new_value
	
	slider_callbacks_dict["SmokeTemperatureDissipationHSlider"] = func(new_value: float) -> void:
		smoke_temperature_dissipation_value.text = str(new_value)
		smoke_temperature_dissipation_h_slider.value = new_value
		smoke_curr_temperature_dissipation = new_value
	
	slider_callbacks_dict["SmokeVorticityScaleHSlider"] = func(new_value: float) -> void:
		smoke_vorticity_scale_value.text = str(new_value)
		smoke_vorticity_scale_h_slider.value = new_value
		smoke_curr_vorticity_scale = new_value
	
	slider_callbacks_dict["SmokeDenseDownForceHSlider"] = func(new_value: float) -> void:
		smoke_dense_down_force_value.text = str(new_value)
		smoke_dense_down_force_h_slider.value = new_value
		smoke_curr_dense_down_force = new_value
	
	slider_callbacks_dict["SmokeHotUpForceHSlider"] = func(new_value: float) -> void:
		smoke_hot_up_force_value.text = str(new_value)
		smoke_hot_up_force_h_slider.value = new_value
		smoke_curr_hot_up_force = new_value
	
	slider_callbacks_dict["SmokeVelAbsValLimitHSlider"] = func(new_value: float) -> void:
		smoke_vel_abs_val_limit_value.text = str(new_value)
		smoke_vel_abs_val_limit_h_slider.value = new_value
		smoke_curr_vel_abs_val_limit = new_value
	
	slider_callbacks_dict["SmokeVaporDensitySplashStrengthHSlider"] = func(new_value: float) -> void:
		smoke_vapor_density_splash_strength_value.text = str(new_value)
		smoke_vapor_density_splash_strength_h_slider.value = new_value
		smoke_curr_vapor_density_splash_strength = new_value
	
	slider_callbacks_dict["SmokeVaporHeatingSplashStrengthHSlider"] = func(new_value: float) -> void:
		smoke_vapor_heating_splash_strength_value.text = str(new_value)
		smoke_vapor_heating_splash_strength_h_slider.value = new_value
		smoke_curr_vapor_heating_splash_strength = new_value
	
	slider_callbacks_dict["SmokeMinAlbedoHSlider"] = func(new_value: float) -> void:
		var new_val: float = min(new_value, smoke_curr_max_albedo)
		smoke_min_albedo_value.text = str(new_val)
		smoke_min_albedo_h_slider.value = new_val
		smoke_curr_min_albedo = new_val
	
	slider_callbacks_dict["SmokeMaxAlbedoHSlider"] = func(new_value: float) -> void:
		var new_val: float = max(new_value, smoke_curr_min_albedo)
		smoke_max_albedo_value.text = str(new_val)
		smoke_max_albedo_h_slider.value = new_val
		smoke_curr_max_albedo = new_val

func init_toggle_callbacks() -> void:
	# for each toggle we define its corresponding callable
	# callables are stored in a dictionary
	# the keys are the names of the toggles
	
	toggle_callbacks_dict["FireObstacleToggleCheckBox"] = func(toggled_on: bool) -> void:
		fire_obstacle_toggle_check_box.button_pressed = toggled_on
		smoke_obstacle_toggle_check_box.button_pressed = toggled_on
		obstacle_polygon_2d.visible = toggled_on
	
	toggle_callbacks_dict["FireBakedToggleCheckBox"] = func(toggled_on: bool) -> void:
		fire_baked_toggle_check_box.button_pressed = toggled_on
		fire_curr_baked_color_toggled_on = toggled_on
	
	toggle_callbacks_dict["FireCustomToggleCheckBox"] = func(toggled_on: bool) -> void:
		fire_custom_toggle_check_box.button_pressed = toggled_on
		fire_curr_custom_color_toggled_on = toggled_on
		fire_gradient_editor.visible = toggled_on
	
	toggle_callbacks_dict["SmokeObstacleToggleCheckBox"] = func(toggled_on: bool) -> void:
		smoke_obstacle_toggle_check_box.button_pressed = toggled_on
		fire_obstacle_toggle_check_box.button_pressed = toggled_on
		obstacle_polygon_2d.visible = toggled_on
	
	toggle_callbacks_dict["SmokeGrayscaleToggleCheckBox"] = func(toggled_on: bool) -> void:
		smoke_grayscale_toggle_check_box.button_pressed = toggled_on
		smoke_curr_grayscale_color_toggled_on = toggled_on
	
	toggle_callbacks_dict["SmokeCustomToggleCheckBox"] = func(toggled_on: bool) -> void:
		smoke_custom_toggle_check_box.button_pressed = toggled_on
		smoke_curr_custom_color_toggled_on = toggled_on
		smoke_custom_color_picker_button.visible = toggled_on

func init_color_picker_button_callbacks() -> void:
	# for each color picker button we define its corresponding callable
	# callables are stored in a dictionary
	# the keys are the names of the color picker buttons
	
	color_picker_button_callbacks_dict["SmokeCustomColorPickerButton"] = func(new_color: Color) -> void:
		smoke_custom_color_picker_button.color = new_color
		smoke_curr_custom_color = new_color

func reset_params() -> void:
	slider_callbacks_dict["FireDisturbanceRadiusHSlider"].call(fire_default_disturbance_radius)
	slider_callbacks_dict["FireDisturbanceStrengthHSlider"].call(fire_default_disturbance_strength)
	slider_callbacks_dict["FireSplashRadiusHSlider"].call(fire_default_splash_radius)
	slider_callbacks_dict["FireSplashStrengthHSlider"].call(fire_default_splash_strength)
	slider_callbacks_dict["FireFuelDissipationHSlider"].call(fire_default_fuel_dissipation)
	slider_callbacks_dict["FireFuelBurnStrengthHSlider"].call(fire_default_fuel_burn_strength)
	slider_callbacks_dict["FireTemperatureDissipationHSlider"].call(fire_default_temperature_dissipation)
	slider_callbacks_dict["FireTemperatureCoolExponentHSlider"].call(fire_default_temperature_cool_exponent)
	slider_callbacks_dict["FireVorticityScaleHSlider"].call(fire_default_vorticity_scale)
	slider_callbacks_dict["FireBuoyancyStrengthHSlider"].call(fire_default_buoyancy_strength)
	slider_callbacks_dict["FireVelAbsValLimitHSlider"].call(fire_default_vel_abs_val_limit)
	slider_callbacks_dict["FireWaterHeatingSpeedHSlider"].call(fire_default_water_heating_speed)
	slider_callbacks_dict["FireWaterVaporizationSpeedHSlider"].call(fire_default_water_vaporization_speed)
	
	toggle_callbacks_dict["FireObstacleToggleCheckBox"].call(fire_default_obstacle_toggled_on)
	toggle_callbacks_dict["FireBakedToggleCheckBox"].call(fire_default_baked_color_toggled_on)
	toggle_callbacks_dict["FireCustomToggleCheckBox"].call(fire_default_custom_color_toggled_on)
	
	slider_callbacks_dict["SmokeDisturbanceRadiusHSlider"].call(smoke_default_disturbance_radius)
	slider_callbacks_dict["SmokeDisturbanceStrengthHSlider"].call(smoke_default_disturbance_strength)
	slider_callbacks_dict["SmokeDensityAndHeatingSplashRadiusHSlider"].call(smoke_default_density_and_heating_splash_radius)
	slider_callbacks_dict["SmokeDensityAndHeatingSplashStrengthHSlider"].call(smoke_default_density_and_heating_splash_strength)
	slider_callbacks_dict["SmokeCoolingSplashRadiusHSlider"].call(smoke_default_cooling_splash_radius)
	slider_callbacks_dict["SmokeCoolingSplashStrengthHSlider"].call(smoke_default_cooling_splash_strength)
	slider_callbacks_dict["SmokeDensityDissipationHSlider"].call(smoke_default_density_dissipation)
	slider_callbacks_dict["SmokeTemperatureDissipationHSlider"].call(smoke_default_temperature_dissipation)
	slider_callbacks_dict["SmokeVorticityScaleHSlider"].call(smoke_default_vorticity_scale)
	slider_callbacks_dict["SmokeDenseDownForceHSlider"].call(smoke_default_dense_down_force)
	slider_callbacks_dict["SmokeHotUpForceHSlider"].call(smoke_default_hot_up_force)
	slider_callbacks_dict["SmokeVelAbsValLimitHSlider"].call(smoke_default_vel_abs_val_limit)
	slider_callbacks_dict["SmokeVaporDensitySplashStrengthHSlider"].call(smoke_default_vapor_density_splash_strength)
	slider_callbacks_dict["SmokeVaporHeatingSplashStrengthHSlider"].call(smoke_default_vapor_heating_splash_strength)
	slider_callbacks_dict["SmokeMinAlbedoHSlider"].call(smoke_default_min_albedo)
	slider_callbacks_dict["SmokeMaxAlbedoHSlider"].call(smoke_default_max_albedo)
	
	toggle_callbacks_dict["SmokeObstacleToggleCheckBox"].call(smoke_default_obstacle_toggled_on)
	toggle_callbacks_dict["SmokeGrayscaleToggleCheckBox"].call(smoke_default_grayscale_color_toggled_on)
	toggle_callbacks_dict["SmokeCustomToggleCheckBox"].call(smoke_default_custom_color_toggled_on)
	
	color_picker_button_callbacks_dict["SmokeCustomColorPickerButton"].call(smoke_default_custom_color)

func screen_to_uv(sprite: Sprite2D) -> Vector2:
	# convert from screen coords to UV coords for a given Sprite2D
	return sprite.get_local_mouse_position() / sprite.get_rect().size

func disturb_fire_velocity(disturbance_origin: Vector2, disturbance_vector: Vector2) -> void:
	velocity_forces_sprite.material.set("shader_parameter/u_fire_disturbance_origin", disturbance_origin)
	velocity_forces_sprite.material.set("shader_parameter/u_fire_disturbance_vector", disturbance_vector)

func stop_disturbing_fire_velocity() -> void:
	velocity_forces_sprite.material.set("shader_parameter/u_fire_disturbance_origin", Vector2(-1.0, -1.0))
	velocity_forces_sprite.material.set("shader_parameter/u_fire_disturbance_vector", Vector2.ZERO)

func disturb_smoke_velocity(disturbance_origin: Vector2, disturbance_vector: Vector2) -> void:
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_disturbance_origin", disturbance_origin)
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_disturbance_vector", disturbance_vector)

func stop_disturbing_smoke_velocity() -> void:
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_disturbance_origin", Vector2(-1.0, -1.0))
	velocity_forces_sprite.material.set("shader_parameter/u_smoke_disturbance_vector", Vector2.ZERO)

func splash_fire_fuel(splash_position: Vector2, eraser_off: bool) -> void:
	splash_mask_sprite.material.set("shader_parameter/u_fuel_splash_position", splash_position)
	splash_mask_sprite.material.set("shader_parameter/u_fuel_eraser_off", int(eraser_off))

func stop_splashing_fire_fuel() -> void:
	splash_mask_sprite.material.set("shader_parameter/u_fuel_splash_position", Vector2(-1.0, -1.0))
	splash_mask_sprite.material.set("shader_parameter/u_fuel_eraser_off", 1)

func splash_smoke_density_heat_smoke_temperature(splash_position: Vector2, eraser_off: bool) -> void:
	splash_mask_sprite.material.set("shader_parameter/u_density_heating_splash_position", splash_position)
	splash_mask_sprite.material.set("shader_parameter/u_density_heating_eraser_off", int(eraser_off))

func stop_splashing_smoke_density_heating_smoke_temperature() -> void:
	splash_mask_sprite.material.set("shader_parameter/u_density_heating_splash_position", Vector2(-1.0, -1.0))
	splash_mask_sprite.material.set("shader_parameter/u_density_heating_eraser_off", 1)

func cool_smoke_temperature(cool_position: Vector2, eraser_off: bool) -> void:
	splash_mask_sprite.material.set("shader_parameter/u_cooling_mouse_position", cool_position)
	splash_mask_sprite.material.set("shader_parameter/u_cooling_eraser_off", int(eraser_off))

func stop_cooling_smoke_temperature() -> void:
	splash_mask_sprite.material.set("shader_parameter/u_cooling_mouse_position", Vector2(-1.0, -1.0))
	splash_mask_sprite.material.set("shader_parameter/u_cooling_eraser_off", 1)

func set_up_pressure_jacobi() -> void:
	# set up PressureJacobiN-PressureBoundaryN pairs
	# the number of pairs corresponds to the number of jacobi iterations
	# they should be placed between PressureInitViewport and VelocityDivFreeViewport
	var child_idx: int = pressure_init_viewport_idx + 1
	
	# from 0 to pressure_jacobi_iterations - 1
	for i in pressure_jacobi_iterations:
		# PressureJacobiN SubViewport
		var pressure_jacobi_i_name: String = "PressureJacobi%d"
		var pressure_jacobi_i: SubViewport = SubViewport.new()
		pressure_jacobi_i.name = pressure_jacobi_i_name % i
		pressure_jacobi_i.size = viewport_size
		pressure_jacobi_i.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		pressure_jacobi_i.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		pressure_jacobi_i.disable_3d = true
		pressure_jacobi_i.transparent_bg = true
		pressure_jacobi_i.use_hdr_2d = true
		pressure_jacobi_i.add_to_group("ViewportPipeline")
		
		# child of PressureJacobiN SubViewport
		var pressure_jacobi_i_sprite = Sprite2D.new()
		if (i == 0):
			pressure_jacobi_i_sprite.texture = pressure_init_viewport.get_texture()
		else:
			var previous_boundary: SubViewport = get_child(child_idx - 1)
			pressure_jacobi_i_sprite.texture = previous_boundary.get_texture()
		pressure_jacobi_i_sprite.centered = false
		pressure_jacobi_i_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pressure_jacobi_i_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		pressure_jacobi_i_sprite.material = ShaderMaterial.new()
		pressure_jacobi_i_sprite.material.shader = pressure_jacobi_n_shader
		pressure_jacobi_i_sprite.material.set("shader_parameter/u_divergence", divergence_viewport.get_texture())
		pressure_jacobi_i.add_child(pressure_jacobi_i_sprite)
		
		# PressureBoundaryN SubViewport
		var pressure_boundary_i_name: String = "PressureBoundary%d"
		var pressure_boundary_i: SubViewport = SubViewport.new()
		pressure_boundary_i.name = pressure_boundary_i_name % i
		pressure_boundary_i.size = viewport_size
		pressure_boundary_i.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		pressure_boundary_i.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		pressure_boundary_i.disable_3d = true
		pressure_boundary_i.transparent_bg = true
		pressure_boundary_i.use_hdr_2d = true
		pressure_boundary_i.add_to_group("ViewportPipeline")
		
		# child of PressureBoundaryN SubViewport
		var pressure_boundary_i_sprite = Sprite2D.new()
		pressure_boundary_i_sprite.texture = pressure_jacobi_i.get_texture()
		pressure_boundary_i_sprite.centered = false
		pressure_boundary_i_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pressure_boundary_i_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		pressure_boundary_i_sprite.material = ShaderMaterial.new()
		pressure_boundary_i_sprite.material.shader = pressure_boundary_n_shader
		pressure_boundary_i_sprite.material.set("shader_parameter/u_obstacles_raw", obstacles_raw_viewport.get_texture())
		pressure_boundary_i_sprite.material.set("shader_parameter/u_obstacles_edges", obstacles_edges_viewport.get_texture())
		pressure_boundary_i.add_child(pressure_boundary_i_sprite)
		
		add_child(pressure_jacobi_i)
		move_child(pressure_jacobi_i, child_idx)
		child_idx += 1
		add_child(pressure_boundary_i)
		move_child(pressure_boundary_i, child_idx)
		child_idx += 1
	
	print(get_child(pressure_init_viewport_idx).name)    # PressureInitViewport
	print(get_child(pressure_init_viewport_idx + (2 * pressure_jacobi_iterations) - 1).name)    # last PressureJacobiN
	print(get_child(pressure_init_viewport_idx + (2 * pressure_jacobi_iterations)).name)    # last PressureBoundaryN
	print(get_child(pressure_init_viewport_idx + (2 * pressure_jacobi_iterations) + 1).name)    # VelocityDivFreeViewport
	
	pressure_boundary_last = get_child(pressure_init_viewport_idx + (2 * pressure_jacobi_iterations))

func set_up_pressure_jacobi_faster() -> void:
	# this method is analogical to the original method above (without "faster" suffix)
	# the difference is that we don't set up PressureJacobiN-PressureBoundaryN pairs for each jacobi iteration
	# we setup only PressureJacobiN for each jacobi iteration
	# we don't setup PressureBoundaryN for each jacobi iteration
	# we only setup one PressureBoundary, the one at the end, after all iterations are finished
	# this saves GPU memory and computation time
	# that's because we don't process multiple PressureBoundaryN's at each iteration
	# it shouldn't have any dramatic effects on the simulation's accuracy (at least to the naked eye)
	var child_idx: int = pressure_init_viewport_idx + 1
	
	# from 0 to pressure_jacobi_iterations - 1
	for i in pressure_jacobi_iterations:
		# PressureJacobiN SubViewport
		var pressure_jacobi_i_name: String = "PressureJacobi%d"
		var pressure_jacobi_i: SubViewport = SubViewport.new()
		pressure_jacobi_i.name = pressure_jacobi_i_name % i
		pressure_jacobi_i.size = viewport_size
		pressure_jacobi_i.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		pressure_jacobi_i.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		pressure_jacobi_i.disable_3d = true
		pressure_jacobi_i.transparent_bg = true
		pressure_jacobi_i.use_hdr_2d = true
		pressure_jacobi_i.add_to_group("ViewportPipeline")
		
		# child of PressureJacobiN SubViewport
		var pressure_jacobi_i_sprite = Sprite2D.new()
		if (i == 0):
			pressure_jacobi_i_sprite.texture = pressure_init_viewport.get_texture()
		else:
			var previous_boundary: SubViewport = get_child(child_idx - 1)
			pressure_jacobi_i_sprite.texture = previous_boundary.get_texture()
		pressure_jacobi_i_sprite.centered = false
		pressure_jacobi_i_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pressure_jacobi_i_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		pressure_jacobi_i_sprite.material = ShaderMaterial.new()
		pressure_jacobi_i_sprite.material.shader = pressure_jacobi_n_shader
		pressure_jacobi_i_sprite.material.set("shader_parameter/u_divergence", divergence_viewport.get_texture())
		pressure_jacobi_i.add_child(pressure_jacobi_i_sprite)
		
		add_child(pressure_jacobi_i)
		move_child(pressure_jacobi_i, child_idx)
		child_idx += 1
	
	# PressureBoundary SubViewport
	var pressure_boundary_name: String = "PressureBoundary"
	var pressure_boundary: SubViewport = SubViewport.new()
	pressure_boundary.name = pressure_boundary_name
	pressure_boundary.size = viewport_size
	pressure_boundary.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	pressure_boundary.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pressure_boundary.disable_3d = true
	pressure_boundary.transparent_bg = true
	pressure_boundary.use_hdr_2d = true
	pressure_boundary.add_to_group("ViewportPipeline")
	
	var last_pressure_jacobi : SubViewport = get_child(child_idx - 1)
	
	# child of PressureBoundary SubViewport
	var pressure_boundary_sprite = Sprite2D.new()
	pressure_boundary_sprite.texture = last_pressure_jacobi.get_texture()
	pressure_boundary_sprite.centered = false
	pressure_boundary_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressure_boundary_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	pressure_boundary_sprite.material = ShaderMaterial.new()
	pressure_boundary_sprite.material.shader = pressure_boundary_n_shader
	pressure_boundary_sprite.material.set("shader_parameter/u_obstacles_raw", obstacles_raw_viewport.get_texture())
	pressure_boundary_sprite.material.set("shader_parameter/u_obstacles_edges", obstacles_edges_viewport.get_texture())
	pressure_boundary.add_child(pressure_boundary_sprite)
	
	add_child(pressure_boundary)
	move_child(pressure_boundary, child_idx)
	
	print(get_child(pressure_init_viewport_idx).name)    # PressureInitViewport
	print(get_child(pressure_init_viewport_idx + pressure_jacobi_iterations).name)    # last PressureJacobiN
	print(get_child(pressure_init_viewport_idx + pressure_jacobi_iterations + 1).name)    # PressureBoundary
	print(get_child(pressure_init_viewport_idx + pressure_jacobi_iterations + 2).name)    # VelocityDivFreeViewport
	
	pressure_boundary_last = get_child(pressure_init_viewport_idx + pressure_jacobi_iterations + 1)

func init_display_configs() -> void:
	#region [Fire + Smoke]
	fire_plus_smoke_textures = []
	fire_plus_smoke_textures.resize(6)
	fire_plus_smoke_textures[0] = fire_smoke_together_viewport.get_texture()
	fire_plus_smoke_textures[1] = fire_fuel_smoke_density_advect_viewport.get_texture()
	fire_plus_smoke_textures[2] = fire_smoke_temperature_advect_viewport.get_texture()
	fire_plus_smoke_textures[3] = velocity_div_free_viewport.get_texture()
	fire_plus_smoke_textures[4] = pressure_init_viewport.get_texture()
	fire_plus_smoke_textures[5] = divergence_viewport.get_texture()
	
	fire_plus_smoke_labels = []
	fire_plus_smoke_labels.resize(6)
	fire_plus_smoke_labels[0] = "Fire + Smoke"
	fire_plus_smoke_labels[1] = "Fire Fuel + Smoke Density"
	fire_plus_smoke_labels[2] = "Fire Temperature + Smoke Temperature"
	fire_plus_smoke_labels[3] = "Fire Velocity + Smoke Velocity"
	fire_plus_smoke_labels[4] = "Fire Pressure + Smoke Pressure"
	fire_plus_smoke_labels[5] = "Fire Divergence + Smoke Divergence"
	
	fire_plus_smoke_shaders = []
	fire_plus_smoke_shaders.resize(6)
	fire_plus_smoke_shaders[0] = empty_shader
	fire_plus_smoke_shaders[1] = clamp_shader
	fire_plus_smoke_shaders[2] = clamp_shader
	fire_plus_smoke_shaders[3] = clamp_shader
	fire_plus_smoke_shaders[4] = clamp_shader
	fire_plus_smoke_shaders[5] = clamp_shader
	
	fire_plus_smoke_use_r = []
	fire_plus_smoke_use_r.resize(6)
	fire_plus_smoke_use_r[0] = false
	fire_plus_smoke_use_r[1] = true
	fire_plus_smoke_use_r[2] = true
	fire_plus_smoke_use_r[3] = true
	fire_plus_smoke_use_r[4] = true
	fire_plus_smoke_use_r[5] = true
	
	fire_plus_smoke_use_g = []
	fire_plus_smoke_use_g.resize(6)
	fire_plus_smoke_use_g[0] = false
	fire_plus_smoke_use_g[1] = true
	fire_plus_smoke_use_g[2] = true
	fire_plus_smoke_use_g[3] = true
	fire_plus_smoke_use_g[4] = true
	fire_plus_smoke_use_g[5] = true
	
	fire_plus_smoke_use_b = []
	fire_plus_smoke_use_b.resize(6)
	fire_plus_smoke_use_b[0] = false
	fire_plus_smoke_use_b[1] = false
	fire_plus_smoke_use_b[2] = false
	fire_plus_smoke_use_b[3] = true
	fire_plus_smoke_use_b[4] = false
	fire_plus_smoke_use_b[5] = false
	
	fire_plus_smoke_use_a = []
	fire_plus_smoke_use_a.resize(6)
	fire_plus_smoke_use_a[0] = false
	fire_plus_smoke_use_a[1] = false
	fire_plus_smoke_use_a[2] = false
	fire_plus_smoke_use_a[3] = true
	fire_plus_smoke_use_a[4] = false
	fire_plus_smoke_use_a[5] = false
	
	fire_plus_smoke_max_values = []
	fire_plus_smoke_max_values.resize(6)
	fire_plus_smoke_max_values[0] = -1.0
	fire_plus_smoke_max_values[1] = 1.0
	fire_plus_smoke_max_values[2] = fire_temp_max
	fire_plus_smoke_max_values[3] = 1.0
	fire_plus_smoke_max_values[4] = 0.001
	fire_plus_smoke_max_values[5] = 0.1
	
	fire_plus_smoke_min_values = []
	fire_plus_smoke_min_values.resize(6)
	fire_plus_smoke_min_values[0] = -1.0
	fire_plus_smoke_min_values[1] = 0.0
	fire_plus_smoke_min_values[2] = smoke_temp_ambient
	fire_plus_smoke_min_values[3] = -1.0
	fire_plus_smoke_min_values[4] = -0.001
	fire_plus_smoke_min_values[5] = -0.1
	#endregion
	
	#region [Fire]
	fire_textures = []
	fire_textures.resize(6)
	fire_textures[0] = plancks_law_viewport.get_texture()
	fire_textures[1] = fire_fuel_smoke_density_advect_viewport.get_texture()
	fire_textures[2] = fire_smoke_temperature_advect_viewport.get_texture()
	fire_textures[3] = velocity_div_free_viewport.get_texture()
	fire_textures[4] = pressure_init_viewport.get_texture()
	fire_textures[5] = divergence_viewport.get_texture()
	
	fire_labels = []
	fire_labels.resize(6)
	fire_labels[0] = "Fire"
	fire_labels[1] = "Fire Fuel"
	fire_labels[2] = "Fire Temperature"
	fire_labels[3] = "Fire Velocity"
	fire_labels[4] = "Fire Pressure"
	fire_labels[5] = "Fire Divergence"
	
	fire_shaders = []
	fire_shaders.resize(6)
	fire_shaders[0] = empty_shader
	fire_shaders[1] = clamp_shader
	fire_shaders[2] = clamp_shader
	fire_shaders[3] = clamp_shader
	fire_shaders[4] = clamp_shader
	fire_shaders[5] = clamp_shader
	
	fire_use_r = []
	fire_use_r.resize(6)
	fire_use_r[0] = false
	fire_use_r[1] = true
	fire_use_r[2] = true
	fire_use_r[3] = true
	fire_use_r[4] = true
	fire_use_r[5] = true
	
	fire_use_g = []
	fire_use_g.resize(6)
	fire_use_g[0] = false
	fire_use_g[1] = false
	fire_use_g[2] = false
	fire_use_g[3] = true
	fire_use_g[4] = false
	fire_use_g[5] = false
	
	fire_use_b = []
	fire_use_b.resize(6)
	fire_use_b[0] = false
	fire_use_b[1] = false
	fire_use_b[2] = false
	fire_use_b[3] = false
	fire_use_b[4] = false
	fire_use_b[5] = false
	
	fire_use_a = []
	fire_use_a.resize(6)
	fire_use_a[0] = false
	fire_use_a[1] = false
	fire_use_a[2] = false
	fire_use_a[3] = false
	fire_use_a[4] = false
	fire_use_a[5] = false
	
	fire_max_values = []
	fire_max_values.resize(6)
	fire_max_values[0] = -1.0
	fire_max_values[1] = 1.0
	fire_max_values[2] = fire_temp_max
	fire_max_values[3] = 1.0
	fire_max_values[4] = 0.001
	fire_max_values[5] = 0.1
	
	fire_min_values = []
	fire_min_values.resize(6)
	fire_min_values[0] = -1.0
	fire_min_values[1] = 0.0
	fire_min_values[2] = fire_temp_ambient
	fire_min_values[3] = -1.0
	fire_min_values[4] = -0.001
	fire_min_values[5] = -0.1
	#endregion
	
	#region [Smoke]
	smoke_textures = []
	smoke_textures.resize(6)
	smoke_textures[0] = smoke_vis_viewport.get_texture()
	smoke_textures[1] = fire_fuel_smoke_density_advect_viewport.get_texture()
	smoke_textures[2] = fire_smoke_temperature_advect_viewport.get_texture()
	smoke_textures[3] = velocity_div_free_viewport.get_texture()
	smoke_textures[4] = pressure_init_viewport.get_texture()
	smoke_textures[5] = divergence_viewport.get_texture()
	
	smoke_labels = []
	smoke_labels.resize(6)
	smoke_labels[0] = "Smoke"
	smoke_labels[1] = "Smoke Density"
	smoke_labels[2] = "Smoke Temperature"
	smoke_labels[3] = "Smoke Velocity"
	smoke_labels[4] = "Smoke Pressure"
	smoke_labels[5] = "Smoke Divergence"
	
	smoke_shaders = []
	smoke_shaders.resize(6)
	smoke_shaders[0] = empty_shader
	smoke_shaders[1] = clamp_shader
	smoke_shaders[2] = clamp_shader
	smoke_shaders[3] = clamp_shader
	smoke_shaders[4] = clamp_shader
	smoke_shaders[5] = clamp_shader
	
	smoke_use_r = []
	smoke_use_r.resize(6)
	smoke_use_r[0] = false
	smoke_use_r[1] = false
	smoke_use_r[2] = false
	smoke_use_r[3] = false
	smoke_use_r[4] = false
	smoke_use_r[5] = false
	
	smoke_use_g = []
	smoke_use_g.resize(6)
	smoke_use_g[0] = false
	smoke_use_g[1] = true
	smoke_use_g[2] = true
	smoke_use_g[3] = false
	smoke_use_g[4] = true
	smoke_use_g[5] = true
	
	smoke_use_b = []
	smoke_use_b.resize(6)
	smoke_use_b[0] = false
	smoke_use_b[1] = false
	smoke_use_b[2] = false
	smoke_use_b[3] = true
	smoke_use_b[4] = false
	smoke_use_b[5] = false
	
	smoke_use_a = []
	smoke_use_a.resize(6)
	smoke_use_a[0] = false
	smoke_use_a[1] = false
	smoke_use_a[2] = false
	smoke_use_a[3] = true
	smoke_use_a[4] = false
	smoke_use_a[5] = false
	
	smoke_max_values = []
	smoke_max_values.resize(6)
	smoke_max_values[0] = -1.0
	smoke_max_values[1] = 1.0
	smoke_max_values[2] = smoke_temp_max
	smoke_max_values[3] = 1.0
	smoke_max_values[4] = 0.001
	smoke_max_values[5] = 0.1
	
	smoke_min_values = []
	smoke_min_values.resize(6)
	smoke_min_values[0] = -1.0
	smoke_min_values[1] = 0.0
	smoke_min_values[2] = smoke_temp_ambient
	smoke_min_values[3] = -1.0
	smoke_min_values[4] = -0.001
	smoke_min_values[5] = -0.1
	#endregion

func set_curr_display_config() -> void:
	if fire_interaction_mode and smoke_interaction_mode:
		curr_textures = fire_plus_smoke_textures
		curr_labels = fire_plus_smoke_labels
		curr_shaders = fire_plus_smoke_shaders
		curr_use_r = fire_plus_smoke_use_r
		curr_use_g = fire_plus_smoke_use_g
		curr_use_b = fire_plus_smoke_use_b
		curr_use_a = fire_plus_smoke_use_a
		curr_max_values = fire_plus_smoke_max_values
		curr_min_values = fire_plus_smoke_min_values
	elif fire_interaction_mode and (not smoke_interaction_mode):
		curr_textures = fire_textures
		curr_labels = fire_labels
		curr_shaders = fire_shaders
		curr_use_r = fire_use_r
		curr_use_g = fire_use_g
		curr_use_b = fire_use_b
		curr_use_a = fire_use_a
		curr_max_values = fire_max_values
		curr_min_values = fire_min_values
	elif smoke_interaction_mode and (not fire_interaction_mode):
		curr_textures = smoke_textures
		curr_labels = smoke_labels
		curr_shaders = smoke_shaders
		curr_use_r = smoke_use_r
		curr_use_g = smoke_use_g
		curr_use_b = smoke_use_b
		curr_use_a = smoke_use_a
		curr_max_values = smoke_max_values
		curr_min_values = smoke_min_values
	else:
		push_error("Invalid case: fire_interaction_mode and smoke_interaction_mode cannot be both false at the same time.")

func init_display() -> void:
	display.material = ShaderMaterial.new()
	curr_display_index = 0

func set_display() -> void:
	label.text = curr_labels[curr_display_index]
	
	display.texture = curr_textures[curr_display_index]
	display.material.shader = curr_shaders[curr_display_index]
	
	if curr_use_r[curr_display_index] or curr_use_g[curr_display_index] or curr_use_b[curr_display_index] or curr_use_a[curr_display_index]:
		# using clamp.gdshader
		display.material.set("shader_parameter/u_use_r", curr_use_r[curr_display_index])
		display.material.set("shader_parameter/u_use_g", curr_use_g[curr_display_index])
		display.material.set("shader_parameter/u_use_b", curr_use_b[curr_display_index])
		display.material.set("shader_parameter/u_use_a", curr_use_a[curr_display_index])
		display.material.set("shader_parameter/u_max_value", curr_max_values[curr_display_index])
		display.material.set("shader_parameter/u_min_value", curr_min_values[curr_display_index])

func init_mode_label() -> void:
	mode_label.text = fire_plus_smoke_mode_label_text

func set_mode_label() -> void:
	if fire_interaction_mode and smoke_interaction_mode:
		mode_label.text = fire_plus_smoke_mode_label_text
	elif fire_interaction_mode and (not smoke_interaction_mode):
		mode_label.text = fire_mode_label_text
	elif smoke_interaction_mode and (not fire_interaction_mode):
		mode_label.text = smoke_mode_label_text
	else:
		push_error("Invalid case: fire_interaction_mode and smoke_interaction_mode cannot be both false at the same time.")

func init_params_panel() -> void:
	curr_params_panel = fire_bottom_margin_container

func set_params_panel() -> void:
	var was_visible: bool = curr_params_panel.visible
	
	if fire_interaction_mode and (not smoke_interaction_mode) and (not curr_params_panel == fire_bottom_margin_container):
		curr_params_panel.visible = false
		curr_params_panel = fire_bottom_margin_container
		if was_visible:
			curr_params_panel.visible = true
	elif smoke_interaction_mode and (not fire_interaction_mode) and (not curr_params_panel == smoke_bottom_margin_container):
		curr_params_panel.visible = false
		curr_params_panel = smoke_bottom_margin_container
		if was_visible:
			curr_params_panel.visible = true

func swap_curr_params_panel() -> void:
	if curr_params_panel == fire_bottom_margin_container:
		curr_params_panel = smoke_bottom_margin_container
	elif curr_params_panel == smoke_bottom_margin_container:
		curr_params_panel = fire_bottom_margin_container

func set_particles_to_grid_connection(particles_texture: Texture2DRD) -> void:
	particles_to_grid_texture_rect.texture = particles_texture
	particles_to_grid_texture_rect.material.set("shader_parameter/u_init_state", false)

func get_grid_to_particles_connection() -> ViewportTexture:
	return grid_to_particles_viewport.get_texture()

func set_extinguishing_data(extinguishing_data: Array[float]) -> void:
	particle_mass = extinguishing_data[0]
	particle_specific_heat_capacity = extinguishing_data[1]
	particle_specific_latent_heat_vaporization = extinguishing_data[2]
	particle_heating_energy_cost = extinguishing_data[3]
	particle_vaporization_energy_cost = extinguishing_data[4]
	particle_total_energy_cost = extinguishing_data[5]
	
	fire_fuel_smoke_density_splash_sprite.material.set("shader_parameter/u_heating_energy_cost", particle_heating_energy_cost)
	fire_smoke_temperature_sprite.material.set("shader_parameter/u_heating_energy_cost", particle_heating_energy_cost)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_mass", particle_mass)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_specific_heat_capacity", particle_specific_heat_capacity)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_specific_latent_heat_vaporization", particle_specific_latent_heat_vaporization)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_heating_energy_cost", particle_heating_energy_cost)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_vaporization_energy_cost", particle_vaporization_energy_cost)
	grid_to_particles_texture_rect.material.set("shader_parameter/u_total_energy_cost", particle_total_energy_cost)

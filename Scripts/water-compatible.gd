class_name WaterCompatible
extends Node2D

#region implementation notes
# 1. normalized vs unnormalized coordinate system
# - we decouple the simulation domain from the viewport domain
# - the simulation is performed within the normalized world, i.e. within the rectangle [0,1]x[0,1]
# - this normalized world is then mapped to viewport, i.e. unnormalized, world to display it based on the viewport's size
# - the normalized coordinate system is used to express the properties of particles 
# - the unnormalized coordinate system is generally not used throughout this implementation with one big exception regarding SDF-related logic
#
# 2. mortal vs immortal & dead vs alive
# - we divide the particles into mortal and immortal
# - mortal particles have a limited lifetime, i.e. after some time they become dead and no longer participate in the simulation
# - immortal particles, on the other hand, don't die, so they never disappear from the simulation (infinite lifetime)
# - therefore, we also divide particles into dead and alive
# - dead particles don't appear in the simulation
# - alive particles appear in the simulation
# - dead particles can be used to implement particle spawner without having to resize particle buffers on GPU
# - this is because dead particles are "free to reuse"
# - we can just check if we currently have any dead particles, and if so, we can reuse them as new particles being spawned by marking them as alive
# - we can specify how many mortal particles and how many immortal particles start the simulation as alive
# - if a mortal particle starts the simulation as alive, it will die eventually, after some time
# - if an immortal particle starts the simulation as alive, it won't ever die
# - some mortal and some immortal particles can initially be marked as dead and used as spawnable particles from the very start of the simulation
# - spawned mortal particles will eventually die, while spawned immortal particles won't do this
# - thus, the total number of dead particles at any given time determines the total number of particles that we can possibly spawn at that time
# - we can also of course specify how many mortal and how many immortal particles we have out of the total number of particles
#endregion

#region tweakable variables for 196x196 simulation

#region init tweakables

## Size of the window that the simulation will be displayed in.
@export var viewport_size: Vector2i = Vector2i(1152, 648)

## Size of the low resolution buffer which is used in rendering discrete particles as continuous water.
## Note: it turns out that Godot provides built-in tools which allow us to actually use the normal resolution instead of the low resolution without affecting the performace (moreover, lower resolutions give worse results).
@export var low_res_size: Vector2i = Vector2i(1152, 648)

## How many simulation steps to run per frame.
@export var sim_steps_per_frame: int = 6

## How many frames will the CPU wait to sync with the GPU after submitting the work to the GPU.
## Syncing is a costly operation.
## Should be at least ~1,2,3 to allow CPU and GPU to work in parallel.
@export var desired_waiting_frames: int = 2

## Generally, a number between 0.0 and 1.0.
## Controls the maximum allowed timestep of one simulation step.
## Helps to keep the simulation stable.
@export var safety_courant_number: float = 0.33

## Determines the total number of particles that can be used in the simulation.
@export var particle_grid_size: Vector2i = Vector2i(196, 196)

## Expressed in normalized world units.
## Shifts the initial position of the particles when starting the simulation.
@export var init_grid_top_left_corner: Vector2 = Vector2(0.0, 0.0)

## Very important variable.
## Determines the values of a few other important variables.
## Expressed in normalized world units.
## Particles = samples of a continuous fluid, particle spacing = sampling resolution.
@export var particle_spacing: float = 1.0 / 196.0

## Generally, a number between ~1.0 and ~2.0 (~3.0 is probably too much).
## Controls the size of the smoothing radius.
@export var smoothing_radius_multiplier: float = 2.0

## [%]
## How many particles are mortal.
@export var mortal_particles_amount: float = 1.0

## [%]
## How many mortal particles start the simulation as alive.
@export var init_alive_mortal_particles_amount: float = 0.0

## [%]
## How many immortal particles start the simulation as alive.
@export var init_alive_immortal_particles_amount: float = 0.0

## [seconds]
## Lower bound for random lifetime of mortal particles.
@export var mortal_particle_lifetime_min: float = 2.0

## [seconds]
## Upper bound for random lifetime of mortal particles.
@export var mortal_particle_lifetime_max: float = 3.0

#endregion

#region real-time tweakables
var water_main_color: Color = Color(0.0, 0.413, 0.66, 1.0)
var water_tint_color: Color = Color(0.0, 0.652, 0.85, 1.0)
var particle_color: Color = Color.RED    # predefined, used to encode the density in the R channel
var particle_vis_size: float = 0.25
var rest_density: float = 1.0
var stiffness: float = 10.0
var stiffness_near: float = 1.0
var viscosity_scale: float = 0.0005
var xsph_scale: float = 0.03
var vorticity_scale: float = 0.1
var surface_tension_threshold: float = 550.0
var surface_tension_scale: float = 5.0
var adhesion_threshold: float = 0.01
var adhesion_scale: float = 0.3
var gravity_multiplier: float = 1.0
var damping: float = 0.9999
var bounds_damping: float = 0.5
var vel_clamp: float = 20.0
var mouse_interaction_radius: float = 0.25
var mouse_interaction_strength: float = 25.0
var glass_movement_speed: float = 200.0    # px / s
var glass_rotation_speed: float = 3.141    # radians / s
var glass_scaling_speed: Vector2 = Vector2(3.0, 3.0)    # px / s
var spawn_rate: float = 32000.0     # particles / s
var spawn_random_offset_range: int = 16    # in particle_spacing units
var spawn_init_vel: Vector2 = Vector2(0.0, 0.0)
var blur_amount: float = 0.9
var water_density_threshold: float = 0.2
var edge_softness: float = 0.05
var tint_threshold_min: float = 0.25
var tint_threshold_max: float = 1.0
var vis_neighborhood_search: bool = false
#endregion

#endregion

#region predefined variables for ...x... simulation

#region general predefined variables
var background_color: Color
var verbose_particle_color: Color
var neighbor_particle_color: Color

var normalized_sim_world_bounds_min: Vector2
var normalized_sim_world_bounds_max: Vector2

var normalized_to_viewport_scale_factor: Vector2
var viewport_to_normalized_scale_factor: Vector2

var mass: float
var smoothing_radius: float
var max_timestep: float

var poly6_2d_constant: float
var spiky_2d_gradient_constant: float
var visc_2d_laplacian_constant: float

var gravity: Vector2

var particle_count: int

var particle_pos_temp_img_size: int
var glass_sdf_imgs_size: Vector2i

var viewport_size_f: Vector2
var sim_steps_per_frame_f: float
var particle_grid_size_f: Vector2
var particle_pos_temp_img_size_f: float
var glass_sdf_imgs_size_f: Vector2

var verbose_particle_idx: int

var mouse_normalized_pos: Vector2

var left_button_clicked: bool
var right_button_clicked: bool
var middle_button_clicked: bool

var left_arrow_pressed: bool
var right_arrow_pressed: bool
var up_arrow_pressed: bool
var down_arrow_pressed: bool

var a_key_pressed: bool
var d_key_pressed: bool
var w_key_pressed: bool
var s_key_pressed: bool

var waiting_for_gpu: bool
var curr_waiting_frames: int

var kill_particles_workgroup_size_x: int
var kill_particles_workgroups_x: int
var spawn_particles_workgroup_size_x: int
var spawn_particles_workgroups_x: int
var compute_hashes_workgroup_size_x: int
var compute_hashes_workgroups_x: int
var range_start_end_workgroup_size_x: int
var range_start_end_workgroups_x: int
var compute_densities_workgroup_size_x: int
var compute_densities_workgroups_x: int
var compute_pressures_workgroup_size_x: int
var compute_pressures_workgroups_x: int
var compute_vorticities_workgroup_size_x: int
var compute_vorticities_workgroups_x: int
var compute_forces_workgroup_size_x: int
var compute_forces_workgroups_x: int
var integrate_motion_workgroup_size_x: int
var integrate_motion_workgroups_x: int
var store_neighbors_workgroup_size_x: int
var store_neighbors_workgroups_x: int
var mark_neighbors_workgroup_size_x: int
var mark_neighbors_workgroups_x: int

var positions_size: int
var velocities_size: int
var temperatures_size: int
var lifetimes_size: int
var ages_size: int
var is_alive_size: int
var dead_stack_size: int
var hashes_size: int
var particle_indices_size: int
var start_indices_size: int
var end_indices_size: int
var densities_size: int
var pressures_size: int
var near_densities_size: int
var near_pressures_size: int
var vorticities_size: int
var forces_size: int
var neighbor_flags_size: int

var glass_sdf_img: Image
var glass_sdf_gradient_img: Image

var M_X_x: float
var M_X_y: float
var M_Y_x: float
var M_Y_y: float
var M_origin_x: float
var M_origin_y: float

var M_rotation_X_x: float
var M_rotation_X_y: float
var M_rotation_Y_x: float
var M_rotation_Y_y: float

var T_init: Transform2D
var T_init_inverse: Transform2D

var mortal_particle_count: int
var immortal_particle_count: int
var init_alive_mortal_particle_count: int
var init_dead_mortal_particle_count: int
var init_alive_immortal_particle_count: int
var init_dead_immortal_particle_count: int
var init_dead_particle_count: int

var spawn_accumulator: float
var prev_spawn_accumulator_int_part: int
var curr_spawn_accumulator_int_part: int
var spawn_count: int
var spawn_grid_size: int
var spawn_random_offset: Vector2i

var rt_water_main_color: Color
var rt_water_tint_color: Color
var rt_particle_color: Color
var rt_particle_vis_size: float
var rt_rest_density: float
var rt_stiffness: float
var rt_stiffness_near: float
var rt_viscosity_scale: float
var rt_xsph_scale: float
var rt_vorticity_scale: float
var rt_surface_tension_threshold: float
var rt_surface_tension_scale: float
var rt_adhesion_threshold: float
var rt_adhesion_scale: float
var rt_gravity_multiplier: float
var rt_damping: float
var rt_bounds_damping: float
var rt_vel_clamp: float
var rt_mouse_interaction_radius: float
var rt_mouse_interaction_strength: float
var rt_glass_movement_speed: float
var rt_glass_rotation_speed: float
var rt_glass_scaling_speed: Vector2
var rt_spawn_rate: float
var rt_spawn_random_offset_range: int
var rt_spawn_init_vel: Vector2
var rt_blur_amount: float
var rt_water_density_threshold: float
var rt_edge_softness: float
var rt_tint_threshold_min: float
var rt_tint_threshold_max: float
var rt_vis_neighborhood_search: bool

var color_picker_button_callbacks_dict: Dictionary
var slider_callbacks_dict: Dictionary
var toggle_callbacks_dict: Dictionary

var curr_display_idx: int

@export var textures: Array[ViewportTexture] = []    # textures to display in the simulation
@export var labels: Array[String] = []    # labels visible in the top-left corner

@onready var glass_sdf_sprite_2d: Sprite2D = $GlassSDFSprite2D
@onready var glass_sdf_gradient_sprite_2d: Sprite2D = $GlassSDFGradientSprite2D
@onready var particles_sub_viewport: SubViewport = $ParticlesSubViewport
@onready var gpu_particles_2d: GPUParticles2D = $ParticlesSubViewport/GPUParticles2D
@onready var low_res_water_density_sub_viewport: SubViewport = $LowResWaterDensitySubViewport
@onready var low_res_texture_rect: TextureRect = $LowResWaterDensitySubViewport/LowResTextureRect
@onready var low_res_color_rect: ColorRect = $LowResWaterDensitySubViewport/LowResColorRect
@onready var water_sub_viewport: SubViewport = $WaterSubViewport
@onready var another_background_sprite_2d: Sprite2D = $WaterSubViewport/AnotherBackgroundSprite2D
@onready var upscaled_texture_rect: TextureRect = $WaterSubViewport/UpscaledTextureRect
@onready var display: Sprite2D = $Display
@onready var glass: Polygon2D = $Glass    # we assume that all verties of the polygon are within the normalized world boundaries
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var label: Label = $CanvasLayer/VBoxContainer/TopMarginContainer/HBoxContainer/Label
@onready var fps_label: Label = $CanvasLayer/VBoxContainer/TopMarginContainer/HBoxContainer/FPSLabel
@onready var top_margin_container: MarginContainer = $CanvasLayer/VBoxContainer/TopMarginContainer
@onready var bottom_margin_container: MarginContainer = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer

@onready var particle_vis_size_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ParticleVisSizeHBoxContainer/ParticleVisSizeValue
@onready var rest_density_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/RestDensityHBoxContainer/RestDensityValue
@onready var stiffness_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/StiffnessHBoxContainer/StiffnessValue
@onready var stiffness_near_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/StiffnessNearHBoxContainer/StiffnessNearValue
@onready var viscosity_scale_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ViscosityScaleHBoxContainer/ViscosityScaleValue
@onready var xsph_scale_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/XSPHScaleHBoxContainer/XSPHScaleValue
@onready var vorticity_scale_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/VorticityScaleHBoxContainer/VorticityScaleValue
@onready var surface_tension_threshold_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SurfaceTensionThresholdHBoxContainer/SurfaceTensionThresholdValue
@onready var surface_tension_scale_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SurfaceTensionScaleHBoxContainer/SurfaceTensionScaleValue
@onready var adhesion_threshold_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/AdhesionThresholdHBoxContainer/AdhesionThresholdValue
@onready var adhesion_scale_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/AdhesionScaleHBoxContainer/AdhesionScaleValue
@onready var gravity_multiplier_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GravityMultiplierHBoxContainer/GravityMultiplierValue
@onready var damping_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/DampingHBoxContainer/DampingValue
@onready var bounds_damping_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/BoundsDampingHBoxContainer/BoundsDampingValue
@onready var vel_clamp_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/VelClampHBoxContainer/VelClampValue
@onready var mouse_interaction_radius_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/MouseInteractionRadiusHBoxContainer/MouseInteractionRadiusValue
@onready var mouse_interaction_strength_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/MouseInteractionStrengthHBoxContainer/MouseInteractionStrengthValue
@onready var glass_movement_speed_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassMovementSpeedHBoxContainer/GlassMovementSpeedValue
@onready var glass_rotation_speed_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassRotationSpeedHBoxContainer/GlassRotationSpeedValue
@onready var glass_scaling_speed_x_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassScalingSpeedHBoxContainer/XHBoxContainer/GlassScalingSpeedXValue
@onready var glass_scaling_speed_y_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassScalingSpeedHBoxContainer/YHBoxContainer/GlassScalingSpeedYValue
@onready var spawn_rate_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnRateHBoxContainer/SpawnRateValue
@onready var spawn_random_offset_range_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnRandomOffsetRangeHBoxContainer/SpawnRandomOffsetRangeValue
@onready var spawn_init_vel_x_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnInitVelHBoxContainer/XHBoxContainer/SpawnInitVelXValue
@onready var spawn_init_vel_y_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnInitVelHBoxContainer/YHBoxContainer/SpawnInitVelYValue
@onready var blur_amount_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/BlurAmountHBoxContainer/BlurAmountValue
@onready var water_density_threshold_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/WaterDensityThresholdHBoxContainer/WaterDensityThresholdValue
@onready var edge_softness_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/EdgeSoftnessHBoxContainer/EdgeSoftnessValue
@onready var tint_threshold_min_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/TintThresholdMinHBoxContainer/TintThresholdMinValue
@onready var tint_threshold_max_value: Label = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/TintThresholdMaxHBoxContainer/TintThresholdMaxValue

@onready var water_main_color_picker_button: ColorPickerButton = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ColorPickerButtonsHBoxContainer/WaterMainColorMarginContainer/WaterMainColorPickerButton
@onready var water_tint_color_picker_button: ColorPickerButton = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ColorPickerButtonsHBoxContainer/WaterTintColorMarginContainer/WaterTintColorPickerButton
@onready var particle_color_picker_button: ColorPickerButton = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ColorPickerButtonsHBoxContainer/ParticleColorMarginContainer/ParticleColorPickerButton

@onready var particle_vis_size_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ParticleVisSizeHBoxContainer/ParticleVisSizeMarginContainer/ParticleVisSizeHSlider
@onready var rest_density_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/RestDensityHBoxContainer/RestDensityMarginContainer/RestDensityHSlider
@onready var stiffness_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/StiffnessHBoxContainer/StiffnessMarginContainer/StiffnessHSlider
@onready var stiffness_near_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/StiffnessNearHBoxContainer/StiffnessNearMarginContainer/StiffnessNearHSlider
@onready var viscosity_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/ViscosityScaleHBoxContainer/ViscosityScaleMarginContainer/ViscosityScaleHSlider
@onready var xsph_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/XSPHScaleHBoxContainer/XSPHScaleMarginContainer/XSPHScaleHSlider
@onready var vorticity_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/VorticityScaleHBoxContainer/VorticityScaleMarginContainer/VorticityScaleHSlider
@onready var surface_tension_threshold_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SurfaceTensionThresholdHBoxContainer/SurfaceTensionThresholdMarginContainer/SurfaceTensionThresholdHSlider
@onready var surface_tension_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SurfaceTensionScaleHBoxContainer/SurfaceTensionScaleMarginContainer/SurfaceTensionScaleHSlider
@onready var adhesion_threshold_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/AdhesionThresholdHBoxContainer/AdhesionThresholdMarginContainer/AdhesionThresholdHSlider
@onready var adhesion_scale_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/AdhesionScaleHBoxContainer/AdhesionScaleMarginContainer/AdhesionScaleHSlider
@onready var gravity_multiplier_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GravityMultiplierHBoxContainer/GravityMultiplierMarginContainer/GravityMultiplierHSlider
@onready var damping_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/DampingHBoxContainer/DampingMarginContainer/DampingHSlider
@onready var bounds_damping_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/BoundsDampingHBoxContainer/BoundsDampingMarginContainer/BoundsDampingHSlider
@onready var vel_clamp_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/VelClampHBoxContainer/VelClampMarginContainer/VelClampHSlider
@onready var mouse_interaction_radius_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/MouseInteractionRadiusHBoxContainer/MouseInteractionRadiusMarginContainer/MouseInteractionRadiusHSlider
@onready var mouse_interaction_strength_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/MouseInteractionStrengthHBoxContainer/MouseInteractionStrengthMarginContainer/MouseInteractionStrengthHSlider
@onready var glass_movement_speed_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassMovementSpeedHBoxContainer/GlassMovementSpeedMarginContainer/GlassMovementSpeedHSlider
@onready var glass_rotation_speed_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassRotationSpeedHBoxContainer/GlassRotationSpeedMarginContainer/GlassRotationSpeedHSlider
@onready var glass_scaling_speed_x_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassScalingSpeedHBoxContainer/XHBoxContainer/GlassScalingSpeedXMarginContainer/GlassScalingSpeedXHSlider
@onready var glass_scaling_speed_y_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/GlassScalingSpeedHBoxContainer/YHBoxContainer/GlassScalingSpeedYMarginContainer/GlassScalingSpeedYHSlider
@onready var spawn_rate_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnRateHBoxContainer/SpawnRateMarginContainer/SpawnRateHSlider
@onready var spawn_random_offset_range_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnRandomOffsetRangeHBoxContainer/SpawnRandomOffsetRangeMarginContainer/SpawnRandomOffsetRangeHSlider
@onready var spawn_init_vel_x_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnInitVelHBoxContainer/XHBoxContainer/SpawnInitVelXMarginContainer/SpawnInitVelXHSlider
@onready var spawn_init_vel_y_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/SpawnInitVelHBoxContainer/YHBoxContainer/SpawnInitVelYMarginContainer/SpawnInitVelYHSlider
@onready var blur_amount_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/BlurAmountHBoxContainer/BlurAmountMarginContainer/BlurAmountHSlider
@onready var water_density_threshold_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/WaterDensityThresholdHBoxContainer/WaterDensityThresholdMarginContainer/WaterDensityThresholdHSlider
@onready var edge_softness_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/EdgeSoftnessHBoxContainer/EdgeSoftnessMarginContainer/EdgeSoftnessHSlider
@onready var tint_threshold_min_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/TintThresholdMinHBoxContainer/TintThresholdMinMarginContainer/TintThresholdMinHSlider
@onready var tint_threshold_max_h_slider: HSlider = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/TintThresholdMaxHBoxContainer/TintThresholdMaxMarginContainer/TintThresholdMaxHSlider

@onready var vis_neighborhood_search_toggle_check_box: CheckBox = $CanvasLayer/VBoxContainer/ScrollContainer/BottomMarginContainer/PanelContainer/MarginContainer/VBoxContainer/VisNeighborhoodSearchToggleHBoxContainer/VisNeighborhoodSearchToggleMarginContainer/VisNeighborhoodSearchToggleCheckBox
#endregion

#region parallel radix sort predefined variables
var histogram_workgroup_size_x: int
var histogram_workgroups_x: int

var digit_num_bits: int
var num_digits: int

var digits_times_groups: int

var counts_per_digit_workgroup_size_x: int
var counts_per_digit_workgroups_x: int

var pps16_workgroup_size_x: int
var pps16_workgroups_x: int

var scan_per_digit_workgroup_size_x: int
var scan_per_digit_workgroups_x: int

var combine_offsets_workgroup_size_x: int
var combine_offsets_workgroups_x: int

var scatter_workgroup_size_x: int
var scatter_workgroups_x: int

var group_histograms_size: int
var digit_totals_size: int
var digit_totals_after_scan_size: int
var prefix_groups_size: int
var group_offsets_size: int
#endregion

#endregion

#region compute shader pipeline variables

# rendering devices are the basis for everything
var rd: RenderingDevice
var ren_rd: RenderingDevice

#region shader variables
# shader variables correspond to all compute shaders used in the pipeline
var kill_particles_shader_rid: RID
var spawn_particles_shader_rid: RID
var compute_hashes_shader_rid: RID
#region parallel radix sort shader variables
var histogram_shader_rid: RID
var counts_per_digit_shader_rid: RID
var pps16_shader_rid: RID
var scan_per_digit_shader_rid: RID
var combine_offsets_shader_rid: RID
var scatter_shader_rid: RID
#endregion
var range_start_end_shader_rid: RID
var compute_densities_shader_rid: RID
var compute_pressures_shader_rid: RID
var compute_vorticities_shader_rid: RID
var compute_forces_shader_rid: RID
var integrate_motion_shader_rid: RID
var store_neighbors_shader_rid: RID
var mark_neighbors_shader_rid: RID
#endregion

#region buffers
# buffers store all necessary data on GPU and are initialized with bytes on CPU
var positions_buffer_rid: RID
var velocities_buffer_rid: RID
var temperatures_buffer_rid: RID
var lifetimes_buffer_rid: RID
var ages_buffer_rid: RID
var is_alive_buffer_rid: RID
var dead_stack_buffer_rid: RID
var dead_count_buffer_rid: RID
var hashes_1_buffer_rid: RID    # ping-pong
var hashes_2_buffer_rid: RID    # ping-pong
var particle_indices_1_buffer_rid: RID    # ping-pong
var particle_indices_2_buffer_rid: RID    # ping-pong
#region parallel radix sort buffers
var group_histograms_buffer_rid: RID
var digit_totals_buffer_rid: RID
var digit_totals_after_scan_buffer_rid: RID
var prefix_groups_buffer_rid: RID
var group_offsets_buffer_rid: RID
#endregion
var start_indices_buffer_rid: RID
var end_indices_buffer_rid: RID
var densities_buffer_rid: RID
var pressures_buffer_rid: RID
var near_densities_buffer_rid: RID
var near_pressures_buffer_rid: RID
var vorticities_buffer_rid: RID
var forces_buffer_rid: RID
var neighbor_flags_buffer_rid: RID
#endregion

#region uniforms
# uniforms point to existing buffers on GPU and connect them to shaders
var kill_particles_positions_uniform: RDUniform
var kill_particles_velocities_uniform: RDUniform
var kill_particles_lifetimes_uniform: RDUniform
var kill_particles_ages_uniform: RDUniform
var kill_particles_is_alive_uniform: RDUniform
var kill_particles_dead_stack_uniform: RDUniform
var kill_particles_dead_count_uniform: RDUniform
var spawn_particles_positions_uniform: RDUniform
var spawn_particles_velocities_uniform: RDUniform
var spawn_particles_ages_uniform: RDUniform
var spawn_particles_is_alive_uniform: RDUniform
var spawn_particles_dead_stack_uniform: RDUniform
var spawn_particles_dead_count_uniform: RDUniform
var compute_hashes_positions_uniform: RDUniform
var compute_hashes_hashes_uniform: RDUniform
var compute_hashes_particle_indices_uniform: RDUniform
#region parallel radix sort uniforms
var histogram_keys_in_1_uniform: RDUniform    # ping-pong
var histogram_keys_in_2_uniform: RDUniform    # ping-pong
var histogram_group_histograms_uniform: RDUniform
var counts_per_digit_group_histograms_uniform: RDUniform
var counts_per_digit_digit_totals_uniform: RDUniform
var pps16_inputtt_uniform: RDUniform
var pps16_outputtt_uniform: RDUniform
var scan_per_digit_group_histograms_uniform: RDUniform
var scan_per_digit_prefix_groups_uniform: RDUniform
var combine_offsets_digit_totals_after_scan_uniform: RDUniform
var combine_offsets_prefix_groups_uniform: RDUniform
var combine_offsets_group_offsets_uniform: RDUniform
var scatter_keys_in_1_uniform: RDUniform    # ping-pong
var scatter_keys_in_2_uniform: RDUniform    # ping-pong
var scatter_keys_out_1_uniform: RDUniform    # ping-pong
var scatter_keys_out_2_uniform: RDUniform    # ping-pong
var scatter_group_offsets_uniform: RDUniform
var scatter_values_in_1_uniform: RDUniform    # ping-pong
var scatter_values_in_2_uniform: RDUniform    # ping-pong
var scatter_values_out_1_uniform: RDUniform    # ping-pong
var scatter_values_out_2_uniform: RDUniform    # ping-pong
#endregion
var range_start_end_hashes_uniform: RDUniform
var range_start_end_start_indices_uniform: RDUniform
var range_start_end_end_indices_uniform: RDUniform
var compute_densities_positions_uniform: RDUniform
var compute_densities_sorted_particle_indices_uniform: RDUniform
var compute_densities_start_indices_uniform: RDUniform
var compute_densities_end_indices_uniform: RDUniform
var compute_densities_densities_uniform: RDUniform
var compute_densities_near_densities_uniform: RDUniform
var compute_densities_is_alive_uniform: RDUniform
var compute_pressures_densities_uniform: RDUniform
var compute_pressures_pressures_uniform: RDUniform
var compute_pressures_near_densities_uniform: RDUniform
var compute_pressures_near_pressures_uniform: RDUniform
var compute_pressures_is_alive_uniform: RDUniform
var compute_vorticities_positions_uniform: RDUniform
var compute_vorticities_sorted_particle_indices_uniform: RDUniform
var compute_vorticities_start_indices_uniform: RDUniform
var compute_vorticities_end_indices_uniform: RDUniform
var compute_vorticities_densities_uniform: RDUniform
var compute_vorticities_velocities_uniform: RDUniform
var compute_vorticities_vorticities_uniform: RDUniform
var compute_vorticities_is_alive_uniform: RDUniform
var compute_forces_positions_uniform: RDUniform
var compute_forces_velocities_uniform: RDUniform
var compute_forces_sorted_particle_indices_uniform: RDUniform
var compute_forces_start_indices_uniform: RDUniform
var compute_forces_end_indices_uniform: RDUniform
var compute_forces_densities_uniform: RDUniform
var compute_forces_pressures_uniform: RDUniform
var compute_forces_near_densities_uniform: RDUniform
var compute_forces_near_pressures_uniform: RDUniform
var compute_forces_vorticities_uniform: RDUniform
var compute_forces_forces_uniform: RDUniform
var compute_forces_is_alive_uniform: RDUniform
var integrate_motion_positions_uniform: RDUniform
var integrate_motion_velocities_uniform: RDUniform
var integrate_motion_densities_uniform: RDUniform
var integrate_motion_forces_uniform: RDUniform
var integrate_motion_sorted_particle_indices_uniform: RDUniform
var integrate_motion_start_indices_uniform: RDUniform
var integrate_motion_end_indices_uniform: RDUniform
var integrate_motion_is_alive_uniform: RDUniform
var integrate_motion_temperatures_uniform: RDUniform
var store_neighbors_positions_uniform: RDUniform
var store_neighbors_sorted_particle_indices_uniform: RDUniform
var store_neighbors_start_indices_uniform: RDUniform
var store_neighbors_end_indices_uniform: RDUniform
var store_neighbors_neighbor_flags_uniform: RDUniform
var mark_neighbors_neighbor_flags_uniform: RDUniform
#endregion

#region textures
# textures can be used as buffers when our data isn't regular data but rather image data
var particle_pos_temp_img_texture_view: RDTextureView
var particle_pos_temp_img_texture_format: RDTextureFormat
var particle_pos_temp_img_ren_texture_rid: RID
var particle_pos_temp_img_texture_rid: RID
var particle_pos_temp_img_texture_2drd: Texture2DRD

var glass_sdf_img_texture_view: RDTextureView
var glass_sdf_img_texture_format: RDTextureFormat
var glass_sdf_img_ren_texture_rid: RID
var glass_sdf_img_texture_rid: RID
var glass_sdf_img_texture_2drd: Texture2DRD

var glass_sdf_gradient_img_texture_view: RDTextureView
var glass_sdf_gradient_img_texture_format: RDTextureFormat
var glass_sdf_gradient_img_ren_texture_rid: RID
var glass_sdf_gradient_img_texture_rid: RID
var glass_sdf_gradient_img_texture_2drd: Texture2DRD

var integrate_motion_particle_pos_temp_img_uniform: RDUniform
var integrate_motion_glass_sdf_img_uniform: RDUniform
var integrate_motion_glass_sdf_gradient_img_uniform: RDUniform
var store_neighbors_particle_pos_temp_img_uniform: RDUniform
var mark_neighbors_particle_pos_temp_img_uniform: RDUniform
#endregion

#region uniform sets
# uniform sets are used by shaders so that shaders know which uniforms to use and which uniform points to which buffer
var kill_particles_uniform_set_rid: RID
var spawn_particles_uniform_set_rid: RID
var compute_hashes_uniform_set_rid: RID
#region parallel radix sort uniform sets
var histogram_uniform_set_1_rid: RID    # ping-pong
var histogram_uniform_set_2_rid: RID    # ping-pong
var counts_per_digit_uniform_set_rid: RID
var pps16_uniform_set_rid: RID
var scan_per_digit_uniform_set_rid: RID
var combine_offsets_uniform_set_rid: RID
var scatter_uniform_set_1_rid: RID    # ping-pong
var scatter_uniform_set_2_rid: RID    # ping-pong
#endregion
var range_start_end_uniform_set_rid: RID
var compute_densities_uniform_set_rid: RID
var compute_pressures_uniform_set_rid: RID
var compute_vorticities_uniform_set_rid: RID
var compute_forces_uniform_set_rid: RID
var integrate_motion_uniform_set_rid: RID
var store_neighbors_uniform_set_rid: RID
var mark_neighbors_uniform_set_rid: RID
#endregion

#region pipelines
# pipelines correspond to shaders, i.e. each shader has its own pipeline
var kill_particles_pipeline_rid: RID
var spawn_particles_pipeline_rid: RID
var compute_hashes_pipeline_rid: RID
#region parallel radix sort pipelines
var histogram_pipeline_rid: RID
var counts_per_digit_pipeline_rid: RID
var pps16_pipeline_rid: RID
var scan_per_digit_pipeline_rid: RID
var combine_offsets_pipeline_rid: RID
var scatter_pipeline_rid: RID
#endregion
var range_start_end_pipeline_rid: RID
var compute_densities_pipeline_rid: RID
var compute_pressures_pipeline_rid: RID
var compute_vorticities_pipeline_rid: RID
var compute_forces_pipeline_rid: RID
var integrate_motion_pipeline_rid: RID
var store_neighbors_pipeline_rid: RID
var mark_neighbors_pipeline_rid: RID
#endregion

#endregion

func _ready() -> void:
	init_general_predefined_variables()
	init_parallel_radix_sort_predefined_variables()
	
	particles_sub_viewport.size = viewport_size
	low_res_water_density_sub_viewport.size = low_res_size
	low_res_texture_rect.size = low_res_size
	low_res_color_rect.size = low_res_size
	water_sub_viewport.size = viewport_size
	upscaled_texture_rect.size = viewport_size
	
	glass.position = Vector2(0.8 * viewport_size_f.x, 0.4 * viewport_size_f.y)
	glass.rotation = -0.1 * PI
	glass.scale = Vector2(1.0, 1.5) * 0.75
	
	T_init = glass.get_global_transform()
	T_init_inverse = T_init.affine_inverse()
	
	#print_transforms_intuition()

	# because each frame we need to convert P'' to P' and vice-versa, we need to pass M to the compute shader each frame
	# but because we can move/rotate/scale as we like, M can be different each frame
	# below is the template that will be used in each frame to update M if some changes occur
	var T_new: Transform2D = glass.get_global_transform()
	var M: Transform2D = T_new * T_init_inverse
	M_X_x = M.x.x
	M_X_y = M.x.y
	M_Y_x = M.y.x
	M_Y_y = M.y.y
	M_origin_x = M.origin.x
	M_origin_y = M.origin.y
	
	# extract rotation part of the M transform (normalize columns)
	# this is because we transform positions using M but we also need to transform velocities (to reflect them off the object boundaries)
	# velocities transform differently than positions
	# in case of velocities we don't care about the origin (translation) and scaling
	# we only want to properly rotate them to preserve their lenghts
	# of course, to extract the rotation part out of M, we only need to get rid of scaling by normalizing (we also don't care about the origin)
	# this works assuming no shearing is contained within M
	var col_X: Vector2 = M.x.normalized()
	var col_Y: Vector2 = M.y.normalized()
	M_rotation_X_x = col_X.x
	M_rotation_X_y = col_X.y
	M_rotation_Y_x = col_Y.x
	M_rotation_Y_y = col_Y.y
	
	create_sdf_related_textures(false)

	init_gpu()
	
	verbose_particle_idx = randi() % particle_count
	
	var another_background_img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	another_background_img.fill(background_color)
	
	another_background_sprite_2d.texture = ImageTexture.create_from_image(another_background_img)
	another_background_sprite_2d.scale = Vector2(viewport_size.x, viewport_size.y)
	
	glass_sdf_img_texture_2drd = Texture2DRD.new()
	glass_sdf_img_texture_2drd.texture_rd_rid = glass_sdf_img_ren_texture_rid    # texture_2drd should automatically free ren_texture_rid
	glass_sdf_sprite_2d.texture = glass_sdf_img_texture_2drd
	
	glass_sdf_gradient_img_texture_2drd = Texture2DRD.new()
	glass_sdf_gradient_img_texture_2drd.texture_rd_rid = glass_sdf_gradient_img_ren_texture_rid    # texture_2drd should automatically free ren_texture_rid
	glass_sdf_gradient_sprite_2d.texture = glass_sdf_gradient_img_texture_2drd
	
	particle_pos_temp_img_texture_2drd = Texture2DRD.new()
	particle_pos_temp_img_texture_2drd.texture_rd_rid = particle_pos_temp_img_ren_texture_rid    # texture_2drd should automatically free ren_texture_rid
	
	gpu_particles_2d.process_material.set_shader_parameter("u_particle_pos_temp_img", particle_pos_temp_img_texture_2drd)
	gpu_particles_2d.process_material.set_shader_parameter("u_verbose_particle_color", Vector4(verbose_particle_color.r, verbose_particle_color.g, verbose_particle_color.b, verbose_particle_color.a))
	gpu_particles_2d.process_material.set_shader_parameter("u_neighbor_particle_color", Vector4(neighbor_particle_color.r, neighbor_particle_color.g, neighbor_particle_color.b, neighbor_particle_color.a))
	gpu_particles_2d.process_material.set_shader_parameter("u_n_to_v_scale_factor", normalized_to_viewport_scale_factor)
	gpu_particles_2d.amount = particle_count
	
	top_margin_container.visible = true
	bottom_margin_container.visible = false
	
	init_color_picker_button_callbacks()
	init_slider_callbacks()
	init_toggle_callbacks()
	
	for pcpb in get_tree().get_nodes_in_group("ParamColorPickerButton"):
		if pcpb is ColorPickerButton:
			# see the explanation below
			pcpb.color_changed.connect(Callable(self, "_on_colorpickerbuttonvalue_changed").bind(pcpb.name))
	
	for ps in get_tree().get_nodes_in_group("ParamSlider"):
		if ps is HSlider:
			# connect a new, separate version of the original callable to the signal emitted by a particular slider
			# each version of the original callable has a different, constant second paramater
			# this second parameter is bound to the original callable after the original call supplies the first parameter
			ps.value_changed.connect(Callable(self, "_on_slidervalue_changed").bind(ps.name))
	
	for pt in get_tree().get_nodes_in_group("ParamToggle"):
		if pt is CheckBox:
			# see the explanation above
			pt.toggled.connect(Callable(self, "_on_togglevalue_changed").bind(pt.name))
	
	reset_params()
	
	set_display()

func _process(delta: float) -> void:
	if not waiting_for_gpu:
		var adjusted_delta: float = delta * float(desired_waiting_frames + 1)
		
		# self-explanatory
		mouse_normalized_pos = get_global_mouse_position() * viewport_to_normalized_scale_factor
		
		# update glass transform → recompute M and M_rotation to pass them to the compute shader → do it once per frame instead of once per particle
		update_glass_transform(adjusted_delta)
		
		# prevent too large timestep (for stability purposes)
		run_gpu(min(adjusted_delta / sim_steps_per_frame_f, max_timestep), sim_steps_per_frame, (!bottom_margin_container.visible) and left_button_clicked)
		
		if desired_waiting_frames == 0:
			rd.sync()
		else:
			curr_waiting_frames += 1
			waiting_for_gpu = true
	else:
		if curr_waiting_frames == desired_waiting_frames:
			rd.sync()
			curr_waiting_frames = 0
			waiting_for_gpu = false
		else:
			curr_waiting_frames += 1
	
	gpu_particles_2d.process_material.set_shader_parameter("u_particle_color", Vector4(rt_particle_color.r, rt_particle_color.g, rt_particle_color.b, rt_particle_color.a))
	gpu_particles_2d.process_material.set_shader_parameter("u_particle_vis_size", rt_particle_vis_size)
	
	low_res_color_rect.material.set("shader_parameter/lod", rt_blur_amount)
	
	upscaled_texture_rect.material.set("shader_parameter/u_water_density_threshold", rt_water_density_threshold)
	upscaled_texture_rect.material.set("shader_parameter/u_edge_softness", rt_edge_softness)
	upscaled_texture_rect.material.set("shader_parameter/u_tint_threshold_min", rt_tint_threshold_min)
	upscaled_texture_rect.material.set("shader_parameter/u_tint_threshold_max", rt_tint_threshold_max)
	upscaled_texture_rect.material.set("shader_parameter/u_water_main_color", rt_water_main_color)
	upscaled_texture_rect.material.set("shader_parameter/u_water_tint_color", rt_water_tint_color)
	
	fps_label.text = str(Engine.get_frames_per_second()) + " FPS"

func _input(event: InputEvent) -> void:
	
	if event is InputEventMouseButton:
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			left_button_clicked = true
		else:
			left_button_clicked = false
			spawn_accumulator = 0.0
			prev_spawn_accumulator_int_part = 0
			curr_spawn_accumulator_int_part = 0
		
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			right_button_clicked = true
		else:
			right_button_clicked = false
		
		if event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			middle_button_clicked = true
		else:
			middle_button_clicked = false
	
	if event is InputEventKey:
		
		if event.pressed and event.keycode == KEY_LEFT:
			left_arrow_pressed = true
		else:
			left_arrow_pressed = false
		if event.pressed and event.keycode == KEY_RIGHT:
			right_arrow_pressed = true
		else:
			right_arrow_pressed = false
		if event.pressed and event.keycode == KEY_UP:
			up_arrow_pressed = true
		else:
			up_arrow_pressed = false
		if event.pressed and event.keycode == KEY_DOWN:
			down_arrow_pressed = true
		else:
			down_arrow_pressed = false
		if event.pressed and event.keycode == KEY_A:
			a_key_pressed = true
		else:
			a_key_pressed = false
		if event.pressed and event.keycode == KEY_D:
			d_key_pressed = true
		else:
			d_key_pressed = false
		if event.pressed and event.keycode == KEY_W:
			w_key_pressed = true
		else:
			w_key_pressed = false
		if event.pressed and event.keycode == KEY_S:
			s_key_pressed = true
		else:
			s_key_pressed = false
		
		if event.pressed and event.keycode == KEY_R:
			reset_params()
		if event.pressed and event.keycode == KEY_H:
			top_margin_container.visible = !top_margin_container.visible
		if event.pressed and event.keycode == KEY_T:
			bottom_margin_container.visible = !bottom_margin_container.visible
		
		if event.pressed and event.keycode == KEY_PERIOD:
			curr_display_idx = (curr_display_idx + 1) % textures.size()
			set_display()
		elif event.pressed and event.keycode == KEY_COMMA:
			curr_display_idx = (curr_display_idx - 1) % textures.size()
			set_display()
		
		if event.pressed and event.keycode == KEY_C:
			verbose_particle_idx = randi() % particle_count
			
			#run_gpu(1.0 / 120.0, 1, false)
			#
			#print("Positions: ", give_me_my_packedvector2array_xD(rd.buffer_get_data(positions_buffer_rid)).slice(0, 10))
			#print("Velocities: ", give_me_my_packedvector2array_xD(rd.buffer_get_data(velocities_buffer_rid)).slice(0, 10))
			#
			#print("Lifetimes: ", rd.buffer_get_data(lifetimes_buffer_rid).to_float32_array())
			#print("Ages: ", rd.buffer_get_data(ages_buffer_rid).to_float32_array())
			#print("Is alive: ", get_uint_arr(rd.buffer_get_data(is_alive_buffer_rid)))
			#print("Dead stack: ", get_uint_arr(rd.buffer_get_data(dead_stack_buffer_rid)))
			#print("Dead count: ", rd.buffer_get_data(dead_count_buffer_rid).to_int32_array())
			#
			#print("Hashes (unsorted): ", hashes_unsorted)
			#print("Particle indices (unsorted): ", particle_indices_unsorted)
			#print("Hashes (sorted): ", hashes_sorted)
			#print("Particle indices (sorted): ", particle_indices_sorted)
			#print("Start indices: ", get_uint_arr(rd.buffer_get_data(start_indices_buffer_rid)))
			#print("End indices: ", get_uint_arr(rd.buffer_get_data(end_indices_buffer_rid)))
			#print("Neighbor flags: ", get_uint_arr(rd.buffer_get_data(neighbor_flags_buffer_rid)))
			#
			#var densities_gpu: PackedFloat32Array = rd.buffer_get_data(densities_buffer_rid).to_float32_array()
			#print("Densities avg: ", average(densities_gpu))
			#print("Densities: ", densities_gpu.slice(0, 10))
			#
			#var pressures_gpu: PackedFloat32Array = rd.buffer_get_data(pressures_buffer_rid).to_float32_array()
			#print("Pressures avg: ", average(pressures_gpu))
			#print("Pressures: ", pressures_gpu.slice(0, 10))
			#
			#var near_densities_gpu: PackedFloat32Array = rd.buffer_get_data(near_densities_buffer_rid).to_float32_array()
			#print("Near densities avg: ", average(near_densities_gpu))
			#print("Near densities: ", near_densities_gpu.slice(0, 10))
			#
			#var near_pressures_gpu: PackedFloat32Array = rd.buffer_get_data(near_pressures_buffer_rid).to_float32_array()
			#print("Near pressures avg: ", average(near_pressures_gpu))
			#print("Near pressures: ", near_pressures_gpu.slice(0, 10))
			#
			#var vorticities_gpu: PackedFloat32Array = rd.buffer_get_data(vorticities_buffer_rid).to_float32_array()
			#print("Vorticities avg: ", average(vorticities_gpu))
			#print("Vorticities: ", vorticities_gpu.slice(0, 10))
			#
			#print("Forces: ", give_me_my_packedvector2array_xD(rd.buffer_get_data(forces_buffer_rid)).slice(0, 10))
			#
			#print()

func _exit_tree() -> void:
	free_gpu()

func init_general_predefined_variables() -> void:
	# commented variables are initialized in other parts of the code
	
	background_color = Color(0.0, 0.0, 0.0, 0.0)
	verbose_particle_color = Color(1.0, 0.0, 1.0, 1.0)
	neighbor_particle_color = Color(1.0, 1.0, 0.0, 1.0)
	
	normalized_sim_world_bounds_min = Vector2(0.0, 0.0)
	normalized_sim_world_bounds_max = Vector2(1.0, 1.0)
	
	normalized_to_viewport_scale_factor = Vector2(viewport_size.x, viewport_size.y)
	viewport_to_normalized_scale_factor = Vector2(1.0 / normalized_to_viewport_scale_factor.x, 1.0 / normalized_to_viewport_scale_factor.y)
	
	mass = rest_density * (particle_spacing * particle_spacing)
	smoothing_radius = particle_spacing * smoothing_radius_multiplier
	max_timestep = safety_courant_number * (smoothing_radius / sqrt(stiffness))
	
	poly6_2d_constant = 4.0 / (PI * pow(smoothing_radius, 8.0))
	spiky_2d_gradient_constant = -30.0 / (PI * pow(smoothing_radius, 5.0))
	visc_2d_laplacian_constant = 40.0 / (PI * pow(smoothing_radius, 5.0))
	
	gravity = Vector2(0.0, 9.81)
	
	particle_count = particle_grid_size.x * particle_grid_size.y
	
	particle_pos_temp_img_size = int(ceil(sqrt(particle_count)))
	glass_sdf_imgs_size = viewport_size
	
	viewport_size_f = Vector2(float(viewport_size.x), float(viewport_size.y))
	sim_steps_per_frame_f = float(sim_steps_per_frame)
	particle_grid_size_f = Vector2(float(particle_grid_size.x), float(particle_grid_size.y))
	particle_pos_temp_img_size_f = float(particle_pos_temp_img_size)
	glass_sdf_imgs_size_f = Vector2(float(glass_sdf_imgs_size.x), float(glass_sdf_imgs_size.y))
	
	verbose_particle_idx = -1
	
	mouse_normalized_pos = Vector2(-1.0, -1.0)
	
	left_button_clicked = false
	right_button_clicked = false
	middle_button_clicked = false
	
	left_arrow_pressed = false
	right_arrow_pressed = false
	up_arrow_pressed = false
	down_arrow_pressed = false
	
	a_key_pressed = false
	d_key_pressed = false
	w_key_pressed = false
	s_key_pressed = false
	
	waiting_for_gpu = false
	curr_waiting_frames = 0
	
	kill_particles_workgroup_size_x = 256    # should match local_size_x in the corresponding shader
	kill_particles_workgroups_x = int(ceil(particle_count / float(kill_particles_workgroup_size_x)))
	spawn_particles_workgroup_size_x = 256    # should match local_size_x in the corresponding shader
	#spawn_particles_workgroups_x
	compute_hashes_workgroup_size_x = kill_particles_workgroup_size_x
	compute_hashes_workgroups_x = kill_particles_workgroups_x
	range_start_end_workgroup_size_x = kill_particles_workgroup_size_x
	range_start_end_workgroups_x = kill_particles_workgroups_x
	compute_densities_workgroup_size_x = kill_particles_workgroup_size_x
	compute_densities_workgroups_x = kill_particles_workgroups_x
	compute_pressures_workgroup_size_x = kill_particles_workgroup_size_x
	compute_pressures_workgroups_x = kill_particles_workgroups_x
	compute_vorticities_workgroup_size_x = kill_particles_workgroup_size_x
	compute_vorticities_workgroups_x = kill_particles_workgroups_x
	compute_forces_workgroup_size_x = kill_particles_workgroup_size_x
	compute_forces_workgroups_x = kill_particles_workgroups_x
	integrate_motion_workgroup_size_x = kill_particles_workgroup_size_x
	integrate_motion_workgroups_x = kill_particles_workgroups_x
	store_neighbors_workgroup_size_x = kill_particles_workgroup_size_x
	store_neighbors_workgroups_x = kill_particles_workgroups_x
	mark_neighbors_workgroup_size_x = kill_particles_workgroup_size_x
	mark_neighbors_workgroups_x = kill_particles_workgroups_x
	
	positions_size = particle_count
	velocities_size = positions_size
	temperatures_size = positions_size
	lifetimes_size = positions_size
	ages_size = positions_size
	is_alive_size = positions_size
	dead_stack_size = positions_size    # this is actually the maximum POSSIBLE stack size
	hashes_size = positions_size    # number of grid cells = number of particles, collisions expected
	particle_indices_size = positions_size
	start_indices_size = positions_size
	end_indices_size = positions_size
	densities_size = positions_size
	pressures_size = positions_size
	near_densities_size = positions_size
	near_pressures_size = positions_size
	vorticities_size = positions_size
	forces_size = positions_size
	neighbor_flags_size = positions_size
	
	#glass_sdf_img
	#glass_sdf_gradient_img
	
	#M_X_x
	#M_X_y
	#M_Y_x
	#M_Y_y
	#M_origin_x
	#M_origin_y
	
	#M_rotation_X_x
	#M_rotation_X_y
	#M_rotation_Y_x
	#M_rotation_Y_y
	
	#T_init
	#T_init_inverse    # necessary for computing M and M_rotation each frame
	
	mortal_particle_count = int(round(mortal_particles_amount * particle_count))
	immortal_particle_count = particle_count - mortal_particle_count
	init_alive_mortal_particle_count = int(round(init_alive_mortal_particles_amount * mortal_particle_count))
	init_dead_mortal_particle_count = mortal_particle_count - init_alive_mortal_particle_count
	init_alive_immortal_particle_count = int(round(init_alive_immortal_particles_amount * immortal_particle_count))
	init_dead_immortal_particle_count = immortal_particle_count - init_alive_immortal_particle_count
	init_dead_particle_count = init_dead_mortal_particle_count + init_dead_immortal_particle_count
	
	spawn_accumulator = 0.0
	prev_spawn_accumulator_int_part = 0
	curr_spawn_accumulator_int_part = 0
	spawn_count = 0
	spawn_grid_size = 0
	spawn_random_offset = Vector2(0, 0)    # in particle_spacing units
	
	rt_water_main_color = water_main_color
	rt_water_tint_color = water_tint_color
	rt_particle_color = particle_color
	rt_particle_vis_size = particle_vis_size
	rt_rest_density = rest_density
	rt_stiffness = stiffness
	rt_stiffness_near = stiffness_near
	rt_viscosity_scale = viscosity_scale
	rt_xsph_scale = xsph_scale
	rt_vorticity_scale = vorticity_scale
	rt_surface_tension_threshold = surface_tension_threshold
	rt_surface_tension_scale = surface_tension_scale
	rt_adhesion_threshold = adhesion_threshold
	rt_adhesion_scale = adhesion_scale
	rt_gravity_multiplier = gravity_multiplier
	rt_damping = damping
	rt_bounds_damping = bounds_damping
	rt_vel_clamp = vel_clamp
	rt_mouse_interaction_radius = mouse_interaction_radius
	rt_mouse_interaction_strength = mouse_interaction_strength
	rt_glass_movement_speed = glass_movement_speed
	rt_glass_rotation_speed = glass_rotation_speed
	rt_glass_scaling_speed = glass_scaling_speed
	rt_spawn_rate = spawn_rate
	rt_spawn_random_offset_range = spawn_random_offset_range
	rt_spawn_init_vel = spawn_init_vel
	rt_blur_amount = blur_amount
	rt_water_density_threshold = water_density_threshold
	rt_edge_softness = edge_softness
	rt_tint_threshold_min = tint_threshold_min
	rt_tint_threshold_max = tint_threshold_max
	rt_vis_neighborhood_search = vis_neighborhood_search
	
	color_picker_button_callbacks_dict = {}
	slider_callbacks_dict = {}
	toggle_callbacks_dict = {}
	
	curr_display_idx = 2

func init_parallel_radix_sort_predefined_variables() -> void:
	histogram_workgroup_size_x = 256    # should match local_size_x in histogram.glsl shader
	histogram_workgroups_x = int(ceil(float(hashes_size) / histogram_workgroup_size_x))    # very important variable
	
	digit_num_bits = 4    # in this version we consider a "digit" to be a group of 4 bits
	num_digits = 16    # num_digits = 2^(digit_num_bits) = 2^4 = 16
	
	digits_times_groups = num_digits * histogram_workgroups_x    # total entries in [group][digit] 2D arrays used in shaders
	
	counts_per_digit_workgroup_size_x = num_digits    # 16 in our version
	counts_per_digit_workgroups_x = 1
	
	pps16_workgroup_size_x = num_digits >> 1    # 8 in our version
	pps16_workgroups_x = 1
	
	scan_per_digit_workgroup_size_x = num_digits    # 16 in our version
	scan_per_digit_workgroups_x = 1
	
	combine_offsets_workgroup_size_x = 256    # should match local_size_x in combine-offsets.glsl shader
	combine_offsets_workgroups_x = int(ceil(float(digits_times_groups) / combine_offsets_workgroup_size_x))
	
	scatter_workgroup_size_x = histogram_workgroup_size_x    # these two should always match
	scatter_workgroups_x = histogram_workgroups_x    # these two should always match
	
	group_histograms_size = digits_times_groups    # size of array computed in histogram.glsl
	digit_totals_size = num_digits    # size of array computed in counts-per-digit.glsl
	digit_totals_after_scan_size = digit_totals_size    # size of array computed in pps16.glsl
	prefix_groups_size = group_histograms_size    # size of array computed in scan-per-digit.glsl
	group_offsets_size = group_histograms_size    # size of array computed in combine-offsets.glsl

func init_gpu() -> void:
	# create a local rendering device
	# get also a global rendering device needed for displaying GPU textures on GPUParticles2D
	rd = RenderingServer.create_local_rendering_device()
	ren_rd = RenderingServer.get_rendering_device()
	
	#region shaders
	var kill_particles_shader_file = load("res://Compute Shaders/Water/kill-particles.glsl")
	var kill_particles_shader_spirv = kill_particles_shader_file.get_spirv()
	kill_particles_shader_rid = rd.shader_create_from_spirv(kill_particles_shader_spirv)
	
	var spawn_particles_shader_file = load("res://Compute Shaders/Water/spawn-particles.glsl")
	var spawn_particles_shader_spirv = spawn_particles_shader_file.get_spirv()
	spawn_particles_shader_rid = rd.shader_create_from_spirv(spawn_particles_shader_spirv)
	
	var compute_hashes_shader_file = load("res://Compute Shaders/Water/compute-hashes.glsl")
	var compute_hashes_shader_spirv = compute_hashes_shader_file.get_spirv()
	compute_hashes_shader_rid = rd.shader_create_from_spirv(compute_hashes_shader_spirv)
	
	#region parallel radix sort shaders
	var histogram_shader_file = load("res://Compute Shaders/Water/histogram.glsl")
	var histogram_shader_spirv = histogram_shader_file.get_spirv()
	histogram_shader_rid = rd.shader_create_from_spirv(histogram_shader_spirv)
	
	var counts_per_digit_shader_file = load("res://Compute Shaders/Water/counts-per-digit.glsl")
	var counts_per_digit_shader_spirv = counts_per_digit_shader_file.get_spirv()
	counts_per_digit_shader_rid = rd.shader_create_from_spirv(counts_per_digit_shader_spirv)
	
	var pps16_shader_file = load("res://Compute Shaders/Water/pps16.glsl")
	var pps16_shader_spirv = pps16_shader_file.get_spirv()
	pps16_shader_rid = rd.shader_create_from_spirv(pps16_shader_spirv)
	
	var scan_per_digit_shader_file = load("res://Compute Shaders/Water/scan-per-digit.glsl")
	var scan_per_digit_shader_spirv = scan_per_digit_shader_file.get_spirv()
	scan_per_digit_shader_rid = rd.shader_create_from_spirv(scan_per_digit_shader_spirv)
	
	var combine_offsets_shader_file = load("res://Compute Shaders/Water/combine-offsets.glsl")
	var combine_offsets_shader_spirv = combine_offsets_shader_file.get_spirv()
	combine_offsets_shader_rid = rd.shader_create_from_spirv(combine_offsets_shader_spirv)
	
	var scatter_shader_file = load("res://Compute Shaders/Water/scatter.glsl")
	var scatter_shader_spirv = scatter_shader_file.get_spirv()
	scatter_shader_rid = rd.shader_create_from_spirv(scatter_shader_spirv)
	#endregion
	
	var range_start_end_shader_file = load("res://Compute Shaders/Water/range-start-end.glsl")
	var range_start_end_shader_spirv = range_start_end_shader_file.get_spirv()
	range_start_end_shader_rid = rd.shader_create_from_spirv(range_start_end_shader_spirv)
	
	var compute_densities_shader_file = load("res://Compute Shaders/Water/compute-densities.glsl")
	var compute_densities_shader_spirv = compute_densities_shader_file.get_spirv()
	compute_densities_shader_rid = rd.shader_create_from_spirv(compute_densities_shader_spirv)
	
	var compute_pressures_shader_file = load("res://Compute Shaders/Water/compute-pressures.glsl")
	var compute_pressures_shader_spirv = compute_pressures_shader_file.get_spirv()
	compute_pressures_shader_rid = rd.shader_create_from_spirv(compute_pressures_shader_spirv)
	
	var compute_vorticities_shader_file = load("res://Compute Shaders/Water/compute-vorticities.glsl")
	var compute_vorticities_shader_spirv = compute_vorticities_shader_file.get_spirv()
	compute_vorticities_shader_rid = rd.shader_create_from_spirv(compute_vorticities_shader_spirv)
	
	var compute_forces_shader_file = load("res://Compute Shaders/Water/compute-forces.glsl")
	var compute_forces_shader_spirv = compute_forces_shader_file.get_spirv()
	compute_forces_shader_rid = rd.shader_create_from_spirv(compute_forces_shader_spirv)
	
	var integrate_motion_shader_file = load("res://Compute Shaders/Water/integrate-motion.glsl")
	var integrate_motion_shader_spirv = integrate_motion_shader_file.get_spirv()
	integrate_motion_shader_rid = rd.shader_create_from_spirv(integrate_motion_shader_spirv)
	
	var store_neighbors_shader_file = load("res://Compute Shaders/Water/store-neighbors.glsl")
	var store_neighbors_shader_spirv = store_neighbors_shader_file.get_spirv()
	store_neighbors_shader_rid = rd.shader_create_from_spirv(store_neighbors_shader_spirv)
	
	var mark_neighbors_shader_file = load("res://Compute Shaders/Water/mark-neighbors.glsl")
	var mark_neighbors_shader_spirv = mark_neighbors_shader_file.get_spirv()
	mark_neighbors_shader_rid = rd.shader_create_from_spirv(mark_neighbors_shader_spirv)
	#endregion
	
	#region bytes
	# packed byte arrays are used to initialize the GPU buffers with some data (bytes)
	# we don't create positions_bytes right away because we still need to alter the positions of dead particles (we'll move them outside the simulation domain)
	# let's assume this initialization order: [ immortal alive ][ immortal dead ][ mortal alive ][ mortal dead ] (this is actually flattenned, in reality particles are initialized in a grid)
	
	var positions: PackedVector2Array = PackedVector2Array()
	for i in particle_grid_size.x:
		for j in particle_grid_size.y:
			positions.append(init_grid_top_left_corner + (Vector2(i, j) * particle_spacing))
	
	var velocities: PackedVector2Array = PackedVector2Array()
	for i in velocities_size:
		velocities.append(Vector2(0.0, 0.0))
	var velocities_bytes: PackedByteArray = velocities.to_byte_array()
	
	var temperatures: PackedFloat32Array = PackedFloat32Array()
	temperatures.resize(temperatures_size)
	temperatures.fill(0.0)
	var temperatures_bytes: PackedByteArray = temperatures.to_byte_array()
	
	var lifetimes: PackedFloat32Array = PackedFloat32Array()
	for i in lifetimes_size:
		if i < immortal_particle_count:
			# immortal particles
			lifetimes.append(INF)
		else:
			# mortal particles
			lifetimes.append(randf_range(mortal_particle_lifetime_min, mortal_particle_lifetime_max))
	var lifetimes_bytes: PackedByteArray = lifetimes.to_byte_array()
	
	var ages: PackedFloat32Array = PackedFloat32Array()
	ages.resize(ages_size)
	ages.fill(0.0)
	var ages_bytes: PackedByteArray = ages.to_byte_array()
	
	var is_alive: PackedInt32Array = PackedInt32Array()
	for i in is_alive_size:
		if i < immortal_particle_count:
			# immortal particles
			if i < init_alive_immortal_particle_count:
				# initially alive
				is_alive.append(1)
			else:
				# initially dead
				is_alive.append(0)
		else:
			# mortal particles
			if (i - immortal_particle_count) < init_alive_mortal_particle_count:
				# initially alive
				is_alive.append(1)
			else:
				# initially dead
				is_alive.append(0)
	var is_alive_bytes: PackedByteArray = get_uint_packed_byte_array(is_alive)
	
	var dead_stack: Array[int] = []
	dead_stack.resize(dead_stack_size)
	dead_stack.fill(particle_count)    # invalid particle indices (garbage values)
	
	var push_idx: int = 0
	var total_dead_counter: int = 0
	
	for i in is_alive_size:
		if is_alive[i] == 0:
			dead_stack[push_idx] = i
			push_idx += 1
			total_dead_counter += 1
			positions[i] = Vector2(2.0 + (randf() * 10.0), 2.0 + (randf() * 10.0))    # move outside the simualation domain
	
	var dead_stack_bytes: PackedByteArray = get_uint_packed_byte_array(dead_stack)
	
	var positions_bytes: PackedByteArray = positions.to_byte_array()
	
	print("{0}\n".format([total_dead_counter == init_dead_particle_count]))
	
	var dead_count: int = init_dead_particle_count
	var dead_count_bytes: PackedByteArray
	dead_count_bytes.resize(4)
	dead_count_bytes.fill(0)
	dead_count_bytes.encode_s32(0, dead_count)
	
	var hashes_1: Array[int] = []
	hashes_1.resize(hashes_size)
	hashes_1.fill(particle_count)    # invalid hash (hashes are in the range [0, particle_count-1])
	var hashes_1_bytes: PackedByteArray = get_uint_packed_byte_array(hashes_1)
	
	var hashes_2: Array[int] = hashes_1.duplicate()    # ping-pong
	var hashes_2_bytes: PackedByteArray = get_uint_packed_byte_array(hashes_2)    # ping-pong
	
	var particle_indices_1: Array[int] = []
	particle_indices_1.resize(particle_indices_size)
	particle_indices_1.fill(particle_count)    # invalid index (indices are in the range [0, particle_count-1])
	var particle_indices_1_bytes: PackedByteArray = get_uint_packed_byte_array(particle_indices_1)
	
	var particle_indices_2: Array[int] = particle_indices_1.duplicate()    # ping-pong
	var particle_indices_2_bytes: PackedByteArray = get_uint_packed_byte_array(particle_indices_2)    # ping-pong
	
	#region parallel radix sort bytes
	var group_histograms: Array[int] = []
	group_histograms.resize(group_histograms_size)
	group_histograms.fill(0)
	var group_histograms_bytes: PackedByteArray = get_uint_packed_byte_array(group_histograms)
	
	var digit_totals: Array[int] = []
	digit_totals.resize(digit_totals_size)
	digit_totals.fill(0)
	var digit_totals_bytes: PackedByteArray = get_uint_packed_byte_array(digit_totals)
	
	var digit_totals_after_scan: Array[int] = []
	digit_totals_after_scan.resize(digit_totals_after_scan_size)
	digit_totals_after_scan.fill(0)
	var digit_totals_after_scan_bytes: PackedByteArray = get_uint_packed_byte_array(digit_totals_after_scan)
	
	var prefix_groups: Array[int] = []
	prefix_groups.resize(prefix_groups_size)
	prefix_groups.fill(0)
	var prefix_groups_bytes: PackedByteArray = get_uint_packed_byte_array(prefix_groups)
	
	var group_offsets: Array[int] = []
	group_offsets.resize(group_offsets_size)
	group_offsets.fill(0)
	var group_offsets_bytes: PackedByteArray = get_uint_packed_byte_array(group_offsets)
	#endregion
	
	var start_indices: Array[int] = []
	start_indices.resize(start_indices_size)
	start_indices.fill(particle_count)    # invalid start index (outside of array's range)
	var start_indices_bytes: PackedByteArray = get_uint_packed_byte_array(start_indices)
	
	var end_indices: Array[int] = []
	end_indices.resize(end_indices_size)
	end_indices.fill(0)    # invalid end index (should always be one past some other, existing index, -1 doesn't exist in case of 0)
	var end_indices_bytes: PackedByteArray = get_uint_packed_byte_array(end_indices)
	
	var densities: PackedFloat32Array = PackedFloat32Array()
	densities.resize(densities_size)
	densities.fill(rest_density)
	var densities_bytes: PackedByteArray = densities.to_byte_array()
	
	var pressures: PackedFloat32Array = PackedFloat32Array()
	pressures.resize(pressures_size)
	pressures.fill(0.0)
	var pressures_bytes: PackedByteArray = pressures.to_byte_array()
	
	var near_densities: PackedFloat32Array = PackedFloat32Array()
	near_densities.resize(near_densities_size)
	near_densities.fill(rest_density)
	var near_densities_bytes: PackedByteArray = near_densities.to_byte_array()
	
	var near_pressures: PackedFloat32Array = PackedFloat32Array()
	near_pressures.resize(near_pressures_size)
	near_pressures.fill(0.0)
	var near_pressures_bytes: PackedByteArray = near_pressures.to_byte_array()
	
	var vorticities: PackedFloat32Array = PackedFloat32Array()
	vorticities.resize(vorticities_size)
	vorticities.fill(0.0)
	var vorticities_bytes: PackedByteArray = vorticities.to_byte_array()
	
	var forces: PackedVector2Array = PackedVector2Array()
	for i in forces_size:
		forces.append(Vector2(0.0, 0.0))
	var forces_bytes: PackedByteArray = forces.to_byte_array()
	
	var neighbor_flags: Array[int] = []
	neighbor_flags.resize(neighbor_flags_size)
	neighbor_flags.fill(0)
	var neighbor_flags_bytes: PackedByteArray = get_uint_packed_byte_array(neighbor_flags)
	#endregion
	
	#region buffers
	positions_buffer_rid = rd.storage_buffer_create(positions_bytes.size(), positions_bytes)
	velocities_buffer_rid = rd.storage_buffer_create(velocities_bytes.size(), velocities_bytes)
	temperatures_buffer_rid = rd.storage_buffer_create(temperatures_bytes.size(), temperatures_bytes)
	lifetimes_buffer_rid = rd.storage_buffer_create(lifetimes_bytes.size(), lifetimes_bytes)
	ages_buffer_rid = rd.storage_buffer_create(ages_bytes.size(), ages_bytes)
	is_alive_buffer_rid = rd.storage_buffer_create(is_alive_bytes.size(), is_alive_bytes)
	dead_stack_buffer_rid = rd.storage_buffer_create(dead_stack_bytes.size(), dead_stack_bytes)
	dead_count_buffer_rid = rd.storage_buffer_create(dead_count_bytes.size(), dead_count_bytes)
	hashes_1_buffer_rid = rd.storage_buffer_create(hashes_1_bytes.size(), hashes_1_bytes)
	hashes_2_buffer_rid = rd.storage_buffer_create(hashes_2_bytes.size(), hashes_2_bytes)
	particle_indices_1_buffer_rid = rd.storage_buffer_create(particle_indices_1_bytes.size(), particle_indices_1_bytes)
	particle_indices_2_buffer_rid = rd.storage_buffer_create(particle_indices_2_bytes.size(), particle_indices_2_bytes)
	
	#region parallel radix sort buffers
	group_histograms_buffer_rid = rd.storage_buffer_create(group_histograms_bytes.size(), group_histograms_bytes)
	digit_totals_buffer_rid = rd.storage_buffer_create(digit_totals_bytes.size(), digit_totals_bytes)
	digit_totals_after_scan_buffer_rid = rd.storage_buffer_create(digit_totals_after_scan_bytes.size(), digit_totals_after_scan_bytes)
	prefix_groups_buffer_rid = rd.storage_buffer_create(prefix_groups_bytes.size(), prefix_groups_bytes)
	group_offsets_buffer_rid = rd.storage_buffer_create(group_offsets_bytes.size(), group_offsets_bytes)
	#endregion
	
	start_indices_buffer_rid = rd.storage_buffer_create(start_indices_bytes.size(), start_indices_bytes)
	end_indices_buffer_rid = rd.storage_buffer_create(end_indices_bytes.size(), end_indices_bytes)
	densities_buffer_rid = rd.storage_buffer_create(densities_bytes.size(), densities_bytes)
	pressures_buffer_rid = rd.storage_buffer_create(pressures_bytes.size(), pressures_bytes)
	near_densities_buffer_rid = rd.storage_buffer_create(near_densities_bytes.size(), near_densities_bytes)
	near_pressures_buffer_rid = rd.storage_buffer_create(near_pressures_bytes.size(), near_pressures_bytes)
	vorticities_buffer_rid = rd.storage_buffer_create(vorticities_bytes.size(), vorticities_bytes)
	forces_buffer_rid = rd.storage_buffer_create(forces_bytes.size(), forces_bytes)
	neighbor_flags_buffer_rid = rd.storage_buffer_create(neighbor_flags_bytes.size(), neighbor_flags_bytes)
	#endregion
	
	#region uniforms
	kill_particles_positions_uniform = RDUniform.new()
	kill_particles_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_positions_uniform.binding = 0
	kill_particles_positions_uniform.add_id(positions_buffer_rid)
	kill_particles_velocities_uniform = RDUniform.new()
	kill_particles_velocities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_velocities_uniform.binding = 1
	kill_particles_velocities_uniform.add_id(velocities_buffer_rid)
	kill_particles_lifetimes_uniform = RDUniform.new()
	kill_particles_lifetimes_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_lifetimes_uniform.binding = 2
	kill_particles_lifetimes_uniform.add_id(lifetimes_buffer_rid)
	kill_particles_ages_uniform = RDUniform.new()
	kill_particles_ages_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_ages_uniform.binding = 3
	kill_particles_ages_uniform.add_id(ages_buffer_rid)
	kill_particles_is_alive_uniform = RDUniform.new()
	kill_particles_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_is_alive_uniform.binding = 4
	kill_particles_is_alive_uniform.add_id(is_alive_buffer_rid)
	kill_particles_dead_stack_uniform = RDUniform.new()
	kill_particles_dead_stack_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_dead_stack_uniform.binding = 5
	kill_particles_dead_stack_uniform.add_id(dead_stack_buffer_rid)
	kill_particles_dead_count_uniform = RDUniform.new()
	kill_particles_dead_count_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	kill_particles_dead_count_uniform.binding = 6
	kill_particles_dead_count_uniform.add_id(dead_count_buffer_rid)
	spawn_particles_positions_uniform = RDUniform.new()
	spawn_particles_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spawn_particles_positions_uniform.binding = 0
	spawn_particles_positions_uniform.add_id(positions_buffer_rid)
	spawn_particles_velocities_uniform = RDUniform.new()
	spawn_particles_velocities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spawn_particles_velocities_uniform.binding = 1
	spawn_particles_velocities_uniform.add_id(velocities_buffer_rid)
	spawn_particles_ages_uniform = RDUniform.new()
	spawn_particles_ages_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spawn_particles_ages_uniform.binding = 2
	spawn_particles_ages_uniform.add_id(ages_buffer_rid)
	spawn_particles_is_alive_uniform = RDUniform.new()
	spawn_particles_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spawn_particles_is_alive_uniform.binding = 3
	spawn_particles_is_alive_uniform.add_id(is_alive_buffer_rid)
	spawn_particles_dead_stack_uniform = RDUniform.new()
	spawn_particles_dead_stack_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spawn_particles_dead_stack_uniform.binding = 4
	spawn_particles_dead_stack_uniform.add_id(dead_stack_buffer_rid)
	spawn_particles_dead_count_uniform = RDUniform.new()
	spawn_particles_dead_count_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spawn_particles_dead_count_uniform.binding = 5
	spawn_particles_dead_count_uniform.add_id(dead_count_buffer_rid)
	compute_hashes_positions_uniform = RDUniform.new()
	compute_hashes_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_hashes_positions_uniform.binding = 0
	compute_hashes_positions_uniform.add_id(positions_buffer_rid)
	compute_hashes_hashes_uniform = RDUniform.new()
	compute_hashes_hashes_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_hashes_hashes_uniform.binding = 1
	compute_hashes_hashes_uniform.add_id(hashes_1_buffer_rid)
	compute_hashes_particle_indices_uniform = RDUniform.new()
	compute_hashes_particle_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_hashes_particle_indices_uniform.binding = 2
	compute_hashes_particle_indices_uniform.add_id(particle_indices_1_buffer_rid)
	
	#region parallel radix sort uniforms
	histogram_keys_in_1_uniform = RDUniform.new()    # ping-pong
	histogram_keys_in_1_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	histogram_keys_in_1_uniform.binding = 0
	histogram_keys_in_1_uniform.add_id(hashes_1_buffer_rid)
	histogram_keys_in_2_uniform = RDUniform.new()    # ping-pong
	histogram_keys_in_2_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	histogram_keys_in_2_uniform.binding = 0
	histogram_keys_in_2_uniform.add_id(hashes_2_buffer_rid)
	histogram_group_histograms_uniform = RDUniform.new()
	histogram_group_histograms_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	histogram_group_histograms_uniform.binding = 1
	histogram_group_histograms_uniform.add_id(group_histograms_buffer_rid)
	counts_per_digit_group_histograms_uniform = RDUniform.new()
	counts_per_digit_group_histograms_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	counts_per_digit_group_histograms_uniform.binding = 0
	counts_per_digit_group_histograms_uniform.add_id(group_histograms_buffer_rid)
	counts_per_digit_digit_totals_uniform = RDUniform.new()
	counts_per_digit_digit_totals_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	counts_per_digit_digit_totals_uniform.binding = 1
	counts_per_digit_digit_totals_uniform.add_id(digit_totals_buffer_rid)
	pps16_inputtt_uniform = RDUniform.new()
	pps16_inputtt_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pps16_inputtt_uniform.binding = 0
	pps16_inputtt_uniform.add_id(digit_totals_buffer_rid)
	pps16_outputtt_uniform = RDUniform.new()
	pps16_outputtt_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pps16_outputtt_uniform.binding = 1
	pps16_outputtt_uniform.add_id(digit_totals_after_scan_buffer_rid)
	scan_per_digit_group_histograms_uniform = RDUniform.new()
	scan_per_digit_group_histograms_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scan_per_digit_group_histograms_uniform.binding = 0
	scan_per_digit_group_histograms_uniform.add_id(group_histograms_buffer_rid)
	scan_per_digit_prefix_groups_uniform = RDUniform.new()
	scan_per_digit_prefix_groups_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scan_per_digit_prefix_groups_uniform.binding = 1
	scan_per_digit_prefix_groups_uniform.add_id(prefix_groups_buffer_rid)
	combine_offsets_digit_totals_after_scan_uniform = RDUniform.new()
	combine_offsets_digit_totals_after_scan_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	combine_offsets_digit_totals_after_scan_uniform.binding = 0
	combine_offsets_digit_totals_after_scan_uniform.add_id(digit_totals_after_scan_buffer_rid)
	combine_offsets_prefix_groups_uniform = RDUniform.new()
	combine_offsets_prefix_groups_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	combine_offsets_prefix_groups_uniform.binding = 1
	combine_offsets_prefix_groups_uniform.add_id(prefix_groups_buffer_rid)
	combine_offsets_group_offsets_uniform = RDUniform.new()
	combine_offsets_group_offsets_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	combine_offsets_group_offsets_uniform.binding = 2
	combine_offsets_group_offsets_uniform.add_id(group_offsets_buffer_rid)
	scatter_keys_in_1_uniform = RDUniform.new()    # ping-pong
	scatter_keys_in_1_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_keys_in_1_uniform.binding = 0
	scatter_keys_in_1_uniform.add_id(hashes_1_buffer_rid)
	scatter_keys_in_2_uniform = RDUniform.new()    # ping-pong
	scatter_keys_in_2_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_keys_in_2_uniform.binding = 0
	scatter_keys_in_2_uniform.add_id(hashes_2_buffer_rid)
	scatter_keys_out_1_uniform = RDUniform.new()    # ping-pong
	scatter_keys_out_1_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_keys_out_1_uniform.binding = 1
	scatter_keys_out_1_uniform.add_id(hashes_2_buffer_rid)
	scatter_keys_out_2_uniform = RDUniform.new()    # ping-pong
	scatter_keys_out_2_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_keys_out_2_uniform.binding = 1
	scatter_keys_out_2_uniform.add_id(hashes_1_buffer_rid)
	scatter_group_offsets_uniform = RDUniform.new()
	scatter_group_offsets_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_group_offsets_uniform.binding = 2
	scatter_group_offsets_uniform.add_id(group_offsets_buffer_rid)
	scatter_values_in_1_uniform = RDUniform.new()    # ping-pong
	scatter_values_in_1_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_values_in_1_uniform.binding = 3
	scatter_values_in_1_uniform.add_id(particle_indices_1_buffer_rid)
	scatter_values_in_2_uniform = RDUniform.new()    # ping-pong
	scatter_values_in_2_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_values_in_2_uniform.binding = 3
	scatter_values_in_2_uniform.add_id(particle_indices_2_buffer_rid)
	scatter_values_out_1_uniform = RDUniform.new()    # ping-pong
	scatter_values_out_1_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_values_out_1_uniform.binding = 4
	scatter_values_out_1_uniform.add_id(particle_indices_2_buffer_rid)
	scatter_values_out_2_uniform = RDUniform.new()    # ping-pong
	scatter_values_out_2_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	scatter_values_out_2_uniform.binding = 4
	scatter_values_out_2_uniform.add_id(particle_indices_1_buffer_rid)
	#endregion
	
	range_start_end_hashes_uniform = RDUniform.new()
	range_start_end_hashes_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	range_start_end_hashes_uniform.binding = 0
	range_start_end_hashes_uniform.add_id(hashes_1_buffer_rid)
	range_start_end_start_indices_uniform = RDUniform.new()
	range_start_end_start_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	range_start_end_start_indices_uniform.binding = 1
	range_start_end_start_indices_uniform.add_id(start_indices_buffer_rid)
	range_start_end_end_indices_uniform = RDUniform.new()
	range_start_end_end_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	range_start_end_end_indices_uniform.binding = 2
	range_start_end_end_indices_uniform.add_id(end_indices_buffer_rid)
	compute_densities_positions_uniform = RDUniform.new()
	compute_densities_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_positions_uniform.binding = 0
	compute_densities_positions_uniform.add_id(positions_buffer_rid)
	compute_densities_sorted_particle_indices_uniform = RDUniform.new()
	compute_densities_sorted_particle_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_sorted_particle_indices_uniform.binding = 1
	compute_densities_sorted_particle_indices_uniform.add_id(particle_indices_1_buffer_rid)
	compute_densities_start_indices_uniform = RDUniform.new()
	compute_densities_start_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_start_indices_uniform.binding = 2
	compute_densities_start_indices_uniform.add_id(start_indices_buffer_rid)
	compute_densities_end_indices_uniform = RDUniform.new()
	compute_densities_end_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_end_indices_uniform.binding = 3
	compute_densities_end_indices_uniform.add_id(end_indices_buffer_rid)
	compute_densities_densities_uniform = RDUniform.new()
	compute_densities_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_densities_uniform.binding = 4
	compute_densities_densities_uniform.add_id(densities_buffer_rid)
	compute_densities_near_densities_uniform = RDUniform.new()
	compute_densities_near_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_near_densities_uniform.binding = 5
	compute_densities_near_densities_uniform.add_id(near_densities_buffer_rid)
	compute_densities_is_alive_uniform = RDUniform.new()
	compute_densities_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_densities_is_alive_uniform.binding = 6
	compute_densities_is_alive_uniform.add_id(is_alive_buffer_rid)
	compute_pressures_densities_uniform = RDUniform.new()
	compute_pressures_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_pressures_densities_uniform.binding = 0
	compute_pressures_densities_uniform.add_id(densities_buffer_rid)
	compute_pressures_pressures_uniform = RDUniform.new()
	compute_pressures_pressures_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_pressures_pressures_uniform.binding = 1
	compute_pressures_pressures_uniform.add_id(pressures_buffer_rid)
	compute_pressures_near_densities_uniform = RDUniform.new()
	compute_pressures_near_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_pressures_near_densities_uniform.binding = 2
	compute_pressures_near_densities_uniform.add_id(near_densities_buffer_rid)
	compute_pressures_near_pressures_uniform = RDUniform.new()
	compute_pressures_near_pressures_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_pressures_near_pressures_uniform.binding = 3
	compute_pressures_near_pressures_uniform.add_id(near_pressures_buffer_rid)
	compute_pressures_is_alive_uniform = RDUniform.new()
	compute_pressures_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_pressures_is_alive_uniform.binding = 4
	compute_pressures_is_alive_uniform.add_id(is_alive_buffer_rid)
	compute_vorticities_positions_uniform = RDUniform.new()
	compute_vorticities_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_positions_uniform.binding = 0
	compute_vorticities_positions_uniform.add_id(positions_buffer_rid)
	compute_vorticities_sorted_particle_indices_uniform = RDUniform.new()
	compute_vorticities_sorted_particle_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_sorted_particle_indices_uniform.binding = 1
	compute_vorticities_sorted_particle_indices_uniform.add_id(particle_indices_1_buffer_rid)
	compute_vorticities_start_indices_uniform = RDUniform.new()
	compute_vorticities_start_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_start_indices_uniform.binding = 2
	compute_vorticities_start_indices_uniform.add_id(start_indices_buffer_rid)
	compute_vorticities_end_indices_uniform = RDUniform.new()
	compute_vorticities_end_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_end_indices_uniform.binding = 3
	compute_vorticities_end_indices_uniform.add_id(end_indices_buffer_rid)
	compute_vorticities_densities_uniform = RDUniform.new()
	compute_vorticities_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_densities_uniform.binding = 4
	compute_vorticities_densities_uniform.add_id(densities_buffer_rid)
	compute_vorticities_velocities_uniform = RDUniform.new()
	compute_vorticities_velocities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_velocities_uniform.binding = 5
	compute_vorticities_velocities_uniform.add_id(velocities_buffer_rid)
	compute_vorticities_vorticities_uniform = RDUniform.new()
	compute_vorticities_vorticities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_vorticities_uniform.binding = 6
	compute_vorticities_vorticities_uniform.add_id(vorticities_buffer_rid)
	compute_vorticities_is_alive_uniform = RDUniform.new()
	compute_vorticities_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_vorticities_is_alive_uniform.binding = 7
	compute_vorticities_is_alive_uniform.add_id(is_alive_buffer_rid)
	compute_forces_positions_uniform = RDUniform.new()
	compute_forces_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_positions_uniform.binding = 0
	compute_forces_positions_uniform.add_id(positions_buffer_rid)
	compute_forces_velocities_uniform = RDUniform.new()
	compute_forces_velocities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_velocities_uniform.binding = 1
	compute_forces_velocities_uniform.add_id(velocities_buffer_rid)
	compute_forces_sorted_particle_indices_uniform = RDUniform.new()
	compute_forces_sorted_particle_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_sorted_particle_indices_uniform.binding = 2
	compute_forces_sorted_particle_indices_uniform.add_id(particle_indices_1_buffer_rid)
	compute_forces_start_indices_uniform = RDUniform.new()
	compute_forces_start_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_start_indices_uniform.binding = 3
	compute_forces_start_indices_uniform.add_id(start_indices_buffer_rid)
	compute_forces_end_indices_uniform = RDUniform.new()
	compute_forces_end_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_end_indices_uniform.binding = 4
	compute_forces_end_indices_uniform.add_id(end_indices_buffer_rid)
	compute_forces_densities_uniform = RDUniform.new()
	compute_forces_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_densities_uniform.binding = 5
	compute_forces_densities_uniform.add_id(densities_buffer_rid)
	compute_forces_pressures_uniform = RDUniform.new()
	compute_forces_pressures_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_pressures_uniform.binding = 6
	compute_forces_pressures_uniform.add_id(pressures_buffer_rid)
	compute_forces_near_densities_uniform = RDUniform.new()
	compute_forces_near_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_near_densities_uniform.binding = 7
	compute_forces_near_densities_uniform.add_id(near_densities_buffer_rid)
	compute_forces_near_pressures_uniform = RDUniform.new()
	compute_forces_near_pressures_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_near_pressures_uniform.binding = 8
	compute_forces_near_pressures_uniform.add_id(near_pressures_buffer_rid)
	compute_forces_vorticities_uniform = RDUniform.new()
	compute_forces_vorticities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_vorticities_uniform.binding = 9
	compute_forces_vorticities_uniform.add_id(vorticities_buffer_rid)
	compute_forces_forces_uniform = RDUniform.new()
	compute_forces_forces_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_forces_uniform.binding = 10
	compute_forces_forces_uniform.add_id(forces_buffer_rid)
	compute_forces_is_alive_uniform = RDUniform.new()
	compute_forces_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	compute_forces_is_alive_uniform.binding = 11
	compute_forces_is_alive_uniform.add_id(is_alive_buffer_rid)
	integrate_motion_positions_uniform = RDUniform.new()
	integrate_motion_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_positions_uniform.binding = 0
	integrate_motion_positions_uniform.add_id(positions_buffer_rid)
	integrate_motion_velocities_uniform = RDUniform.new()
	integrate_motion_velocities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_velocities_uniform.binding = 1
	integrate_motion_velocities_uniform.add_id(velocities_buffer_rid)
	integrate_motion_densities_uniform = RDUniform.new()
	integrate_motion_densities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_densities_uniform.binding = 2
	integrate_motion_densities_uniform.add_id(densities_buffer_rid)
	integrate_motion_forces_uniform = RDUniform.new()
	integrate_motion_forces_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_forces_uniform.binding = 3
	integrate_motion_forces_uniform.add_id(forces_buffer_rid)
	integrate_motion_sorted_particle_indices_uniform = RDUniform.new()
	integrate_motion_sorted_particle_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_sorted_particle_indices_uniform.binding = 4
	integrate_motion_sorted_particle_indices_uniform.add_id(particle_indices_1_buffer_rid)
	integrate_motion_start_indices_uniform = RDUniform.new()
	integrate_motion_start_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_start_indices_uniform.binding = 5
	integrate_motion_start_indices_uniform.add_id(start_indices_buffer_rid)
	integrate_motion_end_indices_uniform = RDUniform.new()
	integrate_motion_end_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_end_indices_uniform.binding = 6
	integrate_motion_end_indices_uniform.add_id(end_indices_buffer_rid)
	integrate_motion_is_alive_uniform = RDUniform.new()
	integrate_motion_is_alive_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_is_alive_uniform.binding = 7
	integrate_motion_is_alive_uniform.add_id(is_alive_buffer_rid)
	integrate_motion_temperatures_uniform = RDUniform.new()
	integrate_motion_temperatures_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	integrate_motion_temperatures_uniform.binding = 8
	integrate_motion_temperatures_uniform.add_id(temperatures_buffer_rid)
	store_neighbors_positions_uniform = RDUniform.new()
	store_neighbors_positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	store_neighbors_positions_uniform.binding = 0
	store_neighbors_positions_uniform.add_id(positions_buffer_rid)
	store_neighbors_sorted_particle_indices_uniform = RDUniform.new()
	store_neighbors_sorted_particle_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	store_neighbors_sorted_particle_indices_uniform.binding = 1
	store_neighbors_sorted_particle_indices_uniform.add_id(particle_indices_1_buffer_rid)
	store_neighbors_start_indices_uniform = RDUniform.new()
	store_neighbors_start_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	store_neighbors_start_indices_uniform.binding = 2
	store_neighbors_start_indices_uniform.add_id(start_indices_buffer_rid)
	store_neighbors_end_indices_uniform = RDUniform.new()
	store_neighbors_end_indices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	store_neighbors_end_indices_uniform.binding = 3
	store_neighbors_end_indices_uniform.add_id(end_indices_buffer_rid)
	store_neighbors_neighbor_flags_uniform = RDUniform.new()
	store_neighbors_neighbor_flags_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	store_neighbors_neighbor_flags_uniform.binding = 4
	store_neighbors_neighbor_flags_uniform.add_id(neighbor_flags_buffer_rid)
	mark_neighbors_neighbor_flags_uniform = RDUniform.new()
	mark_neighbors_neighbor_flags_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	mark_neighbors_neighbor_flags_uniform.binding = 0
	mark_neighbors_neighbor_flags_uniform.add_id(neighbor_flags_buffer_rid)
	#endregion
	
	#region textures
	# my usage bits: allow sampling and allow shaders to read from and write to an image without using a fixed-function graphics pipeline
	
	particle_pos_temp_img_texture_view = RDTextureView.new()
	particle_pos_temp_img_texture_format = RDTextureFormat.new()
	particle_pos_temp_img_texture_format.width = particle_pos_temp_img_size
	particle_pos_temp_img_texture_format.height = particle_pos_temp_img_size
	particle_pos_temp_img_texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT    # matches FORMAT_RGBAF
	particle_pos_temp_img_texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	particle_pos_temp_img_ren_texture_rid = ren_rd.texture_create(particle_pos_temp_img_texture_format, particle_pos_temp_img_texture_view)
	particle_pos_temp_img_texture_rid = rd.texture_create_from_extension(
		RenderingDevice.TEXTURE_TYPE_2D,
		particle_pos_temp_img_texture_format.format,
		particle_pos_temp_img_texture_format.samples,
		particle_pos_temp_img_texture_format.usage_bits,
		ren_rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_TEXTURE, particle_pos_temp_img_ren_texture_rid, 0),
		particle_pos_temp_img_texture_format.width,
		particle_pos_temp_img_texture_format.height,
		particle_pos_temp_img_texture_format.depth,
		particle_pos_temp_img_texture_format.array_layers
	)
	
	glass_sdf_img_texture_view = RDTextureView.new()
	glass_sdf_img_texture_format = RDTextureFormat.new()
	glass_sdf_img_texture_format.width = glass_sdf_imgs_size.x
	glass_sdf_img_texture_format.height = glass_sdf_imgs_size.y
	glass_sdf_img_texture_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT    # matches FORMAT_RF
	glass_sdf_img_texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	glass_sdf_img_ren_texture_rid = ren_rd.texture_create(glass_sdf_img_texture_format, glass_sdf_img_texture_view, [glass_sdf_img.get_data()])
	glass_sdf_img_texture_rid = rd.texture_create_from_extension(
		RenderingDevice.TEXTURE_TYPE_2D,
		glass_sdf_img_texture_format.format,
		glass_sdf_img_texture_format.samples,
		glass_sdf_img_texture_format.usage_bits,
		ren_rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_TEXTURE, glass_sdf_img_ren_texture_rid, 0),
		glass_sdf_img_texture_format.width,
		glass_sdf_img_texture_format.height,
		glass_sdf_img_texture_format.depth,
		glass_sdf_img_texture_format.array_layers
	)
	
	glass_sdf_gradient_img_texture_view = RDTextureView.new()
	glass_sdf_gradient_img_texture_format = RDTextureFormat.new()
	glass_sdf_gradient_img_texture_format.width = glass_sdf_imgs_size.x
	glass_sdf_gradient_img_texture_format.height = glass_sdf_imgs_size.y
	glass_sdf_gradient_img_texture_format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT    # matches FORMAT_RGF
	glass_sdf_gradient_img_texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	glass_sdf_gradient_img_ren_texture_rid = ren_rd.texture_create(glass_sdf_gradient_img_texture_format, glass_sdf_gradient_img_texture_view, [glass_sdf_gradient_img.get_data()])
	glass_sdf_gradient_img_texture_rid = rd.texture_create_from_extension(
		RenderingDevice.TEXTURE_TYPE_2D,
		glass_sdf_gradient_img_texture_format.format,
		glass_sdf_gradient_img_texture_format.samples,
		glass_sdf_gradient_img_texture_format.usage_bits,
		ren_rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_TEXTURE, glass_sdf_gradient_img_ren_texture_rid, 0),
		glass_sdf_gradient_img_texture_format.width,
		glass_sdf_gradient_img_texture_format.height,
		glass_sdf_gradient_img_texture_format.depth,
		glass_sdf_gradient_img_texture_format.array_layers
	)
	
	integrate_motion_particle_pos_temp_img_uniform = RDUniform.new()
	integrate_motion_particle_pos_temp_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	integrate_motion_particle_pos_temp_img_uniform.binding = 9
	integrate_motion_particle_pos_temp_img_uniform.add_id(particle_pos_temp_img_texture_rid)
	integrate_motion_glass_sdf_img_uniform = RDUniform.new()
	integrate_motion_glass_sdf_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	integrate_motion_glass_sdf_img_uniform.binding = 10
	integrate_motion_glass_sdf_img_uniform.add_id(glass_sdf_img_texture_rid)
	integrate_motion_glass_sdf_gradient_img_uniform = RDUniform.new()
	integrate_motion_glass_sdf_gradient_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	integrate_motion_glass_sdf_gradient_img_uniform.binding = 11
	integrate_motion_glass_sdf_gradient_img_uniform.add_id(glass_sdf_gradient_img_texture_rid)
	store_neighbors_particle_pos_temp_img_uniform = RDUniform.new()
	store_neighbors_particle_pos_temp_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	store_neighbors_particle_pos_temp_img_uniform.binding = 5
	store_neighbors_particle_pos_temp_img_uniform.add_id(particle_pos_temp_img_texture_rid)
	mark_neighbors_particle_pos_temp_img_uniform = RDUniform.new()
	mark_neighbors_particle_pos_temp_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	mark_neighbors_particle_pos_temp_img_uniform.binding = 1
	mark_neighbors_particle_pos_temp_img_uniform.add_id(particle_pos_temp_img_texture_rid)
	#endregion
	
	#region uniform sets
	kill_particles_uniform_set_rid = rd.uniform_set_create([kill_particles_positions_uniform, kill_particles_velocities_uniform, kill_particles_lifetimes_uniform, kill_particles_ages_uniform, kill_particles_is_alive_uniform, kill_particles_dead_stack_uniform, kill_particles_dead_count_uniform], kill_particles_shader_rid, 0)
	spawn_particles_uniform_set_rid = rd.uniform_set_create([spawn_particles_positions_uniform, spawn_particles_velocities_uniform, spawn_particles_ages_uniform, spawn_particles_is_alive_uniform, spawn_particles_dead_stack_uniform, spawn_particles_dead_count_uniform], spawn_particles_shader_rid, 0)
	compute_hashes_uniform_set_rid = rd.uniform_set_create([compute_hashes_positions_uniform, compute_hashes_hashes_uniform, compute_hashes_particle_indices_uniform], compute_hashes_shader_rid, 0)
	
	#region parallel radix sort uniform sets
	histogram_uniform_set_1_rid = rd.uniform_set_create([histogram_keys_in_1_uniform, histogram_group_histograms_uniform], histogram_shader_rid, 0)    # ping-pong
	histogram_uniform_set_2_rid = rd.uniform_set_create([histogram_keys_in_2_uniform, histogram_group_histograms_uniform], histogram_shader_rid, 0)    # ping-pong
	counts_per_digit_uniform_set_rid = rd.uniform_set_create([counts_per_digit_group_histograms_uniform, counts_per_digit_digit_totals_uniform], counts_per_digit_shader_rid, 0)
	pps16_uniform_set_rid = rd.uniform_set_create([pps16_inputtt_uniform, pps16_outputtt_uniform], pps16_shader_rid, 0)
	scan_per_digit_uniform_set_rid = rd.uniform_set_create([scan_per_digit_group_histograms_uniform, scan_per_digit_prefix_groups_uniform], scan_per_digit_shader_rid, 0)
	combine_offsets_uniform_set_rid = rd.uniform_set_create([combine_offsets_digit_totals_after_scan_uniform, combine_offsets_prefix_groups_uniform, combine_offsets_group_offsets_uniform], combine_offsets_shader_rid, 0)
	scatter_uniform_set_1_rid = rd.uniform_set_create([scatter_keys_in_1_uniform, scatter_keys_out_1_uniform, scatter_group_offsets_uniform, scatter_values_in_1_uniform, scatter_values_out_1_uniform], scatter_shader_rid, 0)    # ping-pong
	scatter_uniform_set_2_rid = rd.uniform_set_create([scatter_keys_in_2_uniform, scatter_keys_out_2_uniform, scatter_group_offsets_uniform, scatter_values_in_2_uniform, scatter_values_out_2_uniform], scatter_shader_rid, 0)    # ping-pong
	#endregion
	
	range_start_end_uniform_set_rid = rd.uniform_set_create([range_start_end_hashes_uniform, range_start_end_start_indices_uniform, range_start_end_end_indices_uniform], range_start_end_shader_rid, 0)
	compute_densities_uniform_set_rid = rd.uniform_set_create([compute_densities_positions_uniform, compute_densities_sorted_particle_indices_uniform, compute_densities_start_indices_uniform, compute_densities_end_indices_uniform, compute_densities_densities_uniform, compute_densities_near_densities_uniform, compute_densities_is_alive_uniform], compute_densities_shader_rid, 0)
	compute_pressures_uniform_set_rid = rd.uniform_set_create([compute_pressures_densities_uniform, compute_pressures_pressures_uniform, compute_pressures_near_densities_uniform, compute_pressures_near_pressures_uniform, compute_pressures_is_alive_uniform], compute_pressures_shader_rid, 0)
	compute_vorticities_uniform_set_rid = rd.uniform_set_create([compute_vorticities_positions_uniform, compute_vorticities_sorted_particle_indices_uniform, compute_vorticities_start_indices_uniform, compute_vorticities_end_indices_uniform, compute_vorticities_densities_uniform, compute_vorticities_velocities_uniform, compute_vorticities_vorticities_uniform, compute_vorticities_is_alive_uniform], compute_vorticities_shader_rid, 0)
	compute_forces_uniform_set_rid = rd.uniform_set_create([compute_forces_positions_uniform, compute_forces_velocities_uniform, compute_forces_sorted_particle_indices_uniform, compute_forces_start_indices_uniform, compute_forces_end_indices_uniform, compute_forces_densities_uniform, compute_forces_pressures_uniform, compute_forces_near_densities_uniform, compute_forces_near_pressures_uniform, compute_forces_vorticities_uniform, compute_forces_forces_uniform, compute_forces_is_alive_uniform], compute_forces_shader_rid, 0)
	integrate_motion_uniform_set_rid = rd.uniform_set_create([integrate_motion_positions_uniform, integrate_motion_velocities_uniform, integrate_motion_densities_uniform, integrate_motion_forces_uniform, integrate_motion_sorted_particle_indices_uniform, integrate_motion_start_indices_uniform, integrate_motion_end_indices_uniform, integrate_motion_is_alive_uniform, integrate_motion_temperatures_uniform, integrate_motion_particle_pos_temp_img_uniform, integrate_motion_glass_sdf_img_uniform, integrate_motion_glass_sdf_gradient_img_uniform], integrate_motion_shader_rid, 0)
	store_neighbors_uniform_set_rid = rd.uniform_set_create([store_neighbors_positions_uniform, store_neighbors_sorted_particle_indices_uniform, store_neighbors_start_indices_uniform, store_neighbors_end_indices_uniform, store_neighbors_neighbor_flags_uniform, store_neighbors_particle_pos_temp_img_uniform], store_neighbors_shader_rid, 0)
	mark_neighbors_uniform_set_rid = rd.uniform_set_create([mark_neighbors_neighbor_flags_uniform, mark_neighbors_particle_pos_temp_img_uniform], mark_neighbors_shader_rid, 0)
	#endregion
	
	#region pipelines
	kill_particles_pipeline_rid = rd.compute_pipeline_create(kill_particles_shader_rid)
	spawn_particles_pipeline_rid = rd.compute_pipeline_create(spawn_particles_shader_rid)
	compute_hashes_pipeline_rid = rd.compute_pipeline_create(compute_hashes_shader_rid)
	
	#region parallel radix sort pipelines
	histogram_pipeline_rid = rd.compute_pipeline_create(histogram_shader_rid)
	counts_per_digit_pipeline_rid = rd.compute_pipeline_create(counts_per_digit_shader_rid)
	pps16_pipeline_rid = rd.compute_pipeline_create(pps16_shader_rid)
	scan_per_digit_pipeline_rid = rd.compute_pipeline_create(scan_per_digit_shader_rid)
	combine_offsets_pipeline_rid = rd.compute_pipeline_create(combine_offsets_shader_rid)
	scatter_pipeline_rid = rd.compute_pipeline_create(scatter_shader_rid)
	#endregion
	
	range_start_end_pipeline_rid = rd.compute_pipeline_create(range_start_end_shader_rid)
	compute_densities_pipeline_rid = rd.compute_pipeline_create(compute_densities_shader_rid)
	compute_pressures_pipeline_rid = rd.compute_pipeline_create(compute_pressures_shader_rid)
	compute_vorticities_pipeline_rid = rd.compute_pipeline_create(compute_vorticities_shader_rid)
	compute_forces_pipeline_rid = rd.compute_pipeline_create(compute_forces_shader_rid)
	integrate_motion_pipeline_rid = rd.compute_pipeline_create(integrate_motion_shader_rid)
	store_neighbors_pipeline_rid = rd.compute_pipeline_create(store_neighbors_shader_rid)
	mark_neighbors_pipeline_rid = rd.compute_pipeline_create(mark_neighbors_shader_rid)
	#endregion

func run_gpu(delta: float, n_times: int, spawning_on: bool) -> void:
	
	# begin a list of instructions for GPU to execute
	var compute_list: int = rd.compute_list_begin()
	
	var params: PackedByteArray    # array for storing params which are then used in push constant buffers in our shaders
	var shift: int = 0    # used to control which 4-bit "digit" we're currently processing in parallel radix sort
	var curr_histogram_uniform_set_rid: RID    # controls the ping-pong of buffers
	var curr_scatter_uniform_set_rid: RID    # controls the ping-pong of buffers
	
	# it seems it makes no difference if we write "range(n_times)" or just "n_times"
	for n in n_times:
		#region kill particles pass
		rd.compute_list_bind_compute_pipeline(compute_list, kill_particles_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, kill_particles_uniform_set_rid, 0)
		params.resize(16)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, delta)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, kill_particles_workgroups_x, 1, 1)
		#endregion
		
		#region spawning logic
		if spawning_on:
			spawn_accumulator += rt_spawn_rate * delta
			curr_spawn_accumulator_int_part = int(spawn_accumulator)
			
			if curr_spawn_accumulator_int_part != prev_spawn_accumulator_int_part:
				spawn_count += curr_spawn_accumulator_int_part - prev_spawn_accumulator_int_part
				prev_spawn_accumulator_int_part = curr_spawn_accumulator_int_part
		
		# spawn only once, in the last loop iteration
		# otherwise, there's a high chance that one dispatch in one iteration will spawn only one particle
		# this seems like wasting GPU potential
		# by accumulating the spawn data and waiting until the last iteration we increase the chances that one final dispatch will spawn a bunch of particles
		if (spawn_count > 0) and (n == n_times - 1):
			spawn_particles_workgroups_x = int(ceil(spawn_count / float(spawn_particles_workgroup_size_x)))
			
			spawn_grid_size = int(ceil(sqrt(spawn_count)))
			if spawn_grid_size % 2 == 0:
				spawn_grid_size += 1
			
			# in particle_spacing units
			spawn_random_offset = Vector2i(randi_range(-rt_spawn_random_offset_range, rt_spawn_random_offset_range), randi_range(-rt_spawn_random_offset_range, rt_spawn_random_offset_range))
		
			#region spawn particles pass
			rd.compute_list_bind_compute_pipeline(compute_list, spawn_particles_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, spawn_particles_uniform_set_rid, 0)
			params.resize(48)
			params.fill(0)
			params.encode_u32(0, particle_count)
			params.encode_u32(4, spawn_count)
			params.encode_u32(8, randi())
			params.encode_u32(12, spawn_grid_size);
			params.encode_float(16, rt_spawn_init_vel.x);
			params.encode_float(20, rt_spawn_init_vel.y);
			params.encode_float(24, mouse_normalized_pos.x);
			params.encode_float(28, mouse_normalized_pos.y);
			params.encode_float(32, particle_spacing)
			params.encode_s32(36, spawn_random_offset.x)
			params.encode_s32(40, spawn_random_offset.y)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, spawn_particles_workgroups_x, 1, 1)
			#endregion
			
			#print("{0} s: tried to spawn {1} particle(s), accumulator is {2}\n".format([Time.get_ticks_msec() / 1000.0, spawn_count, spawn_accumulator]))
			spawn_count = 0
		#endregion
		
		#region compute hashes pass
		rd.compute_list_bind_compute_pipeline(compute_list, compute_hashes_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, compute_hashes_uniform_set_rid, 0)
		params.resize(16)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, smoothing_radius)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, compute_hashes_workgroups_x, 1, 1)
		#endregion
		
		# for debugging purposes
		#rd.compute_list_end()
		#rd.submit()
		#rd.sync()
		#hashes_unsorted = get_uint_arr(rd.buffer_get_data(hashes_1_buffer_rid))
		#particle_indices_unsorted = get_uint_arr(rd.buffer_get_data(particle_indices_1_buffer_rid))
		#compute_list = rd.compute_list_begin()
		
		#region parallel radix sort passes
		# luckily, we always have to start parallel radix sort with hashes_1 and particle_indices_1
		# this is because the previous pass is linked to those buffers and overwrites them at the beginning of each frame
		for i in range(8):
			shift = i * 4
			
			curr_histogram_uniform_set_rid = histogram_uniform_set_1_rid if i % 2 == 0 else histogram_uniform_set_2_rid
			curr_scatter_uniform_set_rid = scatter_uniform_set_1_rid if i % 2 == 0 else scatter_uniform_set_2_rid
			
			#region pass 1 (histogram.glsl)
			rd.compute_list_bind_compute_pipeline(compute_list, histogram_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, curr_histogram_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, shift)
			params.encode_u32(4, hashes_size)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, histogram_workgroups_x, 1, 1)
			#endregion
			
			#region pass 2 (counts-per-digit.glsl)
			rd.compute_list_bind_compute_pipeline(compute_list, counts_per_digit_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, counts_per_digit_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, histogram_workgroups_x)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, counts_per_digit_workgroups_x, 1, 1)
			#endregion
			
			#region pass 3 (pps16.glsl)
			rd.compute_list_bind_compute_pipeline(compute_list, pps16_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, pps16_uniform_set_rid, 0)
			params.clear()
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, pps16_workgroups_x, 1, 1)
			#endregion
			
			#region pass 4 (scan-per-digit.glsl)
			rd.compute_list_bind_compute_pipeline(compute_list, scan_per_digit_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, scan_per_digit_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, histogram_workgroups_x)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, scan_per_digit_workgroups_x, 1, 1)
			#endregion
			
			#region pass 5 (combine-offsets.glsl)
			rd.compute_list_bind_compute_pipeline(compute_list, combine_offsets_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, combine_offsets_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, group_histograms_size)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, combine_offsets_workgroups_x, 1, 1)
			#endregion
			
			#region pass 6 (scatter.glsl)
			rd.compute_list_bind_compute_pipeline(compute_list, scatter_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, curr_scatter_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, shift)
			params.encode_u32(4, hashes_size)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, scatter_workgroups_x, 1, 1)
			#endregion
		#endregion
		
		# for debugging purposes
		#rd.compute_list_end()
		#rd.submit()
		#rd.sync()
		#hashes_sorted = get_uint_arr(rd.buffer_get_data(hashes_1_buffer_rid))
		#particle_indices_sorted = get_uint_arr(rd.buffer_get_data(particle_indices_1_buffer_rid))
		#compute_list = rd.compute_list_begin()
		
		#region range start end pass
		rd.compute_list_bind_compute_pipeline(compute_list, range_start_end_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, range_start_end_uniform_set_rid, 0)
		params.resize(16)
		params.fill(0)
		params.encode_u32(0, particle_count)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, range_start_end_workgroups_x, 1, 1)
		#endregion
		
		#region compute densities pass
		rd.compute_list_bind_compute_pipeline(compute_list, compute_densities_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, compute_densities_uniform_set_rid, 0)
		params.resize(16)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, smoothing_radius)
		params.encode_float(8, poly6_2d_constant)
		params.encode_float(12, mass)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, compute_densities_workgroups_x, 1, 1)
		#endregion
		
		#region compute pressures pass
		rd.compute_list_bind_compute_pipeline(compute_list, compute_pressures_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, compute_pressures_uniform_set_rid, 0)
		params.resize(16)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, rt_rest_density)
		params.encode_float(8, rt_stiffness)
		params.encode_float(12, rt_stiffness_near)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, compute_pressures_workgroups_x, 1, 1)
		#endregion
		
		#region compute vorticities pass
		rd.compute_list_bind_compute_pipeline(compute_list, compute_vorticities_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, compute_vorticities_uniform_set_rid, 0)
		params.resize(32)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, smoothing_radius)
		params.encode_float(8, spiky_2d_gradient_constant)
		params.encode_float(12, rt_vorticity_scale)
		params.encode_float(16, mass)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, compute_vorticities_workgroups_x, 1, 1)
		#endregion
		
		#region compute forces pass
		rd.compute_list_bind_compute_pipeline(compute_list, compute_forces_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, compute_forces_uniform_set_rid, 0)
		params.resize(64)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, smoothing_radius)
		params.encode_float(8, spiky_2d_gradient_constant)
		params.encode_float(12, visc_2d_laplacian_constant)
		params.encode_float(16, rt_viscosity_scale)
		params.encode_float(20, gravity.x * rt_gravity_multiplier)
		params.encode_float(24, gravity.y * rt_gravity_multiplier)
		params.encode_float(28, mouse_normalized_pos.x)
		params.encode_float(32, mouse_normalized_pos.y)
		params.encode_float(36, rt_mouse_interaction_radius)
		params.encode_float(40, rt_mouse_interaction_strength if right_button_clicked else (-rt_mouse_interaction_strength if middle_button_clicked else 0.0))
		params.encode_float(44, rt_surface_tension_threshold)
		params.encode_float(48, rt_surface_tension_scale)
		params.encode_float(52, rt_vorticity_scale)
		params.encode_float(56, mass)
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, compute_forces_workgroups_x, 1, 1)
		#endregion
		
		#region integrate motion pass
		rd.compute_list_bind_compute_pipeline(compute_list, integrate_motion_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, integrate_motion_uniform_set_rid, 0)
		params.resize(128)
		params.fill(0)
		params.encode_u32(0, particle_count)
		params.encode_float(4, delta)
		params.encode_float(8, rt_damping)
		params.encode_float(12, rt_bounds_damping)
		params.encode_float(16, rt_vel_clamp)
		params.encode_float(20, particle_pos_temp_img_size_f)
		params.encode_float(24, glass_sdf_imgs_size_f.x)
		params.encode_float(28, glass_sdf_imgs_size_f.y)
		params.encode_float(32, rt_adhesion_scale)
		params.encode_float(36, rt_adhesion_threshold)
		params.encode_float(40, particle_spacing)
		params.encode_float(44, smoothing_radius)
		params.encode_float(48, poly6_2d_constant)
		params.encode_float(52, mass)
		params.encode_float(56, rt_xsph_scale)
		params.encode_float(60, M_X_x)
		params.encode_float(64, M_X_y)
		params.encode_float(68, M_Y_x)
		params.encode_float(72, M_Y_y)
		params.encode_float(76, M_origin_x)
		params.encode_float(80, M_origin_y)
		params.encode_float(84, M_rotation_X_x)
		params.encode_float(88, M_rotation_X_y)
		params.encode_float(92, M_rotation_Y_x)
		params.encode_float(96, M_rotation_Y_y)
		params.encode_float(100, normalized_to_viewport_scale_factor.x)
		params.encode_float(104, normalized_to_viewport_scale_factor.y)
		params.encode_float(108, viewport_to_normalized_scale_factor.x)
		params.encode_float(112, viewport_to_normalized_scale_factor.y)
		params.encode_u32(116, int(rt_vis_neighborhood_search))
		rd.compute_list_set_push_constant(compute_list, params, params.size())
		rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, integrate_motion_workgroups_x, 1, 1)
		#endregion
		
		if rt_vis_neighborhood_search:
			
			#region store neighbors pass
			rd.compute_list_bind_compute_pipeline(compute_list, store_neighbors_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, store_neighbors_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, particle_count)
			params.encode_float(4, smoothing_radius)
			params.encode_float(8, particle_pos_temp_img_size_f)
			params.encode_u32(12, verbose_particle_idx)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, store_neighbors_workgroups_x, 1, 1)
			#endregion
			
			#region mark neighbors pass
			rd.compute_list_bind_compute_pipeline(compute_list, mark_neighbors_pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, mark_neighbors_uniform_set_rid, 0)
			params.resize(16)
			params.fill(0)
			params.encode_u32(0, particle_count)
			params.encode_float(4, particle_pos_temp_img_size_f)
			rd.compute_list_set_push_constant(compute_list, params, params.size())
			rd.compute_list_add_barrier(compute_list)
			rd.compute_list_dispatch(compute_list, mark_neighbors_workgroups_x, 1, 1)
			#endregion
		
	# end the list of instructions
	rd.compute_list_end()
	
	# we've recorded what we want GPU to do, now we actually submit it to GPU
	rd.submit()
	
	# for measuring time
	#var st: int = Time.get_ticks_usec()
	
	# tell CPU to wait for GPU
	#rd.sync()
	
	# measure simulation timestep in ms
	#print((Time.get_ticks_usec() - st) / 1000.0, " ", "ms")

func free_gpu() -> void:
	#region pipelines
	rd.free_rid(kill_particles_pipeline_rid)
	rd.free_rid(spawn_particles_pipeline_rid)
	rd.free_rid(compute_hashes_pipeline_rid)
	#region parallel radix sort pipelines
	rd.free_rid(histogram_pipeline_rid)
	rd.free_rid(counts_per_digit_pipeline_rid)
	rd.free_rid(pps16_pipeline_rid)
	rd.free_rid(scan_per_digit_pipeline_rid)
	rd.free_rid(combine_offsets_pipeline_rid)
	rd.free_rid(scatter_pipeline_rid)
	#endregion
	rd.free_rid(range_start_end_pipeline_rid)
	rd.free_rid(compute_densities_pipeline_rid)
	rd.free_rid(compute_pressures_pipeline_rid)
	rd.free_rid(compute_vorticities_pipeline_rid)
	rd.free_rid(compute_forces_pipeline_rid)
	rd.free_rid(integrate_motion_pipeline_rid)
	rd.free_rid(store_neighbors_pipeline_rid)
	rd.free_rid(mark_neighbors_pipeline_rid)
	#endregion
	
	#region uniform sets
	rd.free_rid(kill_particles_uniform_set_rid)
	rd.free_rid(spawn_particles_uniform_set_rid)
	rd.free_rid(compute_hashes_uniform_set_rid)
	#region parallel radix sort uniform sets
	rd.free_rid(histogram_uniform_set_1_rid)
	rd.free_rid(histogram_uniform_set_2_rid)
	rd.free_rid(counts_per_digit_uniform_set_rid)
	rd.free_rid(pps16_uniform_set_rid)
	rd.free_rid(scan_per_digit_uniform_set_rid)
	rd.free_rid(combine_offsets_uniform_set_rid)
	rd.free_rid(scatter_uniform_set_1_rid)
	rd.free_rid(scatter_uniform_set_2_rid)
	#endregion
	rd.free_rid(range_start_end_uniform_set_rid)
	rd.free_rid(compute_densities_uniform_set_rid)
	rd.free_rid(compute_pressures_uniform_set_rid)
	rd.free_rid(compute_vorticities_uniform_set_rid)
	rd.free_rid(compute_forces_uniform_set_rid)
	rd.free_rid(integrate_motion_uniform_set_rid)
	rd.free_rid(store_neighbors_uniform_set_rid)
	rd.free_rid(mark_neighbors_uniform_set_rid)
	#endregion
	
	#region buffers
	rd.free_rid(positions_buffer_rid)
	rd.free_rid(velocities_buffer_rid)
	rd.free_rid(temperatures_buffer_rid)
	rd.free_rid(lifetimes_buffer_rid)
	rd.free_rid(ages_buffer_rid)
	rd.free_rid(is_alive_buffer_rid)
	rd.free_rid(dead_stack_buffer_rid)
	rd.free_rid(dead_count_buffer_rid)
	rd.free_rid(hashes_1_buffer_rid)
	rd.free_rid(hashes_2_buffer_rid)
	rd.free_rid(particle_indices_1_buffer_rid)
	rd.free_rid(particle_indices_2_buffer_rid)
	#region parallel radix sort buffers
	rd.free_rid(group_histograms_buffer_rid)
	rd.free_rid(digit_totals_buffer_rid)
	rd.free_rid(digit_totals_after_scan_buffer_rid)
	rd.free_rid(prefix_groups_buffer_rid)
	rd.free_rid(group_offsets_buffer_rid)
	#endregion
	rd.free_rid(start_indices_buffer_rid)
	rd.free_rid(end_indices_buffer_rid)
	rd.free_rid(densities_buffer_rid)
	rd.free_rid(pressures_buffer_rid)
	rd.free_rid(near_densities_buffer_rid)
	rd.free_rid(near_pressures_buffer_rid)
	rd.free_rid(vorticities_buffer_rid)
	rd.free_rid(forces_buffer_rid)
	rd.free_rid(neighbor_flags_buffer_rid)
	#endregion
	
	#region shaders
	rd.free_rid(kill_particles_shader_rid)
	rd.free_rid(spawn_particles_shader_rid)
	rd.free_rid(compute_hashes_shader_rid)
	#region parallel radix sort shaders
	rd.free_rid(histogram_shader_rid)
	rd.free_rid(counts_per_digit_shader_rid)
	rd.free_rid(pps16_shader_rid)
	rd.free_rid(scan_per_digit_shader_rid)
	rd.free_rid(combine_offsets_shader_rid)
	rd.free_rid(scatter_shader_rid)
	#endregion
	rd.free_rid(range_start_end_shader_rid)
	rd.free_rid(compute_densities_shader_rid)
	rd.free_rid(compute_pressures_shader_rid)
	rd.free_rid(compute_vorticities_shader_rid)
	rd.free_rid(compute_forces_shader_rid)
	rd.free_rid(integrate_motion_shader_rid)
	rd.free_rid(store_neighbors_shader_rid)
	rd.free_rid(mark_neighbors_shader_rid)
	#endregion
	
	#region textures
	rd.free_rid(particle_pos_temp_img_texture_rid)
	rd.free_rid(glass_sdf_img_texture_rid)
	rd.free_rid(glass_sdf_gradient_img_texture_rid)
	#endregion
	
	rd.free()

func update_glass_transform(delta: float) -> void:
	var moved: bool = false
	
	# movement
	if (left_arrow_pressed):
		# move glass left
		glass.position.x -= rt_glass_movement_speed * delta
		moved = true
	if (right_arrow_pressed):
		# move glass right
		glass.position.x += rt_glass_movement_speed * delta
		moved = true
	if (up_arrow_pressed):
		# move glass up
		glass.position.y -= rt_glass_movement_speed * delta
		moved = true
	if (down_arrow_pressed):
		# move glass down
		glass.position.y += rt_glass_movement_speed * delta
		moved = true
	
	# rotation
	if (a_key_pressed):
		# rotate glass CCW
		glass.rotation -= rt_glass_rotation_speed * delta
		moved = true
	if (d_key_pressed):
		# rotate glass CW
		glass.rotation += rt_glass_rotation_speed * delta
		moved = true
	
	# scaling
	if (w_key_pressed):
		# scale glass up
		var factor: Vector2 = Vector2(1.0 + (rt_glass_scaling_speed.x * delta), 1.0 + (rt_glass_scaling_speed.y * delta))
		glass.scale *= Vector2(factor.x, factor.y)
		moved = true
	if (s_key_pressed):
		# scale glass down
		var factor: Vector2 = Vector2(1.0 + (rt_glass_scaling_speed.x * delta), 1.0 + (rt_glass_scaling_speed.y * delta))
		glass.scale /= Vector2(factor.x, factor.y)
		moved = true
	
	# prevent invalid scale (very important!)
	glass.scale.x = max(glass.scale.x, 0.001)
	glass.scale.y = max(glass.scale.y, 0.001)
	
	# recompute transforms only if needed
	if moved:
		var T_new: Transform2D = glass.get_global_transform()
		var M: Transform2D = T_new * T_init_inverse
		
		# store full transform (for GPU)
		M_X_x = M.x.x
		M_X_y = M.x.y
		M_Y_x = M.y.x
		M_Y_y = M.y.y
		M_origin_x = M.origin.x
		M_origin_y = M.origin.y
		
		# extract rotation (normalize columns)
		var col_X: Vector2 = M.x.normalized()
		var col_Y: Vector2 = M.y.normalized()
		
		# store only the rotation part (also for GPU)
		M_rotation_X_x = col_X.x
		M_rotation_X_y = col_X.y
		M_rotation_Y_x = col_Y.x
		M_rotation_Y_y = col_Y.y

func _on_colorpickerbuttonvalue_changed(new_color: Color, color_picker_button_name: String) -> void:
	if color_picker_button_callbacks_dict.has(color_picker_button_name):
		color_picker_button_callbacks_dict[color_picker_button_name].call(new_color)

func _on_slidervalue_changed(new_value: float, slider_name: String) -> void:
	if slider_callbacks_dict.has(slider_name):
		slider_callbacks_dict[slider_name].call(new_value)

func _on_togglevalue_changed(toggled_on: bool, toggle_name: String) -> void:
	if toggle_callbacks_dict.has(toggle_name):
		toggle_callbacks_dict[toggle_name].call(toggled_on)

func init_color_picker_button_callbacks() -> void:
	# for each color picker button we define its corresponding callable
	# callables are stored in a dictionary
	# the keys are the names of the color picker buttons
	
	color_picker_button_callbacks_dict["WaterMainColorPickerButton"] = func(new_color: Color) -> void:
		water_main_color_picker_button.color = new_color
		rt_water_main_color = new_color
	
	color_picker_button_callbacks_dict["WaterTintColorPickerButton"] = func(new_color: Color) -> void:
		water_tint_color_picker_button.color = new_color
		rt_water_tint_color = new_color
	
	color_picker_button_callbacks_dict["ParticleColorPickerButton"] = func(new_color: Color) -> void:
		particle_color_picker_button.color = new_color
		if labels[curr_display_idx] == "Particles":
			rt_particle_color = new_color

func init_slider_callbacks() -> void:
	# for some reason the inspector doesn't allow 4 decimal digits, only 3 at most
	
	viscosity_scale_h_slider.min_value = viscosity_scale
	viscosity_scale_h_slider.max_value = viscosity_scale * 15
	viscosity_scale_h_slider.step = 0.0001
	viscosity_scale_h_slider.value = viscosity_scale
	
	surface_tension_scale_h_slider.step = 0.0001
	
	damping_h_slider.value = damping
	damping_h_slider.step = 0.0001
	
	# for each slider we define its corresponding callable
	# callables are stored in a dictionary
	# the keys are the names of the sliders
	
	slider_callbacks_dict["ParticleVisSizeHSlider"] = func(new_value: float) -> void:
		particle_vis_size_value.text = str(new_value)
		particle_vis_size_h_slider.value = new_value
		rt_particle_vis_size = new_value
	
	slider_callbacks_dict["RestDensityHSlider"] = func(new_value: float) -> void:
		rest_density_value.text = str(new_value)
		rest_density_h_slider.value = new_value
		rt_rest_density = new_value
	
	slider_callbacks_dict["StiffnessHSlider"] = func(new_value: float) -> void:
		stiffness_value.text = str(new_value)
		stiffness_h_slider.value = new_value
		rt_stiffness = new_value
	
	slider_callbacks_dict["StiffnessNearHSlider"] = func(new_value: float) -> void:
		stiffness_near_value.text = str(new_value)
		stiffness_near_h_slider.value = new_value
		rt_stiffness_near = new_value
	
	slider_callbacks_dict["ViscosityScaleHSlider"] = func(new_value: float) -> void:
		viscosity_scale_value.text = str(new_value)
		viscosity_scale_h_slider.value = new_value
		rt_viscosity_scale = new_value
	
	slider_callbacks_dict["XSPHScaleHSlider"] = func(new_value: float) -> void:
		xsph_scale_value.text = str(new_value)
		xsph_scale_h_slider.value = new_value
		rt_xsph_scale = new_value
	
	slider_callbacks_dict["VorticityScaleHSlider"] = func(new_value: float) -> void:
		vorticity_scale_value.text = str(new_value)
		vorticity_scale_h_slider.value = new_value
		rt_vorticity_scale = new_value
	
	slider_callbacks_dict["SurfaceTensionThresholdHSlider"] = func(new_value: float) -> void:
		surface_tension_threshold_value.text = str(new_value)
		surface_tension_threshold_h_slider.value = new_value
		rt_surface_tension_threshold = new_value
	
	slider_callbacks_dict["SurfaceTensionScaleHSlider"] = func(new_value: float) -> void:
		surface_tension_scale_value.text = str(new_value)
		surface_tension_scale_h_slider.value = new_value
		rt_surface_tension_scale = new_value
	
	slider_callbacks_dict["AdhesionThresholdHSlider"] = func(new_value: float) -> void:
		adhesion_threshold_value.text = str(new_value)
		adhesion_threshold_h_slider.value = new_value
		rt_adhesion_threshold = new_value
	
	slider_callbacks_dict["AdhesionScaleHSlider"] = func(new_value: float) -> void:
		adhesion_scale_value.text = str(new_value)
		adhesion_scale_h_slider.value = new_value
		rt_adhesion_scale = new_value
	
	slider_callbacks_dict["GravityMultiplierHSlider"] = func(new_value: float) -> void:
		gravity_multiplier_value.text = str(new_value)
		gravity_multiplier_h_slider.value = new_value
		rt_gravity_multiplier = new_value
	
	slider_callbacks_dict["DampingHSlider"] = func(new_value: float) -> void:
		damping_value.text = str(new_value)
		damping_h_slider.value = new_value
		rt_damping = new_value
	
	slider_callbacks_dict["BoundsDampingHSlider"] = func(new_value: float) -> void:
		bounds_damping_value.text = str(new_value)
		bounds_damping_h_slider.value = new_value
		rt_bounds_damping = new_value
	
	slider_callbacks_dict["VelClampHSlider"] = func(new_value: float) -> void:
		vel_clamp_value.text = str(new_value)
		vel_clamp_h_slider.value = new_value
		rt_vel_clamp = new_value
	
	slider_callbacks_dict["MouseInteractionRadiusHSlider"] = func(new_value: float) -> void:
		mouse_interaction_radius_value.text = str(new_value)
		mouse_interaction_radius_h_slider.value = new_value
		rt_mouse_interaction_radius = new_value
	
	slider_callbacks_dict["MouseInteractionStrengthHSlider"] = func(new_value: float) -> void:
		mouse_interaction_strength_value.text = str(new_value)
		mouse_interaction_strength_h_slider.value = new_value
		rt_mouse_interaction_strength = new_value
	
	slider_callbacks_dict["GlassMovementSpeedHSlider"] = func(new_value: float) -> void:
		glass_movement_speed_value.text = str(new_value)
		glass_movement_speed_h_slider.value = new_value
		rt_glass_movement_speed = new_value
	
	slider_callbacks_dict["GlassRotationSpeedHSlider"] = func(new_value: float) -> void:
		glass_rotation_speed_value.text = str(new_value)
		glass_rotation_speed_h_slider.value = new_value
		rt_glass_rotation_speed = new_value
	
	slider_callbacks_dict["GlassScalingSpeedXHSlider"] = func(new_value: float) -> void:
		glass_scaling_speed_x_value.text = str(new_value)
		glass_scaling_speed_x_h_slider.value = new_value
		rt_glass_scaling_speed.x = new_value
	
	slider_callbacks_dict["GlassScalingSpeedYHSlider"] = func(new_value: float) -> void:
		glass_scaling_speed_y_value.text = str(new_value)
		glass_scaling_speed_y_h_slider.value = new_value
		rt_glass_scaling_speed.y = new_value
	
	slider_callbacks_dict["SpawnRateHSlider"] = func(new_value: float) -> void:
		spawn_rate_value.text = str(new_value)
		spawn_rate_h_slider.value = new_value
		rt_spawn_rate = new_value
	
	slider_callbacks_dict["SpawnRandomOffsetRangeHSlider"] = func(new_value: float) -> void:
		spawn_random_offset_range_value.text = str(new_value)
		spawn_random_offset_range_h_slider.value = new_value
		rt_spawn_random_offset_range = int(new_value)
	
	slider_callbacks_dict["SpawnInitVelXHSlider"] = func(new_value: float) -> void:
		spawn_init_vel_x_value.text = str(new_value)
		spawn_init_vel_x_h_slider.value = new_value
		rt_spawn_init_vel.x = new_value
	
	slider_callbacks_dict["SpawnInitVelYHSlider"] = func(new_value: float) -> void:
		spawn_init_vel_y_value.text = str(new_value)
		spawn_init_vel_y_h_slider.value = new_value
		rt_spawn_init_vel.y = new_value
	
	slider_callbacks_dict["BlurAmountHSlider"] = func(new_value: float) -> void:
		blur_amount_value.text = str(new_value)
		blur_amount_h_slider.value = new_value
		rt_blur_amount = new_value
	
	slider_callbacks_dict["WaterDensityThresholdHSlider"] = func(new_value: float) -> void:
		water_density_threshold_value.text = str(new_value)
		water_density_threshold_h_slider.value = new_value
		rt_water_density_threshold = new_value
	
	slider_callbacks_dict["EdgeSoftnessHSlider"] = func(new_value: float) -> void:
		edge_softness_value.text = str(new_value)
		edge_softness_h_slider.value = new_value
		rt_edge_softness = new_value
	
	slider_callbacks_dict["TintThresholdMinHSlider"] = func(new_value: float) -> void:
		var new_val: float = min(new_value, rt_tint_threshold_max)
		tint_threshold_min_value.text = str(new_val)
		tint_threshold_min_h_slider.value = new_val
		rt_tint_threshold_min = new_val
	
	slider_callbacks_dict["TintThresholdMaxHSlider"] = func(new_value: float) -> void:
		var new_val: float = max(new_value, rt_tint_threshold_min)
		tint_threshold_max_value.text = str(new_val)
		tint_threshold_max_h_slider.value = new_val
		rt_tint_threshold_max = new_val

func init_toggle_callbacks() -> void:
	# for each toggle we define its corresponding callable
	# callables are stored in a dictionary
	# the keys are the names of the toggles
	
	toggle_callbacks_dict["VisNeighborhoodSearchToggleCheckBox"] = func(toggled_on: bool) -> void:
		vis_neighborhood_search_toggle_check_box.button_pressed = toggled_on
		rt_vis_neighborhood_search = toggled_on

func reset_params() -> void:
	color_picker_button_callbacks_dict["WaterMainColorPickerButton"].call(water_main_color)
	color_picker_button_callbacks_dict["WaterTintColorPickerButton"].call(water_tint_color)
	color_picker_button_callbacks_dict["ParticleColorPickerButton"].call(particle_color)
	
	slider_callbacks_dict["ParticleVisSizeHSlider"].call(particle_vis_size)
	slider_callbacks_dict["RestDensityHSlider"].call(rest_density)
	slider_callbacks_dict["StiffnessHSlider"].call(stiffness)
	slider_callbacks_dict["StiffnessNearHSlider"].call(stiffness_near)
	slider_callbacks_dict["ViscosityScaleHSlider"].call(viscosity_scale)
	slider_callbacks_dict["XSPHScaleHSlider"].call(xsph_scale)
	slider_callbacks_dict["VorticityScaleHSlider"].call(vorticity_scale)
	slider_callbacks_dict["SurfaceTensionThresholdHSlider"].call(surface_tension_threshold)
	slider_callbacks_dict["SurfaceTensionScaleHSlider"].call(surface_tension_scale)
	slider_callbacks_dict["AdhesionThresholdHSlider"].call(adhesion_threshold)
	slider_callbacks_dict["AdhesionScaleHSlider"].call(adhesion_scale)
	slider_callbacks_dict["GravityMultiplierHSlider"].call(gravity_multiplier)
	slider_callbacks_dict["DampingHSlider"].call(damping)
	slider_callbacks_dict["BoundsDampingHSlider"].call(bounds_damping)
	slider_callbacks_dict["VelClampHSlider"].call(vel_clamp)
	slider_callbacks_dict["MouseInteractionRadiusHSlider"].call(mouse_interaction_radius)
	slider_callbacks_dict["MouseInteractionStrengthHSlider"].call(mouse_interaction_strength)
	slider_callbacks_dict["GlassMovementSpeedHSlider"].call(glass_movement_speed)
	slider_callbacks_dict["GlassRotationSpeedHSlider"].call(glass_rotation_speed)
	slider_callbacks_dict["GlassScalingSpeedXHSlider"].call(glass_scaling_speed.x)
	slider_callbacks_dict["GlassScalingSpeedYHSlider"].call(glass_scaling_speed.y)
	slider_callbacks_dict["SpawnRateHSlider"].call(spawn_rate)
	slider_callbacks_dict["SpawnRandomOffsetRangeHSlider"].call(spawn_random_offset_range)
	slider_callbacks_dict["SpawnInitVelXHSlider"].call(spawn_init_vel.x)
	slider_callbacks_dict["SpawnInitVelYHSlider"].call(spawn_init_vel.y)
	slider_callbacks_dict["BlurAmountHSlider"].call(blur_amount)
	slider_callbacks_dict["WaterDensityThresholdHSlider"].call(water_density_threshold)
	slider_callbacks_dict["EdgeSoftnessHSlider"].call(edge_softness)
	slider_callbacks_dict["TintThresholdMinHSlider"].call(tint_threshold_min)
	slider_callbacks_dict["TintThresholdMaxHSlider"].call(tint_threshold_max)
	
	toggle_callbacks_dict["VisNeighborhoodSearchToggleCheckBox"].call(vis_neighborhood_search)

func set_display() -> void:
	display.texture = textures[curr_display_idx]
	label.text = labels[curr_display_idx]
	
	#if labels[curr_display_idx] == "Particles":
		#rt_particle_color = particle_color_picker_button.color
	#else:
		#rt_particle_color = Color.WHITE

func print_transforms_intuition() -> void:
	# the following code explains the logic of moving between some coordinate systems using transforms
	# it's needed to perform dynamic collision detection with a glass with the help of SDF and its gradient
	
	# vertices in local space
	var glass_vertices: PackedVector2Array = glass.polygon
	
	# some random vertex used for testing
	var gv: Vector2 = glass_vertices[-1]
	
	# optional offset in local space
	# it needs to be applied to each vertex in local space
	# otherwise, we won't get the correct positions of vertices in local space
	var glass_offset: Vector2 = glass.offset
	
	# X axis increases rightwards, Y axis increases downwards
	# rotations by positive angles are clockwise
	# matrices representing transforms use columns to represent basis vectors
	# here we set the initial position, rotation and scale of the glass
	glass.position = Vector2(0.8 * viewport_size_f.x, 0.4 * viewport_size_f.y)
	glass.rotation = -0.1 * PI
	glass.scale = Vector2(1.0, 1.5) * 0.75
	
	# position, rotation and scale define a 2D transform T
	# every transform T here is a 2D transform represented as a 2x2 matrix and an additional 2x1 translation vector
	# T = (A, t), A = rotation/scaling matrix, t = translation vector
	# each transform is relative to the parent node
	# transform.x - X basis vector (first column of the matrix A)
	# transform.y - Y basis vector (second column of the matrix A)
	# transform.x.x - top-left
	# transform.x.y - bottom-left
	# transform.y.x - top-right
	# transform.y.y - bottom-right
	# transform.origin - vector t
	# transform.origin.x - x component of t
	# transform.origin.y - y component of t
	# affine inverse returns the inverse transform, T^-1, of the original transform T
	# affine inverse assumes that T is composed of rotation, scaling and translation
	# T_init is computed only once and so T_init_inverse is computed only once
	# we'll need T_init_inverse in other parts of the code
	var T_init: Transform2D = glass.get_global_transform()
	T_init_inverse = T_init.affine_inverse()
	print(T_init.x.x)
	print(T_init.x.y)
	print(T_init.y.x)
	print(T_init.y.y)
	print(T_init.origin.x)
	print(T_init.origin.y)
	print("T_init: ", T_init)
	print("T_init_inverse: ", T_init_inverse)
	print("Identity check: ", T_init * T_init_inverse)
	print()
	
	# global transforms (e.g. T_init) allow us to find the world position of each vertex of the glass (polygon)
	# this world position is unnormalized and doesn't include the offset applied to each vertex
	# but we want it to be normalized because our simulation works in normalized world
	# we also want to include offset, otherwise the positions will be incorrectly shifted
	# to normalize/unnormalize we just perform simple, component-wise multiplication with the appropriate scaling vector
	# to include offset we just add it to each vertex before applying the transform
	# so, to get the normalized position the formula is T * (vertex + offset) * viewport_to_normalized_scale_factor
	# multiplying by T is Godot's shorthand for applying matrix A and vector t to the given vector v (here v = vertex + offset)
	# this normalized position is in the same coordinate system as the positions of the particles
	print("Unnormalized gv position (T_init): ", T_init * (gv + glass_offset))
	print("Normalized gv position (T_init): ", T_init * (gv + glass_offset) * viewport_to_normalized_scale_factor)
	print()
	
	# during the simulation we will be able to move/rotate/scale the glass by pressing some keys
	# we can do this by changing its position, rotation and scale
	glass.position -= Vector2(100.0, 100.0)
	glass.rotation += PI
	glass.scale *= 0.5
	
	# the global transform will be changed after these operations
	# T_new must be then computed every frame
	var T_new: Transform2D = glass.get_global_transform()
	print("T_new: ", T_new)
	print()
	
	# SDF and its gradient will be created and stored in textures when the initial transform of the glass is applied
	# the initial transform of the glass is T_init
	# during the simulation we will be able to dynamically move/rotate/scale the glass
	# but when we move/rotate/scale the glass, we change T_init to T_new
	# the textures storing SDF and its gradient are static, though, and created assuming T_init, not T_new
	# this means that the SDF and its gradient won't be properly aligned for sampling anymore
	# we can imagine this as having two coordinate systems
	# (1) normalized world space in which glass is "untouched", i.e. has T_init applied
	# (1) this "untouched" space is what is visible in the textures storing SDF and its gradient
	# (2) normalized world space in which glass is "touched", i.e. moved/rotated/scaled, i.e. has T_new applied
	# (2) this "touched" space is actually our simulation space where we have our particles, their positions, velocities, etc., and in which the glass is transformed from its initial setup
	# before applying movement/rotation/scale to the glass with key presses, the "untouched" and "touched" spaces are perfectly aligned
	# but after when we change the transform of the glass, these spaces aren't aligned anymore and the positions in these space are different
	print("Unnormalized gv position (T_new): ", T_new * (gv + glass_offset))
	print("Normalized gv position (T_new): ", T_new * (gv + glass_offset) * viewport_to_normalized_scale_factor)
	print()
	
	# if there is no correct alignment, the collision detection using SDF-related textures will be incorrect
	# this is why each frame we need to convert particles' positions to a coordinate system that assumes that only T_init transform is applied to the glass, i.e. to the "untouched" space
	# the following code explains how to find the transform M that maps the "untouched" space to the "touched" space
	# M^-1 does the opposite
	# P - position in local space (before any transform, assuming only optional offset)
	# P' - position in normalized world space assuming T_init, i.e. in the "untouched" space
	# P'' - position in normalized world space assumign T_new, i.e. in the "touched" space
	# we need to find a transform that allows us to get P' from P'' and then again P'' from P'
	# this is because P'' also represents the position of a particle in a random frame
	# meanwhile, P' represents the position that we need to convert P'' to, to perform SDF-related sampling and stuff
	# after doing SDF-related stuff, we need to convert P' back to P'' (P' can be optionally corrected when performing SDF-related stuff)
	# thus, P'' is our particle position and we need to convert P'' to its position as if glass was never moved/rotated/scaled and this position is P'
	# we then perform collision check using P' and convert it back to P'', loosely speaking
	# the transforms we're looking for are M and M_inverse
	# we find M by assuming it's a transform applied to initial, T_init, tranform to get a new, T_new, tranform
	# then we show that it can move us from P' to P'' and vice-versa
	# assumptions:
	#    T_init * P = P'
	#    T_new * P = P''
	#    M * T_init = T_new
	# derivation:
	#    M = T_new * T_init_inverse    <-----
	#    (M * T_init) * P = P''
	#    M * (T_init * P) = P''
	#    M * P' = P''                  <-----
	#    M_inverse * P'' = P'          <-----
	# we found M such that  M * P' = P'' and M_inverse * P'' = P'
	# the above equations work because we can treat T_init and T_new as matrices using homogenous coordinates
	# we use M^-1 to move particle's position to the coordinate system that assumes only T_init
	# we check the collision in this coordinate system and optionally correct the position there
	# later we use M to move back the particle to the coordinate system that assumes T_new
	var M: Transform2D = T_new * T_init_inverse
	print("M: ", M)
	print()
	
	# Vector2(x1, y1) * Vector2(x2, y2) = Vector2(x1 * x2, y1 * y2) (same thing for division)
	# note that transforms assume unnormalized coordinates so we need to convert back and forth between normalized and unnormalized coordinates
	# also, note that P is just for demonstration purposes
	# in practice, we'll only work with P' (normalized) and P'' (normalized)
	# also, we won't need to worry about any additional offsets as they are specific to polygon vertices used in this demonstration
	# all of this works for positions
	# as for velocities, the logic is analogical but we actually only need to rotate them, so in case of velocities we just care about extracting the rotation part from M and M^-1
	var P: Vector2 = gv + glass_offset
	var P_prime_unnormalized: Vector2 = T_init * P
	var P_prime_normalized: Vector2 = P_prime_unnormalized * viewport_to_normalized_scale_factor
	var P_prime_prime_unnormalized: Vector2 = T_new * P
	var P_prime_prime_normalized: Vector2 = P_prime_prime_unnormalized * viewport_to_normalized_scale_factor
	print("M_inverse * P'' == P' (unnormalized): ", inverse_transform_point(M, P_prime_prime_unnormalized), " ", P_prime_unnormalized)
	print("M_inverse * P'' == P' (normalized): ", viewport_to_normalized_scale_factor * inverse_transform_point(M, normalized_to_viewport_scale_factor * P_prime_prime_normalized), " ", P_prime_normalized)
	print()

func create_sdf_related_textures(sdf_collisions_on: bool) -> void:
	if sdf_collisions_on:
		# we need the polygon's vertices in the simulation domain
		# simulation domain = normalized domain
		# this is the same as UV domain used in case of textures
		var glass_vertices_normalized = get_polygon_vertices_normalized(glass.polygon, glass.offset, T_init, viewport_to_normalized_scale_factor)
		var gvn_count = glass_vertices_normalized.size()
		
		glass_sdf_img = Image.create(glass_sdf_imgs_size.x, glass_sdf_imgs_size.y, false, Image.FORMAT_RF)
		
		for y in range(glass_sdf_imgs_size.y):
			for x in range(glass_sdf_imgs_size.x):
				
				# normalized coords [0,1]
				var uv: Vector2 = Vector2(x / glass_sdf_imgs_size_f.x, y / glass_sdf_imgs_size_f.y)
				
				var min_dist = INF
				
				# loop over edges
				for i in range(gvn_count):
					var a = glass_vertices_normalized[i]
					var b = glass_vertices_normalized[(i + 1) % gvn_count]
					
					var d = distance_to_segment(uv, a, b)
					
					if d < min_dist:
						min_dist = d
				
				# determine sign
				var inside = is_point_inside_polygon(uv, glass_vertices_normalized)
				var sdf = -min_dist if inside else min_dist
				
				# store in image
				glass_sdf_img.set_pixel(x, y, Color(sdf, 0.0, 0.0, 1.0))
		
		glass_sdf_gradient_img = Image.create(glass_sdf_imgs_size.x, glass_sdf_imgs_size.y, false, Image.FORMAT_RGF)
		
		# pixel size in normalized space
		var h_x = 1.0 / glass_sdf_imgs_size_f.x
		var h_y = 1.0 / glass_sdf_imgs_size_f.y
		
		for y in range(glass_sdf_imgs_size.y):
			for x in range(glass_sdf_imgs_size.x):
				
				# clamp neighbors to avoid out-of-bounds
				var x1 = max(x - 1, 0)
				var x2 = min(x + 1, glass_sdf_imgs_size.x - 1)
				var y1 = max(y - 1, 0)
				var y2 = min(y + 1, glass_sdf_imgs_size.y - 1)
				
				var sdf_l = glass_sdf_img.get_pixel(x1, y).r
				var sdf_r = glass_sdf_img.get_pixel(x2, y).r
				var sdf_u = glass_sdf_img.get_pixel(x, y1).r
				var sdf_d = glass_sdf_img.get_pixel(x, y2).r
				
				var dx = (sdf_r - sdf_l) / (2.0 * h_x)
				var dy = (sdf_d - sdf_u) / (2.0 * h_y)
				
				var grad = Vector2(dx, dy)
				
				# normalize (important!)
				if grad.length() > 0.0:
					grad = grad.normalized()
				
				glass_sdf_gradient_img.set_pixel(x, y, Color(grad.x, grad.y, 0.0, 1.0))
	else:
		glass_sdf_img = Image.create(glass_sdf_imgs_size.x, glass_sdf_imgs_size.y, false, Image.FORMAT_RF)
		glass_sdf_gradient_img = Image.create(glass_sdf_imgs_size.x, glass_sdf_imgs_size.y, false, Image.FORMAT_RGF)
		
		glass_sdf_img.fill(Color(0.0, 0.0, 0.0, 1.0))
		glass_sdf_gradient_img.fill(Color(0.0, 0.0, 0.0, 1.0))

func get_polygon_vertices_normalized(vertices: Array[Vector2], offset: Vector2, transform: Transform2D, normalization_factor: Vector2) -> Array[Vector2]:
	var vertices_normalized: Array[Vector2] = []
	for vertex in vertices:
		vertices_normalized.append((transform * (vertex + offset)) * normalization_factor)	
	return vertices_normalized

func distance_to_segment(P: Vector2, A: Vector2, B: Vector2) -> float:
	# P - point of interest, we measure its distance to the AB segment
	# A, B - points defining the AB segment
	
	var AP = P - A
	var AB = B - A
	
	# (AP dot (AB / len(AB))) / len(AB) = (AP dot AB) / len(AB)^2 = (AP dot AB) / (AB dot AB)
	var t = clamp(AP.dot(AB) / AB.dot(AB), 0.0, 1.0)
	
	var closest_projection = t * AB;
	
	return (AP - closest_projection).length()

func is_point_inside_polygon(P: Vector2, polygon_vertices: Array[Vector2]) -> bool:
	# check if point P is inside a polygon defined by its vertices
	# we imagine shooting a ray from our point P
	# this ray goes horizontally and infinitely to the right
	# we determine whether the point P is inside/outside the polygon by counting how many polygon edges this ray crosses
	# if the ray hits edges an odd number of times, then P is inside
	# if the ray hits edges an even number of times, then P is outside
	
	# we start by assuming that P is outside
	# every time we cross an edge, we flip this value
	var inside = false
	
	# this variable tracks the previous vertex
	# by setting it to the last index initially, the first iteration of the loop will check the edge connecting the last vertex to the first vertex
	var j = polygon_vertices.size() - 1
	
	# loop over all the edges of the polygon
	for i in range(polygon_vertices.size()):
		var vi = polygon_vertices[i]
		var vj = polygon_vertices[j]
		
		# the "Y" filter
		# if both vertices of an edge are above P, or both are below P, the ray will never hit that edge
		# the != operator ensures one point is above and one is below
		if ((vi.y > P.y) != (vj.y > P.y)):
			
			# if an edge passes the "Y" filter, we have to check if it's to the right of P
			var x_intersect = (vj.x - vi.x) * (P.y - vi.y) / (vj.y - vi.y) + vi.x
			if P.x < x_intersect:
				
				# an odd number of crossings means you are inside, an even number means you are outside
				inside = !inside
		
		# this moves us to the next edge of the polygon
		j = i
	
	return inside

func inverse_transform_point(T: Transform2D, P: Vector2) -> Vector2:
	# T = (A, t), where A = rotation/scaling matrix, t = translation vector
	# (P = A * P' + t) => (P' = A^-1 * (P - t))
	
	# A matrix components
	var a = T.x.x
	var b = T.x.y
	var c = T.y.x
	var d = T.y.y
	
	# t vector components
	var tx = T.origin.x
	var ty = T.origin.y
	
	# determinant
	var det = (a * d) - (b * c)
	
	# singular matrix case
	if abs(det) < 1e-8:
		push_error("Transform is not invertible!")
		return Vector2.ZERO
	
	# non-singular matrices have inverses
	var inv_det = 1.0 / det
	
	# step 1: subtract translation
	var Pt_x = P.x - tx
	var Pt_y = P.y - ty
	
	# step 2: apply inverse matrix
	var P_prime_x = ( d * Pt_x - c * Pt_y) * inv_det
	var P_prime_y = (-b * Pt_x + a * Pt_y) * inv_det
	
	return Vector2(P_prime_x, P_prime_y)

func give_me_my_packedvector2array_xD(bytes: PackedByteArray) -> PackedVector2Array:
	if bytes.size() % 8 != 0:
		return []
	
	var result: PackedVector2Array = []
	var count: int = bytes.size() / 8.0
	
	result.resize(count)
	
	for i in count:
		result[i] = Vector2(bytes.decode_float(i * 8), bytes.decode_float(i * 8 + 4))
	
	return result

func get_uint_arr(uint_packed_byte_arr: PackedByteArray) -> Array[int]:
	var arr: Array[int] = []
	for i in range(uint_packed_byte_arr.size() / 4):
		arr.append(uint_packed_byte_arr.decode_u32(i * 4))
	return arr

func get_uint_packed_byte_array(uint_arr: Array[int]) -> PackedByteArray:
	var byte_arr: PackedByteArray = PackedByteArray()
	byte_arr.resize(uint_arr.size() * 4)
	byte_arr.fill(0)
	for i in range(uint_arr.size()):
		byte_arr.encode_u32(i * 4, uint_arr[i])
	return byte_arr

func average(numbers: Array) -> float:
	var sum := 0.0
	for n in numbers:
		sum += n
	return sum / numbers.size()

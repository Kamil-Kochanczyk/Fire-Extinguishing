#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Densities {
    float densities[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer Pressures {
    float pressures[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer NearDensities {
    float near_densities[];
};

layout(set = 0, binding = 3, std430) restrict writeonly buffer NearPressures {
    float near_pressures[];
};

layout(set = 0, binding = 4, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float rest_density;
    float stiffness;
    float stiffness_near;
} params;

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    if (is_alive[id] == 0u) {
        pressures[id] = 0.0;
        near_pressures[id] = 0.0;
        return;
    }

    float rho = densities[id];
    float rho_near = near_densities[id];

    float pressure = params.stiffness * (rho - params.rest_density);

    // float term = rho / params.rest_density;
    // float term7 = term * term * term * term * term * term * term;
    // float pressure = (params.stiffness * params.rest_density / 7.0) * (term7 - 1.0);

    // test one of the following to reduce attractive behavior (keep only repulsive behavior)
    // pressure = max(pressure, 0.0);
    // pressure = (pressure < 0.0) ? 0.1 * pressure : pressure;

    float pressure_near = params.stiffness_near * rho_near;

    pressures[id] = pressure;
    near_pressures[id] = pressure_near;
}

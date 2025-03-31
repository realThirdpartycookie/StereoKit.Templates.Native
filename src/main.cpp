#include <stereokit.h>
#include <stereokit_ui.h>

#include "floor.hlsl.h"

using namespace sk;

// Variables used by the app.
material_t floor_mat;
mesh_t     floor_mesh;

mesh_t     cube_mesh;
material_t cube_mat;
pose_t     cube_pose = {{0,0,-0.5f}, quat_identity};

// app_settings is required by the Android binding code for inserting Activity
// values required for initialization.
sk_settings_t app_settings = {"SKNativeTemplate"};

// This main function signature is required for the Android binding code to
// invoke it. See /android/android_main.cpp for the binding code.
int main(int argc, char** argv) {

	// Initialize StereoKit.
	if (!sk_init(app_settings))
		return 1;

	// Initialize assets.
	shader_t floor_shader = shader_create_mem((void*)sks_floor_hlsl, sizeof(sks_floor_hlsl));
	floor_mesh = mesh_find      (default_id_mesh_cube);
	floor_mat  = material_create(floor_shader);
	material_set_transparency(floor_mat, transparency_blend);
	shader_release(floor_shader);

	cube_mesh = mesh_gen_rounded_cube(vec3_one * 0.1f, 0.02f, 4);
	cube_mat  = material_find        (default_id_material_ui);

	// Main app loop.
	sk_run([](){ // Step
		if (device_display_get_blend() == display_blend_opaque) { 
			mesh_draw(floor_mesh, floor_mat, matrix_ts({0,-1.5f,0}, {30,0.1f,30}));
		}

		ui_handle_begin("Cube", cube_pose, mesh_get_bounds(cube_mesh), false);
		render_add_mesh(cube_mesh, cube_mat, matrix_identity);
		ui_handle_end();
	}, [](){ // Shutdown
		mesh_release    (floor_mesh);
		material_release(floor_mat);
		mesh_release    (cube_mesh);
		material_release(cube_mat);
	});

	// Return based on why StereoKit quit.
	return sk_get_quit_reason() == quit_reason_user ? 0 : 1;
}
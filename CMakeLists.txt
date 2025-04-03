#[[ Quick usage guide!

- Update project() with the name of your app!
- Update ANDROID_PACKAGE_NAME with a better package name!
- Add additional code to `target_sources` near the end of this file!

See the readme for more extensive build instructions.

########################
# For Windows or Linux #
########################

# Make a folder to build in
mkdir build

# Configure the build
cmake -B build
# Build and run
cmake --build build -j8 --target run

########################
# For Android          #
########################

# Make a folder to build in
mkdir build-android

# Configure the build, I'll often make a .bat file for this configure command
# just to make it easier to do!
cmake -B build-android ^
  -G Ninja ^
  -DCMAKE_ANDROID_NDK=%ANDROID_NDK_HOME% ^
  -DCMAKE_SYSTEM_NAME=Android ^
  -DCMAKE_SYSTEM_VERSION=32 ^
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a
# Build an APK, install, and run it
cmake --build build-android -j8 --target run
# Or just build an APK
cmake --build build-android -j8 --target apk
]]

cmake_minimum_required(VERSION 3.19)
project(SKNativeTemplate VERSION "0.1.0" LANGUAGES CXX C)

# Vars for the Android APK
set(ANDROID_PACKAGE_NAME       "com.example.${PROJECT_NAME}")
set(ANDROID_MIN_SDK_VERSION    29)
set(ANDROID_TARGET_SDK_VERSION 32)

# Depending on target, we build a library, or an exe
if (ANDROID)
	add_library(${PROJECT_NAME} SHARED)
else()
	add_executable(${PROJECT_NAME})

	# Copy DLLs to the right spot so the executable can run. This looks a
	# little complex for compatibility with Linux, or on Windows if shared
	# libraries are switched to static. Both cases cause TARGET_RUNTIME_DLLS to
	# evaluate to an empty list and error the copy command.
	add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E "$<IF:$<BOOL:$<TARGET_RUNTIME_DLLS:${PROJECT_NAME}>>,copy_if_different $<TARGET_RUNTIME_DLLS:${PROJECT_NAME}> $<TARGET_FILE_DIR:${PROJECT_NAME}>,true>"
		COMMAND_EXPAND_LISTS)
	# Add a "run" target that allows us to build and run with a single command.
	add_custom_target(run DEPENDS ${PROJECT_NAME}
		COMMAND $<TARGET_FILE:${PROJECT_NAME}>
		WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
endif()

# Grab and build StereoKit from the GitHub repository. Here we're setting SK up
# as a statically linked library.
include(FetchContent)
set(SK_BUILD_TESTS       OFF CACHE INTERNAL "")
set(SK_BUILD_SHARED_LIBS ON  CACHE INTERNAL "") # Shared libraries allows for faster builds!
set(SK_PHYSICS           OFF CACHE INTERNAL "") # SK Physics is deprecated, simplifies build.
FetchContent_Declare(
	StereoKitC
	GIT_REPOSITORY https://github.com/StereoKit/StereoKit.git
	GIT_TAG        v0.3.10 ) # Version tag, could also be a branch name like "develop", or a git hash.
FetchContent_MakeAvailable(StereoKitC)
target_compile_options(StereoKitC
	$<$<CXX_COMPILER_ID:GNU,Clang>:-w -Wno-dev>
	$<$<CXX_COMPILER_ID:MSVC>:/W0>)

# Link to dependencies
target_link_libraries( ${PROJECT_NAME}
	PRIVATE StereoKitC
)

# Add source files to our target executable
target_sources( ${PROJECT_NAME} PRIVATE
	src/main.cpp
)

# Compile shaders to .h files for use in our code, you can find parameter docs
# for the shader compiler here: https://github.com/StereoKit/sk_gpu/blob/master/skshaderc/main.cpp#L247-L301
skshaderc_compile_headers( ${PROJECT_NAME}
	${CMAKE_BINARY_DIR}/shaders/
	"-O3 -si -t xe -i ${stereokitc_SOURCE_DIR}/tools/include"
	src/shaders/floor.hlsl
)

# This needs to be called at the end, or it may miss finding any shared
# libraries that are linked to the ${PROJECT_NAME} target.
if (ANDROID)
	include(android/AndroidBuild.cmake)
endif()

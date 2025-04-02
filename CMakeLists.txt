# For Android
# Install Android SDK
# Install Android NDK
# Install JDK
# NDK is good to have in PATH, it should be communicated via the toolchain
# -DCMAKE_TOOLCHAIN_FILE="%NDK%/build/cmake/android.toolchain.cmake"
# Android SDK should be indicated via ANDROID_SDK_ROOT
# -DANDROID_SDK_ROOT="C:/Data/Tools/Android" ^
# JDK bin should be in PATH
# C:\Program Files\Android\jdk\jdk-8.0.302.8-hotspot\jdk8u302-b08\bin

cmake_minimum_required(VERSION 3.21)
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

	# Add a "run" target that allows us to build and run with a single command.
	add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_RUNTIME_DLLS:${PROJECT_NAME}> $<TARGET_FILE_DIR:${PROJECT_NAME}>
		COMMAND_EXPAND_LISTS)
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

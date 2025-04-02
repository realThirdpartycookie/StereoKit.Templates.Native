# StereoKit Template for CMake

This is a basic StereoKit template for C/C++ using [CMake](https://cmake.org/). It's straightforward and portable way to build native StereoKit apps on Linux, Windows, and Android! This template works quite well with VS Code, and following the prompts provided there can get you running pretty quickly. CMake can also be used to generate a Visual Studio solution, for those that prefer that workflow.

This template directly references and builds the StereoKit repository rather than using pre-built binaries, so this template could also be great for those that wish to fork and modify StereoKit's code!

## Command line instructions

For those new to CMake, here's a quick example of how to compile and build this using the CLI! If something is going wrong, sometimes adding in a `-v` for verbose will give you some additional info you might not see from VS Code.

```shell
# From the project root directory

# Make a folder to build in
mkdir build
cd build

# Configure the build
cmake ..
# Build and run
cmake --build . -j8 --target run
```

# Linux

Linux users will need to install some pre-requisites for this template to compile.

```shell
sudo apt-get update
sudo apt-get install build-essential cmake unzip libfontconfig1-dev libgl1-mesa-dev libvulkan-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-glx0-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-randr0-dev libxrandr-dev libxxf86vm-dev mesa-common-dev libjsoncpp-dev libxfixes-dev libglew-dev
```

# Android

This template also supports building and running APKs for Android! Setup for this is more complicated, but no code changes are required to make this work. This template provides some glue code in the /android folder to handle the lifecyle of your Android app, and more advanced projects may want to dig around in there!

> If you don't care about Android, you can safely delete the /android folder of this repo. Nothing will break. Leaving it is fine too, it has no overhead.

## Android Setup

To build for Android, you need a few SDKs! [Android Studio](https://developer.android.com/studio)'s SDK Manager can be a good tool to work with these SDKs, but you can also install them directly!
[Android NDK](https://developer.android.com/ndk/downloads) 
- To build native binaries for Android
- Tested with version r25c
Android SDK
- To package and deploy APKs
- Tested with build-tools 32.0.0
Java SDK
- For signing keystores, and java boilerplate.

[Ninja](https://ninja-build.org/) 
- Windows: `winget install Ninja-build.Ninja`
- Linux (Ubuntu): `apt-get install ninja-build`

Environment or cmake variables required:
ANDROID_NDK_HOME
ANDROID_HOME
JAVA_HOME (or java bin folder in path)
ANDROID_BUILD_TOOLS_VERSION (optional)

## Android Build

```shell
# From the project root directory

# Make a folder to build in
mkdir build-android
cd build-android

# Configure the build
cmake .. ^
  -G Ninja ^
  -DCMAKE_ANDROID_NDK=%ANDROID_NDK_HOME% ^
  -DCMAKE_SYSTEM_NAME=Android ^
  -DCMAKE_SYSTEM_VERSION=32 ^
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a
# Build an APK, install, and run it
cmake --build . -j8 --target run
# Or just build an APK
cmake --build . -j8 --target apk
```
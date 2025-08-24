#!/bin/bash
# build_android_apk.sh: Configure and build or run the Android APK for StereoKit

set -e

# Prevent running with sudo/root so the SDK paths and adb device access use the user account
if [ "$(id -u)" -eq 0 ]; then
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        echo "This script should not be run with sudo. Re-running as $SUDO_USER..."
        exec sudo -u "$SUDO_USER" -H bash "$0" "$@"
    else
        echo "Please run this script without sudo." >&2
        exit 1
    fi
fi

export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"

echo "Configuring Android build..."
cmake -B build-android \
    -G Ninja \
    -DCMAKE_ANDROID_NDK="$ANDROID_NDK_HOME" \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_SYSTEM_VERSION=32 \
    -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
    -DJAVAC="$JAVA_HOME/bin/javac" \
    -DJava_JAVAC_EXECUTABLE="$JAVA_HOME/bin/javac"

echo "Choose build option:"
select opt in "Build and run APK on device" "Build APK only"; do
    case $REPLY in
        1)
            cmake --build build-android -j8 --target run
            break
            ;;
        2)
            cmake --build build-android -j8 --target apk
            break
            ;;
        *)
            echo "Invalid option. Please select 1 or 2."
            ;;
    esac
done

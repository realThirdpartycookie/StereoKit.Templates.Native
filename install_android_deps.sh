#!/bin/bash
# install_android-deps.sh: Install all dependencies for Android build on Linux

set -e

# Prevent running the whole script with sudo/root.
# We still use sudo for apt installs below, but the SDK should be under the user home, not /root.
if [ "$(id -u)" -eq 0 ]; then
  if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    echo "This script should not be run with sudo. Re-running as $SUDO_USER..."
    exec sudo -u "$SUDO_USER" -H bash "$0" "$@"
  else
    echo "Please run this script without sudo (it will use sudo only where needed)." >&2
    exit 1
  fi
fi

sudo apt update
sudo apt install -y cmake libx11-dev libxfixes-dev libegl-dev libgbm-dev libfontconfig-dev unzip curl zip ninja-build openjdk-8-jdk adb google-android-cmdline-tools-13.0-installer

export ANDROID_HOME="$HOME/Android/Sdk"

sdkmanager --sdk_root=$ANDROID_HOME \
  "platform-tools" \
  "platforms;android-32" \
  "build-tools;32.0.0" \
  "ndk;25.2.9519653"

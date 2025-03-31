
set(ANDROID_VERSION_NAME       "${CMAKE_PROJECT_VERSION}")
math(EXPR ANDROID_VERSION_CODE "${PROJECT_VERSION_MAJOR} * 10000 + ${PROJECT_VERSION_MINOR} * 100 + ${PROJECT_VERSION_PATCH}")

#set(ANDROID_SDK_ROOT "C:/Android") #### This needs to be not hard coded
set(BUILD_TOOLS_PATH "${ANDROID_SDK_ROOT}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}")
set(AAPT2    "${BUILD_TOOLS_PATH}/aapt2")
set(AAPT     "${BUILD_TOOLS_PATH}/aapt")
set(ZIPALIGN "${BUILD_TOOLS_PATH}/zipalign")
set(APKSIGN  "${BUILD_TOOLS_PATH}/apksigner")
set(D8       "${BUILD_TOOLS_PATH}/d8")
set(JAVAC    "javac")
# https://developer.android.com/tools/aapt2
# https://developer.android.com/build/building-cmdline

###############################################################################
## Keystore for signing the APK
###############################################################################

# Set default keystore variables
set(DEFAULT_KEYSTORE       "${CMAKE_SOURCE_DIR}/debug.keystore")
set(DEFAULT_KEYSTORE_ALIAS "androiddebugkey")
set(DEFAULT_KEYSTORE_PASS  "android")
set(DEFAULT_KEY_ALIAS_PASS "android")

# Check if keystore variables are provided, otherwise use defaults
set(KEYSTORE       "${DEFAULT_KEYSTORE}"       CACHE STRING "Path to the keystore")
set(KEY_ALIAS      "${DEFAULT_KEYSTORE_ALIAS}" CACHE STRING "Alias for the key")
set(KEYSTORE_PASS  "${DEFAULT_KEYSTORE_PASS}"  CACHE STRING "Password for the keystore")
set(KEY_ALIAS_PASS "${DEFAULT_KEY_ALIAS_PASS}" CACHE STRING "Password for the key")

find_program(KEYTOOL_EXECUTABLE NAMES keytool)
if(NOT EXISTS "${KEYSTORE}")
	message(STATUS "Keystore not found, generating new keystore...")
	execute_process(COMMAND ${KEYTOOL_EXECUTABLE}
		-genkeypair -v
		-keyalg RSA -keysize 2048 -validity 10000
		-keystore "${KEYSTORE}" -alias "${KEY_ALIAS}"
		-storepass "${KEYSTORE_PASS}" -keypass "${KEY_ALIAS_PASS}"
		-dname "CN=Android Debug,O=Android,C=US"
		RESULT_VARIABLE KEYTOOL_RESULT)
	if(NOT KEYTOOL_RESULT EQUAL "0")
		message(FATAL_ERROR "Failed to create keystore")
	endif()
endif()

# Debug message to confirm which keystore is being used
message(STATUS "Using keystore: ${KEYSTORE} with alias ${KEY_ALIAS}")

###############################################################################
## Add glue code and libraries
###############################################################################

# Modify the main project to include all libraries and code necessary to glue
# the app to Android.
target_link_libraries     (${PROJECT_NAME} PRIVATE android log )
target_include_directories(${PROJECT_NAME} PUBLIC  ${CMAKE_ANDROID_NDK}/sources/android/native_app_glue)
target_sources            (${PROJECT_NAME} PRIVATE 
	${CMAKE_ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c 
	android/android_main.cpp)

###############################################################################
## Get a list of shared libraries to pack
###############################################################################

# Here, we go through all libraries that ${PROJECT_NAME} depends on, check if
# they're shared, and then set up some paths for when we need to copy them into
# the APK. This currently doesn't do recursive searching, so if your
# dependencies have dependencies that are shared, you may need to improve this!
get_target_property(PROJECT_LIBRARIES ${PROJECT_NAME} LINK_LIBRARIES)
set(APK_SRC_LIBRARIES $<TARGET_FILE:${PROJECT_NAME}>)
set(APK_COPY_LIBRARIES lib/${ANDROID_ABI}/$<TARGET_FILE_NAME:${PROJECT_NAME}>)
foreach(CURR ${PROJECT_LIBRARIES})
	if (TARGET ${CURR})
		get_target_property(TARGET_TYPE ${CURR} TYPE)
		if(${TARGET_TYPE} STREQUAL "SHARED_LIBRARY")
			list(APPEND APK_SRC_LIBRARIES $<TARGET_FILE:${CURR}>)
			list(APPEND APK_COPY_LIBRARIES lib/${ANDROID_ABI}/$<TARGET_FILE_NAME:${CURR}>)
		endif()
	endif()
endforeach()

###############################################################################
## Building the APK
###############################################################################

# If these files exist from a previous build, we get overwrite errors when
# generating the APK.
set(APK_DIR "${CMAKE_CURRENT_BINARY_DIR}/apk")
set(APK_NAME_ROOT ${APK_DIR}/${PROJECT_NAME})
 
# We need to make a few folders so copies can succeed when copying to them.
file(MAKE_DIRECTORY 
	"${APK_DIR}/obj"
	"${APK_DIR}/lib/${ANDROID_ABI}")

# Manifest has a couple name/number variables that we want to resolve nicely!
configure_file(
	android/AndroidManifest.xml
	${APK_DIR}/obj/AndroidManifest.xml
	@ONLY)

# Put together a dummy java file for the APK
file(WRITE ${APK_DIR}/src/android/Empty.java "public class Empty {}")
add_custom_command(
	DEPENDS ${APK_DIR}/src/android/Empty.java
	OUTPUT  ${APK_DIR}/obj/classes.dex
	COMMAND ${JAVAC} -d ${APK_DIR}/obj -classpath ${ANDROID_SDK_ROOT}/platforms/${ANDROID_PLATFORM}/android.jar -sourcepath src ${APK_DIR}/src/android/Empty.java
	COMMAND ${D8} --release ${APK_DIR}/obj/Empty.class --output ${APK_DIR}/obj
	COMMENT "Building Java boilerplate for APK" )

# Build the resources
add_custom_command(
	OUTPUT  ${APK_DIR}/obj/apk_resources.zip
	DEPENDS ${CMAKE_SOURCE_DIR}/android/resources
	COMMAND ${AAPT2} compile
		--dir ${CMAKE_SOURCE_DIR}/android/resources
		-o ${APK_DIR}/obj/apk_resources.zip
	COMMENT "Compiling APK resources" )

# Assemble the base APK, resources and assets
add_custom_command(
	DEPENDS
		${CMAKE_SOURCE_DIR}/assets
		${APK_DIR}/obj/classes.dex
		${APK_DIR}/obj/apk_resources.zip
		${APK_DIR}/obj/AndroidManifest.xml
	OUTPUT
		${APK_NAME_ROOT}.1.unaligned.apk 
	COMMAND ${CMAKE_COMMAND} -E rm -f ${APK_NAME_ROOT}.1.unaligned.apk
	COMMAND ${AAPT2} link # Link all the files into an APK
		-o ${APK_NAME_ROOT}.1.unaligned.apk 
		--manifest ${APK_DIR}/obj/AndroidManifest.xml
		-A ${CMAKE_SOURCE_DIR}/assets
		-I ${ANDROID_SDK_ROOT}/platforms/${ANDROID_PLATFORM}/android.jar
		${APK_DIR}/obj/apk_resources.zip
	COMMAND cd ${APK_DIR}/obj
	COMMAND ${AAPT} add ${APK_NAME_ROOT}.1.unaligned.apk classes.dex
    COMMENT "Building base APK")

# Assemble the final APK, add binaries and align/sign the base APK
add_custom_command(
	DEPENDS
		${PROJECT_NAME}
		${APK_NAME_ROOT}.1.unaligned.apk
	OUTPUT
		${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.apk
	COMMAND ${CMAKE_COMMAND} -E rm -f
		${APK_NAME_ROOT}.2.aligned.apk
		${APK_NAME_ROOT}.3.unsigned.apk
		${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.apk
	COMMAND cd ${APK_DIR}/obj
	COMMAND ${CMAKE_COMMAND} -E copy
		${APK_SRC_LIBRARIES}
		${APK_DIR}/lib/${ANDROID_ABI}/
	COMMAND cd ${APK_DIR}
	COMMAND ${CMAKE_COMMAND} -E copy ${APK_NAME_ROOT}.1.unaligned.apk ${APK_NAME_ROOT}.2.aligned.apk
	COMMAND ${AAPT} add ${APK_NAME_ROOT}.2.aligned.apk ${APK_COPY_LIBRARIES}
	COMMAND ${ZIPALIGN} 4 ${APK_NAME_ROOT}.2.aligned.apk ${APK_NAME_ROOT}.3.unsigned.apk
	COMMAND ${APKSIGN} sign --ks ${KEYSTORE} --ks-key-alias ${KEY_ALIAS} --ks-pass pass:${KEYSTORE_PASS} --key-pass pass:${KEY_ALIAS_PASS} --out ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.apk ${APK_NAME_ROOT}.3.unsigned.apk
	COMMENT "Building final APK")

# Wrap up APK building into a target!
add_custom_target(apk
	DEPENDS 
		${PROJECT_NAME} 
		${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.apk
	COMMENT "Building Android APK")

# A convenience target for installing and running the APK we build.
add_custom_target(run
	DEPENDS apk
	COMMAND ${ANDROID_SDK_ROOT}/platform-tools/adb install ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.apk
	COMMAND ${ANDROID_SDK_ROOT}/platform-tools/adb shell am start -n ${ANDROID_PACKAGE_NAME}/android.app.NativeActivity
	COMMENT "Running Android APK")
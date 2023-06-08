cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "videna")
project(${PROJECT_NAME} LANGUAGES C)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

include(ExternalProject)
ExternalProject_Add(
    FFmpeg
    PREFIX "FFmpeg"
    URL "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2023-01-31-12-37/ffmpeg-n5.1.2-11-g30d432f205-win64-lgpl-shared-5.1.zip"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND "")

set(FFmpeg_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/FFmpeg/src/FFmpeg/bin")

set(videna_bundled_libraries "${FFmpeg_BIN_DIR}/avcodec-59.dll"
"${FFmpeg_BIN_DIR}/avdevice-59.dll"
"${FFmpeg_BIN_DIR}/avformat-59.dll"
"${FFmpeg_BIN_DIR}/avfilter-8.dll"
"${FFmpeg_BIN_DIR}/avutil-57.dll"
"${FFmpeg_BIN_DIR}/swresample-4.dll"
"${FFmpeg_BIN_DIR}/swscale-6.dll"
"${CMAKE_CURRENT_SOURCE_DIR}/../bin/libvidena.dll"
PARENT_SCOPE)

cmake_minimum_required(VERSION 3.13.1)

set(PROJECT_NAME "videna")

project(${PROJECT_NAME} LANGUAGES C)

set(BUILD_SHARED_LIBS ON)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

add_library(videna SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../src/navigator.c")

include(FetchContent)
FetchContent_Declare(
    FFmpeg
    URL "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2023-01-31-12-37/ffmpeg-n5.1.2-11-g30d432f205-linux64-lgpl-shared-5.1.tar.xz"
    )

FetchContent_MakeAvailable(FFmpeg)

set(FFmpeg_LIB_DIR "${CMAKE_BINARY_DIR}/_deps/ffmpeg-src/lib")

set(videna_bundled_libraries "${FFmpeg_LIB_DIR}/libavcodec.so.59.37.100"
"${FFmpeg_LIB_DIR}/libavdevice.so.59.7.100"
"${FFmpeg_LIB_DIR}/libavformat.so.59.27.100"
"${FFmpeg_LIB_DIR}/libavfilter.so.8.44.100"
"${FFmpeg_LIB_DIR}/libavutil.so.57.28.100"
"${FFmpeg_LIB_DIR}/libswresample.so.4.7.100"
"${FFmpeg_LIB_DIR}/libswscale.so.6.7.100"
"${CMAKE_CURRENT_BINARY_DIR}/libvidena.so"
PARENT_SCOPE)


set(FFmpeg_INCLUDE_DIR "${CMAKE_BINARY_DIR}/_deps/ffmpeg-src/include")

set(AVCODEC_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libavcodec")
set(AVCODEC_LIBRARY "${FFmpeg_LIB_DIR}/libavcodec.so.59")

set(AVFORMAT_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libavformat")
set(AVFORMAT_LIBRARY "${FFmpeg_LIB_DIR}/libavformat.so.59")

set(AVUTIL_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libavutil")
set(AVUTILTIME_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libavutil")
set(AVUTILIMGUTILS_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libavutil")
set(AVUTILFRAME_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libavutil")
set(AVUTIL_LIBRARY "${FFmpeg_LIB_DIR}/libavutil.so.57")

set(SWSCALE_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libswscale")
set(SWSCALE_LIBRARY "${FFmpeg_LIB_DIR}/libswscale.so.6")

set(SWRESAMPLE_INCLUDE_DIR "${FFmpeg_INCLUDE_DIR}/libswresample")
set(SWRESAMPLE_LIBRARY "${FFmpeg_LIB_DIR}/libswresample.so.4")

target_include_directories(videna PRIVATE ${FFmpeg_INCLUDE_DIR})
target_link_libraries(videna PRIVATE ${AVCODEC_LIBRARY} ${AVFORMAT_LIBRARY} ${AVUTIL_LIBRARY} ${SWSCALE_LIBRARY} ${SWRESAMPLE_LIBRARY})
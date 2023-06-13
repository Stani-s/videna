


#-------------------------------------------------------------------------
#- This CMAKELIST is the one used to build the shared library for windows found in ../bin
#- For building it the gcc-TDM compiler should be used
cmake_minimum_required(VERSION 3.14.1)

set(PROJECT_NAME "videna_windows")

project(${PROJECT_NAME} LANGUAGES C)

include(ExternalProject)
ExternalProject_Add(
    FFmpeg
    PREFIX "FFmpeg"
    URL https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2023-01-31-12-37/ffmpeg-n5.1.2-11-g30d432f205-win64-lgpl-shared-5.1.zip
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND "")

set(BUILD_SHARED_LIBS ON)

include_directories(${CMAKE_BINARY_DIR}/FFmpeg/src/FFmpeg/include)
link_directories(${CMAKE_BINARY_DIR}/FFmpeg/src/FFmpeg/lib)

add_library(videna SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../src/navigator.c")

find_path(AVCODEC_INCLUDE_DIR libavcodec/avcodec.h)
find_library(AVCODEC_LIBRARY avcodec)

find_path(AVFORMAT_INCLUDE_DIR libavformat/avformat.h)
find_library(AVFORMAT_LIBRARY avformat)

find_path(AVUTIL_INCLUDE_DIR libavutil/avutil.h)
find_path(AVUTILTIME_INCLUDE_DIR libavutil/time.h)
find_path(AVUTILIMGUTILS_INCLUDE_DIR libavutil/imgutils.h)
find_path(AVUTILFRAME_INCLUDE_DIR libavutil/frame.h)
find_library(AVUTIL_LIBRARY avutil)

find_path(SWSCALE_INCLUDE_DIR libswscale/swscale.h)
find_library(SWSCALE_LIBRARY swscale)

target_include_directories(videna PRIVATE avcodec avformat avutil imgutils)

target_link_libraries(videna PRIVATE avcodec avformat avutil swscale)

add_dependencies(videna FFmpeg)

install(TARGETS videna RUNTIME DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}")

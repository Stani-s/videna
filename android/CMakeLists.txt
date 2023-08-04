cmake_minimum_required(VERSION 3.10)

project(videna_andr LANGUAGES C)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/build/_deps/FFmpeg-src/include/)
set(FFmpeg_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/build/_deps/FFmpeg-kit-src/jni/${ANDROID_ABI}/")

add_library(videna SHARED
        ${CMAKE_CURRENT_SOURCE_DIR}/../src/navigator.c
)

find_path(AVCODEC_INCLUDE_DIR libavcodec/)
set(AVCODEC_LIBRARY "${FFmpeg_LIB_DIR}/libavcodec.so")

find_path(AVFORMAT_INCLUDE_DIR libavformat/)
set(AVFORMAT_LIBRARY "${FFmpeg_LIB_DIR}/libavformat.so")

find_path(AVUTIL_INCLUDE_DIR libavutil/)
find_path(AVUTILTIME_INCLUDE_DIR libavutil/time.h)
find_path(AVUTILIMGUTILS_INCLUDE_DIR libavutil/imgutils.h)
find_path(AVUTILFRAME_INCLUDE_DIR libavutil/frame.h)
set(AVUTIL_LIBRARY "${FFmpeg_LIB_DIR}/libavutil.so")

find_path(SWSCALE_INCLUDE_DIR libswscale/swscale.h)
set(SWSCALE_LIBRARY "${FFmpeg_LIB_DIR}/libswscale.so")

set(SWRESAMPLE_LIBRARY "${FFmpeg_LIB_DIR}/libswresample.so")

if (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    set(AVCODEC_LIBRARY ${FFmpeg_LIB_DIR}/libavcodec_neon.so)
    set(AVFORMAT_LIBRARY ${FFmpeg_LIB_DIR}/libavformat_neon.so)
    set(AVUTIL_LIBRARY ${FFmpeg_LIB_DIR}/libavutil_neon.so)
    set(SWSCALE_LIBRARY ${FFmpeg_LIB_DIR}/libswscale_neon.so)
    set(SWRESAMPLE_LIBRARY ${FFmpeg_LIB_DIR}/libswresample_neon.so)
endif()

target_include_directories(videna PUBLIC AVCODEC_INCLUDE_DIR AVFORMAT AVUTIL_INCLUDE_DIR)

target_link_libraries(videna PUBLIC ${AVCODEC_LIBRARY} ${AVFORMAT_LIBRARY} ${AVUTIL_LIBRARY} ${SWSCALE_LIBRARY})
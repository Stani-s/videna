cmake_minimum_required(VERSION 3.10)

project(videna_deps)
include(FetchContent)
FetchContent_Declare(
    FFmpeg
    URL "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2023-01-31-12-37/ffmpeg-n5.1.2-11-g30d432f205-linux64-lgpl-shared-5.1.tar.xz"
    )

FetchContent_MakeAvailable(FFmpeg)

FetchContent_Declare(
    FFmpeg-kit
    URL "https://repo1.maven.org/maven2/com/arthenica/ffmpeg-kit-full/5.1/ffmpeg-kit-full-5.1.aar"
    )
FetchContent_MakeAvailable(FFmpeg-kit)

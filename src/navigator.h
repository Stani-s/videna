// This file is a part of videna.
// Copyright (C) 2023 Stanisław Talejko <stalejko@gmail.com>
//
// videna is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 3 of the License, or (at your option) any later version.
//
// videna is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#ifndef NAVIGATOR_H
#define NAVIGATOR_H
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/rational.h>
#include <libavutil/time.h>
#include <libavutil/imgutils.h>
#include <libavutil/frame.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

#if _WIN32
#define FFI_EXPORT __declspec(dllexport)
#else
#define FFI_EXPORT
#endif

#define UNKOWN_FORMAT 7

enum formats {
    formatRGBA,
    formatBGRA,
    formatARGB,
    formatABGR,
    formatYUV420P,
    formatGRAY8A,
    formatGRAY16LE
};

const int fmt[] = {
    AV_PIX_FMT_RGBA,
    AV_PIX_FMT_BGRA,
    AV_PIX_FMT_ARGB,
    AV_PIX_FMT_ABGR,
    AV_PIX_FMT_YUV420P,
    AV_PIX_FMT_GRAY8A,
    AV_PIX_FMT_GRAY16LE
};

typedef struct {
    int size;
    int width;
    int height;
    int format;
    uint8_t* data;
    int64_t pts;
    int delay;
    int64_t dts;
    int64_t dtsProgress;
    int64_t progress; // in milliseconds
    int exists;
} ReadyFrame;

typedef struct {
    int64_t startTime;
    int64_t duration;
    int64_t timescale;
    int width;
    int height;
    int numStreams;
} Metadata;

typedef struct {
    int size;
    AVFrame* pFrame;
    int inUse;
    int height;
    int width;
    int64_t pts;
    int64_t delay;
    #ifdef _WIN32
    HANDLE mutex;
    #else
    pthread_mutex_t mutex;
    #endif
} PlayerFrame;

typedef struct {
    AVFormatContext * pFormatContext;
    int videoIndex;
    AVStream* videoStream;
    AVCodecContext* pCodecContext;
    PlayerFrame* pPlayerFrame;

    struct SwsContext * sws_context;
    
    int64_t last_dts;
    int64_t last_pts;
    int64_t last_pts_delay;
    AVRational time_base;
    int format;
    int timescale;
    
    int width;
    int height;

    #ifdef _WIN32
    HANDLE mutex;
    #else
    pthread_mutex_t mutex;
    #endif
    // decoder block
    AVPacket* Dpacket;
    AVFrame* Dframe;

} VideoState;

FFI_EXPORT void* openVideo(char* path, int pxl, int width, int height);

FFI_EXPORT int make_frame(void* videoStateV);

FFI_EXPORT ReadyFrame retrieveFrame(void* videoStateV);

FFI_EXPORT void freeNativeFrame(void* videoStateV);

FFI_EXPORT void disposeVideo(void* videoStateV);

FFI_EXPORT int64_t findEOF(VideoState* videoState);

FFI_EXPORT int64_t calculateTimeStampFromJump(void* videoStateV, int64_t currPts, int numFrames);

FFI_EXPORT int64_t calculateTimeStamp(void* videoStateV, int64_t mseconds);

FFI_EXPORT Metadata getMetadata(char* path);

FFI_EXPORT void resize(void* videoStateV, int width, int height);

FFI_EXPORT int seek_time(void* videoStateV, int64_t mseconds, int backward);

FFI_EXPORT int seek_precise(void* videoStateV, int64_t pts, int backward);

FFI_EXPORT void disposeVideo(void* videoStateV);

#endif
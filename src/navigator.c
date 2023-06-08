// This file is a part of videna.
// Copyright (c) 2023 Stanisław Talejko <stalejko@gmail.com>
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

#include "navigator.h"

#ifdef _WIN32
static void init_lock(HANDLE* mutex) {
    *mutex = CreateMutex(NULL,false,NULL);
}
static int lock(HANDLE* mutex) {
    DWORD ret = WaitForSingleObject(*mutex, INFINITE);
    if (ret == WAIT_OBJECT_0) {
        return 0;
    }
    return -1;
}
static int unlock(HANDLE* mutex) {
    bool ret = ReleaseMutex(*mutex);
    if (ret){
        return 0;
    }
    return -1;
}
static void destroy_lock(HANDLE* mutex) {
    CloseHandle(*mutex);
}
#elif __unix__
static void init_lock(pthread_mutex_t* mutex) {
    pthread_mutex_init(mutex, NULL);
}
static int lock(pthread_mutex_t* mutex) {
    pthread_mutex_lock(mutex);
    return 0;
}
static int unlock(pthread_mutex_t* mutex) {
    pthread_mutex_unlock(mutex);
    return 0;
}
static void destroy_lock(pthread_mutex_t* mutex) {
    pthread_mutex_destroy(mutex);
}
#endif


static int rescale_frame(VideoState* videoState, AVFrame* pFrame, int64_t ptsPacket);

FFI_EXPORT void* openVideo(char* path, int pxl, int width, int height){
    AVFormatContext* pFormatContext = NULL;
    const AVCodec* pCodec = NULL;
    AVCodecContext* pCodecContext = NULL;
    VideoState* videoState;
    int videoStream = -1;
    int ret = 0;
    struct SwsContext* sws_ctx = NULL;

    avformat_open_input(&pFormatContext, path, NULL, NULL);
    
    avformat_find_stream_info(pFormatContext, NULL);
    for (unsigned int i = 0; i < pFormatContext->nb_streams; i++) {
        if(pFormatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStream = i;
            pCodec = avcodec_find_decoder(pFormatContext->streams[i]->codecpar->codec_id);
            if (pCodec == NULL) {
                printf("Codec isn't supported\n");
                return NULL;
            }
            break;
        }
    }

    if (videoStream == -1 ) {
        printf("Could not find video stream\n");
        return NULL;
    }

    pCodecContext = avcodec_alloc_context3(pCodec);
    ret = avcodec_parameters_to_context(pCodecContext,pFormatContext->streams[videoStream]->codecpar);
    if (ret != 0) {
        printf("Failed while copying params\n");
        return NULL;
    }

    ret = avcodec_open2(pCodecContext,pCodec,NULL);
    if (ret != 0) {
        printf("Failed on open_codec2\n");
        return NULL;
    }
    videoState = av_mallocz(sizeof(VideoState));

    if (pxl >= 0 && pxl < sizeof(fmt)/sizeof(fmt[0])) {
        sws_ctx = sws_getContext(pCodecContext->width,
                            pCodecContext->height,
                            pCodecContext->pix_fmt,
                            pCodecContext->width,
                            pCodecContext->height,
                            fmt[pxl],
                            SWS_BILINEAR,
                            NULL,
                            NULL,
                            NULL
                            );

        if (sws_ctx == NULL) {
            return NULL;
        }
        
        videoState->sws_context = sws_ctx;
    }
    
    videoState->pFormatContext = pFormatContext;
    videoState->pCodecContext = pCodecContext;
    videoState->width = pCodecContext->width;
    videoState->height = pCodecContext->height;
    videoState->videoIndex = videoStream;
    videoState->videoStream = pFormatContext->streams[videoStream];
    videoState->time_base = pFormatContext->streams[videoStream]->time_base;
    videoState->format = pxl;
    videoState->timescale = videoState->time_base.den;
    init_lock(&videoState->mutex);
    videoState->pPlayerFrame = av_mallocz(sizeof(PlayerFrame));
    init_lock(&videoState->pPlayerFrame->mutex);    
    if (width == 0 || height == 0) {
        videoState->pPlayerFrame->width = videoState->width;
        videoState->pPlayerFrame->height = videoState->height;
    }
    else {
        videoState->pPlayerFrame->width = width;
        videoState->pPlayerFrame->height = height;
    }
    videoState->Dpacket = av_packet_alloc();
    videoState->Dframe = av_frame_alloc();
    if (videoState->Dpacket == NULL) {
        printf("No memory for packet\n");
        return NULL;
    }
    if (videoState->Dframe == NULL ) {
        printf("No memory for frame\n");
        return NULL;
    }
    return (void*)videoState;
}

static int decode_frame(VideoState* videoState){
    int frameReady = 0;
    int ret;
    int quitting = 0;
    int localPts = 0;
    AVPacket* pPacket = videoState->Dpacket;
    AVFrame* pFrame = videoState->Dframe;
    for (;;) {
        frameReady = 0;
        if (quitting){
            return -1;
        }
        ret = av_read_frame(videoState->pFormatContext, pPacket);
        if (ret < 0){
            return -2;
        }
        
        if (pPacket->stream_index == videoState->videoIndex){
            localPts = pPacket->pts;
            ret = avcodec_send_packet(videoState->pCodecContext, pPacket) == AVERROR(EAGAIN);
            if (ret < 0){
                quitting =1;
                return -1;
            }
            while (ret >= 0) {
                ret = avcodec_receive_frame(videoState->pCodecContext, pFrame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    if (ret == AVERROR_EOF){
                        av_packet_unref(pPacket);
                        return -2;
                    }
                    av_frame_unref(pFrame);
                    break;
                }
                else if (ret < 0) {
                    quitting =1;
                    av_frame_unref(pFrame);
                    break;
                }
                else if (ret >= 0){
                    videoState->last_dts = pFrame->pkt_dts;
                    frameReady = 1;
                    break;
                }
                //pts
            }
            if (frameReady && ret >= 0) {
                break;
            }

            
        }
        av_packet_unref(pPacket);
    }
    
    av_packet_unref(pPacket);
    return localPts;
}

FFI_EXPORT int make_frame(void* videoStateV) {
    VideoState* videoState = (VideoState*) videoStateV;
    int ret = decode_frame(videoState);
    if (ret < 0) {
        return ret;
    }

    return rescale_frame(videoState, videoState->Dframe, ret);
}

static int64_t calculateSyncMini(VideoState* videoState, int64_t ptsPacket) {
    if (videoState->Dframe->pts == AV_NOPTS_VALUE) {
        videoState->Dframe->pts = videoState->Dframe->best_effort_timestamp;
    }
    if (videoState->Dframe->pts < 0) {
        videoState->Dframe->pts = ptsPacket;
    }

    return videoState->Dframe->pts;
}

static int64_t calculateSync(VideoState* videoState, AVFrame* pFrame, int64_t ptsPacket){
    //missing guess pts;
    if (pFrame->pts == AV_NOPTS_VALUE) {
        pFrame->pts = pFrame->best_effort_timestamp;
    }
    if (pFrame->pts < 0) {
        pFrame->pts = ptsPacket;
    }
    int64_t pts = pFrame->pts;
    int64_t us_delay;
    int64_t pts_delay;

    pts_delay = pts - videoState->last_pts;
    if (pts_delay <= 0 || (pts_delay > 5 * videoState->last_pts_delay && videoState->last_pts_delay != 0)) {
        pts_delay = videoState->last_pts_delay;
    }
    videoState->last_pts = pts;
    videoState->last_pts_delay = pts_delay;
    us_delay = av_rescale_q(pts_delay,videoState->time_base, AV_TIME_BASE_Q);
    videoState->pPlayerFrame->delay = us_delay;
    return pts;
}

static int rescale_frame(VideoState* videoState, AVFrame* pFrame, int64_t ptsPacket){
    PlayerFrame* pPlayerFrame = videoState->pPlayerFrame;
    
    while (pPlayerFrame->inUse) {
        av_usleep(1000);
    }

    if (lock(&pPlayerFrame->mutex) < 0) {
        return -1;
    }
    pPlayerFrame->pts = calculateSync(videoState, pFrame, ptsPacket);
    
    if (videoState->sws_context != NULL) {
        if (pPlayerFrame->pFrame ==  NULL                                       // I don't have to do scaling( do it in dart)
                            || pPlayerFrame->width != pFrame->width || pPlayerFrame->height != pFrame->height) {
            if (pPlayerFrame->pFrame != NULL){
                av_frame_free(&pPlayerFrame->pFrame);
                av_free(pPlayerFrame->pFrame);
            }
            pPlayerFrame->pFrame = av_frame_alloc();
            pPlayerFrame->size = av_image_alloc(pPlayerFrame->pFrame->data,
                pPlayerFrame->pFrame->linesize,
                pPlayerFrame->width,
                pPlayerFrame->height,
                fmt[videoState->format],32);
            pPlayerFrame->pFrame->pkt_dts = pFrame->pkt_dts;
        }
        videoState->sws_context = sws_getCachedContext(videoState->sws_context, videoState->width,
                                videoState->height,
                                videoState->pCodecContext->pix_fmt,
                                pPlayerFrame->width,
                                pPlayerFrame->height,
                                fmt[videoState->format],
                                SWS_BILINEAR,
                                NULL,
                                NULL,
                                NULL
                                );
        sws_scale(videoState->sws_context, (const uint8_t * const*)pFrame->data,
            pFrame->linesize, 0, videoState->height, // is height best?
            (uint8_t* const*)pPlayerFrame->pFrame->data, pPlayerFrame->pFrame->linesize);
        av_frame_unref(pFrame);
    }
    else {
        pPlayerFrame->pFrame = pFrame;
    }
    pPlayerFrame->inUse = 1;
    if (unlock(&pPlayerFrame->mutex) < 0) {
        return -1;
    }
    return videoState->pPlayerFrame->pts;
}

FFI_EXPORT int64_t calculateTimeStampFromJump(void* videoStateV, int64_t currPts, int numFrames){
    VideoState* videoState = (VideoState*) videoStateV;
    return currPts + numFrames*videoState->last_pts_delay - videoState->pCodecContext->delay*videoState->last_pts_delay;
}

FFI_EXPORT int64_t calculateTimeStamp(void* videoStateV, int64_t mseconds) {
    VideoState* videoState = (VideoState*) videoStateV;
    AVRational thou;
    thou.num = 1; 
    thou.den = 1000;
    return av_rescale_q(mseconds, videoState->time_base, thou);
    
}

FFI_EXPORT Metadata getMetadata(char* path){ 
    VideoState* videoState = (VideoState *) openVideo(path, UNKOWN_FORMAT, 0, 0);
    AVRational thou;
    int formatSet = 0;
    thou.num = 1;
    thou.den = 1000;
    PlayerFrame *pPlayerFrame;
    Metadata meta;
    if (!videoState) {
        return meta;
    }
    meta.startTime = av_rescale_q(videoState->videoStream->start_time, videoState->time_base, AV_TIME_BASE_Q);
    meta.duration = findEOF(videoState);
    meta.timescale = videoState->timescale;
    meta.width = videoState->width;
    meta.height = videoState->height;
    meta.numStreams = videoState->pFormatContext->nb_streams;
    disposeVideo(videoState);
    return meta;
}

FFI_EXPORT void resize(void* videoStateV, int width, int height) {
    VideoState* videoState = (VideoState*) videoStateV;
    videoState->pPlayerFrame->width = width;
    videoState->pPlayerFrame->height = height;
}

FFI_EXPORT int seek_time(void* videoStateV, int64_t mseconds, int backward){
    //
    VideoState* videoState = (VideoState*) videoStateV;
    int flags = AVSEEK_FLAG_BACKWARD * backward;
    AVRational thou;
    thou.num = 1;
    thou.den = 1000;
    int pts = av_rescale_q(mseconds, videoState->time_base, thou);
    int ret;
    ret = av_seek_frame(videoState->pFormatContext, videoState->videoIndex, pts, flags);
    if (ret < 0){
        return -1;
    }
    avcodec_flush_buffers(videoState->pCodecContext);
    return 0;
}

static int catchUp(void* videoStateV, int pts){
    VideoState* videoState = (VideoState*) videoStateV;
    int64_t ret = 0;
    while (ret >= 0) {
        ret = decode_frame(videoState);
        if (calculateSyncMini(videoState, ret) >= pts - 0.5*videoState->last_pts_delay) {
            return rescale_frame(videoState, videoState->Dframe, ret);
        }
        av_frame_unref(videoState->Dframe);
        freeNativeFrame(videoStateV);
    }
    return ret;
}

FFI_EXPORT int seek_precise(void* videoStateV, int64_t pts, int backward){
    VideoState* videoState = (VideoState*) videoStateV;
    if (backward) {
        int ret;
        ret = av_seek_frame(videoState->pFormatContext, videoState->videoIndex, pts, AVSEEK_FLAG_BACKWARD);
        if (ret < 0){
            return -1;
        }
        avcodec_flush_buffers(videoState->pCodecContext);
    }
    return catchUp(videoStateV,pts);
}

FFI_EXPORT int64_t findEOF(VideoState* videoState){
    int ret = av_seek_frame(videoState->pFormatContext,
                            videoState->videoIndex,
                            av_rescale_q(videoState->pFormatContext->duration, AV_TIME_BASE_Q, videoState->time_base),
                            AVSEEK_FLAG_BACKWARD);
    if (ret < 0){
        return -1;
    }
    avcodec_flush_buffers(videoState->pCodecContext);
    while (ret >= 0) {
        ret = decode_frame(videoState);
        if (ret == -2) {
            AVRational thou;
            thou.num = 1;
            thou.den = 1000;
            ret = av_rescale_q(videoState->last_dts, videoState->time_base, thou);
            av_frame_unref(videoState->Dframe);
            freeNativeFrame(videoState);
            break;
        }
        av_frame_unref(videoState->Dframe);
        freeNativeFrame(videoState);
    }
    return ret;
}

FFI_EXPORT void disposeVideo(void* videoStateV){
    VideoState* videoState = (VideoState*) videoStateV;
    while (videoState->pPlayerFrame->inUse) {
        av_usleep(1000);
    }
    lock(&videoState->pPlayerFrame->mutex);
    av_frame_free(&videoState->Dframe);
    av_free(videoState->Dframe);
    av_packet_free(&videoState->Dpacket);
    av_free(videoState->Dpacket);
    avformat_close_input(&videoState->pFormatContext);
    avformat_free_context(videoState->pFormatContext);
    av_free(videoState->pFormatContext);
    avcodec_free_context(&videoState->pCodecContext);
    av_free(videoState->pCodecContext);
    destroy_lock(&videoState->mutex);
    av_frame_free(&videoState->pPlayerFrame->pFrame);
    av_free(videoState->pPlayerFrame->pFrame);
    unlock(&videoState->pPlayerFrame->mutex);
    destroy_lock(&videoState->pPlayerFrame->mutex);
    av_free(videoState->pPlayerFrame);
    sws_freeContext(videoState->sws_context);
    av_free(videoState);
}

FFI_EXPORT ReadyFrame retrieveFrame(void* videoStateV) {
    VideoState* videoState = (VideoState*) videoStateV;
    PlayerFrame* pPlayerFrame = videoState->pPlayerFrame;
    int formatSet = 0;
    ReadyFrame readyFrame;
    if (lock(&pPlayerFrame->mutex) < 0) {
        readyFrame.exists = -1;
        return readyFrame;
    }
    readyFrame.size = pPlayerFrame->size;
    readyFrame.width = pPlayerFrame->width;
    readyFrame.height = pPlayerFrame->height;
    readyFrame.data = pPlayerFrame->pFrame->data[0];
    readyFrame.pts = pPlayerFrame->pts;
    readyFrame.delay = pPlayerFrame->delay;
    AVRational thou;
    thou.num = 1;
    thou.den = 1000;
    readyFrame.dts = videoState->last_dts;
    readyFrame.dtsProgress = av_rescale_q(videoState->last_dts, videoState->time_base, thou);
    readyFrame.progress = av_rescale_q(pPlayerFrame->pts, videoState->time_base, thou);
    readyFrame.format = videoState->format;
    if (unlock(&videoState->pPlayerFrame->mutex) < 0) {
        readyFrame.exists = -1;
        return readyFrame;
    }
    return readyFrame;
}

FFI_EXPORT void freeNativeFrame(void* videoStateV){
    VideoState* videoState = (VideoState*) videoStateV;
    lock(&videoState->pPlayerFrame->mutex);
    videoState->pPlayerFrame->inUse = 0;
    unlock(&videoState->pPlayerFrame->mutex);
}
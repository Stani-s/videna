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

import 'dart:collection';
import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'package:async/async.dart';
import 'dart:isolate';
import 'dart:core';
import 'package:ffi/ffi.dart';
import 'package:fraction/fraction.dart';
import 'install.dart';
import 'ffi.dart';
import 'frame.dart';
export 'frame.dart';
import 'media_metadata.dart';
export 'media_metadata.dart';
import 'exceptions.dart';

int isNavigatorInitialized = 0;

abstract class Videna {
  /// This method ensures the required binaries are installed
  static void initialize() {
    if (Platform.isWindows) {
      if (!isFFmpegInstalledWindows()) {
        throw Exception(
            "FFmpeg has not been installed correctly alongside the package.");
      }
      if (!isVidenaInstalledWindows()) {
        throw Exception("libvidena has not been installed correctly");
      }
    } else if (Platform.isLinux) {
      if (!isFFmpegInstalledLinux()) {
        throw Exception(
            "FFmpeg has not been installed correctly alongside the package.");
      }
      if (!isVidenaInstalledLinux()) {
        throw Exception("libvidena has not been installed correctly");
      }
    }
    initializeAPI();
    isNavigatorInitialized = 1;
    return;
  }
}

FrameNative? _sendFrame(Pointer<Void> videoState, MediaMetadata m,
    SendPort playerPort, double speed) {
  FrameNative nativeFrame = retrieveFrame(videoState);
  if (nativeFrame.exists == -1) {
    return null;
  }
  playerPort.send(VideoFrame(
      content: nativeFrame.data.asTypedList(nativeFrame.size),
      width: nativeFrame.width,
      height: nativeFrame.height,
      format: ImageFormat.values[nativeFrame.format],
      size: nativeFrame.size,
      pts: nativeFrame.pts,
      dts: nativeFrame.dts,
      delay: (nativeFrame.delay / speed).floor()));

  return nativeFrame;
}

void _sendImageMetadata(
    FrameNative nativeFrame, SendPort metadataPort, double speed) {
  metadataPort.send(VideoFrameMetadata(
      pts: nativeFrame.pts,
      dts: nativeFrame.dts,
      delay: Duration(microseconds: (nativeFrame.delay / speed).floor()),
      size: nativeFrame.size,
      imageFormat: ImageFormat.values[nativeFrame.format],
      width: nativeFrame.width,
      height: nativeFrame.height));
}

FrameNative? _seekPrec(Pointer<Void> videoState, int newPts, int flag,
    _Connections connections, MediaMetadata m) {
  FrameNative? nativeFrame;
  if (newPts < 0) {
    return null;
  }
  int ret = seekPrecise(videoState, newPts, flag);
  if (ret >= 0) {
    nativeFrame =
        _sendFrame(videoState, m, connections.imagePort!, double.infinity);
    if (nativeFrame != null) {
      _sendImageMetadata(
          nativeFrame, connections.imageMetadataPort!, double.infinity);
      connections.progressPort!.send(
          Progress(Duration(milliseconds: nativeFrame.progress), m.duration));
      return nativeFrame;
    }
  } else if (ret == -2) {
    throw EndOfFileException();
  }
  return null;
}

void _decode(List survivalPack) async {
  initializeDecoder();

  bool quit = false;
  bool paused = false;
  double speed = survivalPack[3];
  Queue eventQ = Queue();
  Completer completer = Completer();
  dynamic event;
  int pts = -1;
  _Connections connections = survivalPack[2];
  FrameNative? nativeFrame;
  Pointer<Void> videoState = Pointer<Void>.fromAddress(survivalPack[0]);
  MediaMetadata m = survivalPack[1];
  ReceivePort controlPort = ReceivePort()
    ..listen((message) {
      switch (message[0]) {
        case 'play':
          paused = false;
          eventQ.clear();
          completer.complete();
          break;
        case 'pause':
          paused = true;
          eventQ.clear();
          break;
        case 'halt':
          paused = true;
          break;
        case 'toggle':
          paused = !paused;
          eventQ.clear();
          if (!paused) {
            completer.complete();
          }
          break;
        case 'pulse':
          if (nativeFrame != null) {
            _sendFrame(videoState, m, connections.imagePort!, double.infinity);
          }
          break;
        case 'seekTime':
          int backwards = 0;
          if (nativeFrame != null && nativeFrame!.progress > message[1]) {
            backwards = 1;
          }
          seekTime(videoState, message[1], backwards);
          break;
        case 'seekPrecise':
          if (message[1] < m.duration) {
            try {
              nativeFrame = _seekPrec(
                  videoState,
                  calculateTimeStamp(videoState, message[1]),
                  1,
                  connections,
                  m);
              if (nativeFrame == null) {
                quit = true;
                connections.setupPort.send(['quit']);
                break;
              }
            } catch (e) {
              // Everything is fine, but eof has been reached
            }
          }
          break;
        case 'seekForward':
          if (pts < 0) {
            break;
          }
          eventQ.addLast([message[1], 0]);
          if (eventQ.length <= 1) {
            completer.complete();
          }
          break;
        case 'seekBack':
          if (pts < 0) {
            break;
          }
          eventQ.addLast([-message[1], 1]);
          if (eventQ.length <= 1) {
            completer.complete();
          }
          break;
        case 'speed':
          speed = message[1];
          break;
        case 'resize':
          resize(videoState, message[1].numerator, message[1].denominator);
          break;
        case 'quit':
          paused = true;
          quit = true;
          completer.complete();
          connections.setupPort.send(['quit']);
          break;
        default:
          break;
      }
    });
  connections.setupPort.send([controlPort.sendPort]);
  while (!quit) {
    if (!paused) {
      if (quit) {
        break;
      }

      pts = makeFrame(videoState);

      if (pts >= 0) {
        nativeFrame = _sendFrame(videoState, m, connections.imagePort!, speed);
        if (nativeFrame == null) {
          quit = true;
          paused = true;
          break;
        }
        connections.progressPort!.send(Progress(
            Duration(milliseconds: nativeFrame!.progress), m.duration));
        if ((nativeFrame!.dtsProgress + nativeFrame!.delay / 1000) >=
            m.duration.inMilliseconds) {
          paused = true; // EOF
        }
        await Future.delayed(const Duration(microseconds: 1));
      } else {
        quit = true;
        paused = true;
        connections.setupPort.send(['quit']);
        break;
      }
    } else {
      while (eventQ.isNotEmpty && !completer.isCompleted) {
        event = eventQ.first;
        if (nativeFrame == null ||
            nativeFrame!.dtsProgress + nativeFrame!.delay * event[0] / 1000 <
                m.duration.inMilliseconds) {
          try {
            int newPts = calculateTimeStampFromJump(videoState, pts, event[0]);
            nativeFrame =
                _seekPrec(videoState, newPts, event[1], connections, m);
            if (nativeFrame == null) {
              quit = true;
              connections.setupPort.send(['quit']);
              completer.complete();
              break;
            }
          } catch (e) {
            // Everything is fine, but eof has been reached
          }
        }
        eventQ.removeFirst();
        await Future.delayed(const Duration(microseconds: 1));
      }
      await completer.future;
      completer = Completer();
    }
  }
  disposeVideo(videoState);
  controlPort.close();
  Isolate.exit();
}

Fraction verifyAspectRatio(Fraction? dimensions, Fraction source) {
  if (dimensions == null) {
    return source;
  }
  if (dimensions.reduce() != source) {
    if (dimensions.numerator / source.numerator <=
        dimensions.denominator / source.denominator) {
      dimensions = Fraction(dimensions.numerator,
          (dimensions.numerator / source.toDouble()).ceil());
    } else {
      dimensions = Fraction((dimensions.denominator * source.toDouble()).ceil(),
          dimensions.denominator);
    }
  }
  if (dimensions >= source) {
    return source;
  }
  return dimensions;
}

Fraction findSuitableDimensions(Fraction dimensions, Fraction aspectRatio) {
  if (dimensions.numerator % aspectRatio.numerator != 0) {
    dimensions = Fraction(
        (dimensions.numerator ~/ aspectRatio.numerator + 1) *
            aspectRatio.numerator,
        (dimensions.denominator ~/ aspectRatio.denominator + 1) *
            aspectRatio.denominator);
  }
  return dimensions;
}

Function _getFormatStrategy(ProcessStrategy imgFormat) {
  switch (imgFormat) {
    case ProcessStrategy.raw:
      return () {};
    case ProcessStrategy.image:
      return processImageFromRgba;
    case ProcessStrategy.custom:
      return () {};
  }
}

/// {@template processStrategy}
/// ProcessStrategy
///
/// Used for specifying post-process behaviour:
///
/// [ProcessStrategy.raw] does nothing.
///
/// [ProcessStrategy.image] is the default behaviour of [VidenaPlayer]
/// and it creates Images objects from the obtained frames.
///
/// [ProcessStrategy.custom] allows specifying a custom function to
/// execute on each frame.
/// {@endtemplate}
enum ProcessStrategy { raw, image, custom }

class Progress {
  Duration progress;
  Duration duration;

  Progress(this.progress, this.duration);
}

void _process(
    Function formatProcess,
    Stream stream,
    Pointer<Void> nativeVideoState,
    Completer termination,
    StreamController syncController) async {
  StreamQueue frameEvents = StreamQueue(stream);
  Duration clockAsOfNextFrame = Duration.zero;
  Duration clockAsOfLastFrame = Duration.zero;
  dynamic frame;
  dynamic ret;

  Stopwatch stopwatch = Stopwatch()..start();
  while (await frameEvents.hasNext && !termination.isCompleted) {
    frame = await frameEvents.next;
    clockAsOfNextFrame =
        clockAsOfLastFrame + Duration(microseconds: frame.delay);
    if (!termination.isCompleted) {
      ret = await formatProcess(frame);
      freeFrame(nativeVideoState);
    }
    if (clockAsOfNextFrame < stopwatch.elapsed) {
      clockAsOfNextFrame = stopwatch.elapsed;
    }
    if ((clockAsOfNextFrame.inMicroseconds - stopwatch.elapsedMicroseconds) >
        0) {
      await Future.delayed(
          Duration(
              milliseconds: (clockAsOfNextFrame.inMicroseconds -
                      stopwatch.elapsedMicroseconds) ~/
                  1000), () {
        clockAsOfLastFrame = clockAsOfNextFrame;
        syncController.add(ret);
      });
    } else {
      clockAsOfLastFrame = clockAsOfNextFrame;
      syncController.add(ret);
    }
  }
}

class _Connections {
  SendPort setupPort;
  SendPort? imagePort;
  SendPort? imageMetadataPort;
  SendPort? progressPort;

  _Connections(this.setupPort);

  _Connections.fromAll(this.setupPort, this.imagePort, this.imageMetadataPort,
      this.progressPort);
}

/// An object used for decoding video.
/// It provides access to streams of the information being decoded, as well as time controls.
///
/// [imageStream], [imageMetadataStream] and [progressStream] are all broadcast streams.
///
/// When a video is closed, so are all the streams made available by this object.
class VidenaPlayer {
  ReceivePort? _setupPort;
  Stream? _setupStream;
  ReceivePort? _imageStream;
  ReceivePort? _imageMetadataStream;
  StreamController<VideoFrame>? _imageStreamController;
  ReceivePort? _progressStream;
  SendPort? _controllerPort;
  Pointer<Void>? _videoState;
  Function(Frame)? imageCallback;
  Function(Progress)? progressCallback;
  Function(VideoFrameMetadata)? imageMetadataCallback;
  MediaMetadata? metadata;
  Stream<VideoFrame>? imageStream;
  Stream<VideoFrameMetadata>? imageMetadataStream;
  Stream<Progress>? progressStream;
  StreamSubscription? imageSub;
  StreamSubscription? imageMetaSub;
  StreamSubscription? progressSub;
  Completer? disposal;

  VidenaPlayer(
      {this.imageCallback, this.progressCallback, this.imageMetadataCallback});

  /// {@macro processStrategy}
  Future<void> open(
      {required String file,
      ImageFormat imageFormat = ImageFormat.rgba,
      ProcessStrategy processStrategy = ProcessStrategy.image,
      Future<Frame> Function(Frame)? postProcess,
      double speed = 1}) async {
    if (speed <= 0) {
      throw Exception("Illegal speed value");
    }
    await close();
    if (disposal != null) {
      await disposal!.future;
      disposal = null;
    }
    _initializeStreams();
    metadata = await getMediaMetadata(file);
    _videoState = openVideo(file.toNativeUtf8(), imageFormat.index, 0, 0);
    if (_videoState == nullptr) {
      throw VideoFormatException();
    }
    if (imageCallback != null) {
      imageStream!.listen(imageCallback);
    }
    if (imageMetadataCallback != null) {
      imageMetadataStream!.listen(imageMetadataCallback);
    }
    if (progressCallback != null) {
      progressStream!.listen(progressCallback);
    }
    Isolate.spawn(
        _decode,
        [
          _videoState!.address,
          metadata,
          _Connections.fromAll(_setupPort!.sendPort, _imageStream!.sendPort,
              _imageMetadataStream!.sendPort, _progressStream!.sendPort),
          speed
        ],
        errorsAreFatal: false);
    Completer terminator = Completer();
    await _register(terminator);
    _process(_getFormatStrategy(processStrategy), _imageStream!, _videoState!,
        terminator, _imageStreamController!);
  }

  void _initializeStreams() {
    _setupPort = ReceivePort();
    _setupStream = _setupPort!.asBroadcastStream();
    _imageStream = ReceivePort();
    _imageStreamController = StreamController();
    _imageMetadataStream = ReceivePort();
    _progressStream = ReceivePort();
    imageStream = _imageStreamController!.stream.asBroadcastStream();
    imageMetadataStream = _imageMetadataStream!.asBroadcastStream().cast();
    progressStream = _progressStream!.asBroadcastStream().cast();
  }

  Future<void> _register(Completer terminator) async {
    _setupStream!.listen((message) async {
      if (message[0] == 'quit') {
        terminator.complete();

        _setupPort?.close();
        await _setupStream?.drain();
        _setupStream = null;
        _imageStream?.close();
        _imageMetadataStream?.close();
        _imageStreamController?.close();
        await imageStream?.drain();
        _imageMetadataStream?.close();
        imageStream = null;
        await imageMetadataStream?.drain();
        imageMetadataStream = null;
        _progressStream?.close();
        await progressStream?.drain();
        progressStream = null;

        imageSub?.cancel();
        imageMetaSub?.cancel();
        progressSub?.cancel();

        _videoState = nullptr;
        metadata = null;
        disposal?.complete();
      }
    });
    dynamic message = await _setupStream!.first;
    if (message[0] != 'error') {
      _controllerPort = message[0];
    }
  }

  void play() {
    if (_controllerPort != null) {
      _controllerPort!.send(['play']);
    }
  }

  void pause() {
    if (_controllerPort != null) {
      _controllerPort!.send(['pause']);
    }
  }

  void togglePause() {
    if (_controllerPort != null) {
      _controllerPort!.send(['toggle']);
    }
  }

  void nFramesForward(int n) {
    if (_controllerPort != null) {
      _controllerPort!.send(['halt']);
      _controllerPort!.send(['seekForward', n]);
    }
  }

  void nFramesBackward(int n) {
    if (_controllerPort != null) {
      _controllerPort!.send(['halt']);
      _controllerPort!.send(['seekBack', n]);
    }
  }

  void setPlaybackSpeed(double speed) {
    if (_controllerPort != null) {
      if (speed > 0) {
        _controllerPort!.send(['speed', speed]);
      } else {
        throw Exception("Illegal speed value");
      }
    }
  }

  /// This function pauses the video and resends the last frame through the stream
  void pulse() {
    pause();
    if (_controllerPort != null) {
      _controllerPort!.send(['pulse']);
    }
  }

  void seekTime(Duration duration) {
    if (_controllerPort != null) {
      _controllerPort!.send(['seekTime', duration.inMilliseconds]);
    }
  }

  /// {@template seekPrecise}
  /// This will seek to the exact frame indicated by [duration], or the frame before, instead of seeking to a keyframe like [seekTime] does.
  /// {@endtemplate}
  void seekPrecise(Duration duration) {
    if (_controllerPort != null) {
      _controllerPort!.send(['seekPrecise', duration.inMilliseconds]);
    }
  }

  /// Stores the [callback] provided and [progressStream] is listened to with this callback on every call to [open].
  /// Directly listening to the stream will only last until the video is closed.
  void registerProgress(Function(Progress)? callback) {
    progressCallback = callback;
  }

  /// Stores the [callback] provided and [imageStream] is listened to with this callback on every call to [open].
  /// Directly listening to the stream will only last until the video is closed.
  void registerVideo(Function(Frame)? callback) {
    imageCallback = callback;
  }

  /// Stores the [callback] provided and [imageMetadataStream] is listened to with this callback on every call to [open].
  /// Directly listening to the stream will only last until the video is closed.
  void registerImageMetadata(Function(VideoFrameMetadata)? callback) {
    imageMetadataCallback = callback;
  }

  /// Stops the processing of the video, if any was taking place, and closes all the streams.
  Future<void> close() async {
    if (_controllerPort != null && disposal == null) {
      disposal = Completer();
      _controllerPort!.send(['pause']);
      await Future.delayed(const Duration(milliseconds: 170));
      _controllerPort!.send(['quit']);
    }
    _controllerPort = null;
  }
}

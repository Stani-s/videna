// This file is a part of videna.
// Copyright () 2023 Stanisław Talejko <stalejko@gmail.com>
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

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

typedef InitializeDartApiNative = Int Function(Pointer<Void>);
typedef InitializeDartApi = int Function(Pointer<Void>);

typedef PostCObject
    = Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>;

typedef RegisterSendPortNative = Int Function(Int64, PostCObject);
typedef RegisterSendPort = int Function(int, PostCObject);

typedef GetMetadata = Metadata Function(Pointer<Utf8>);

typedef RetrieveFrameNative = FrameNative Function(Pointer<Void>);
typedef RetrieveFrame = FrameNative Function(Pointer<Void>);

typedef MakeFrameNative = Int Function(Pointer<Void>);
typedef MakeFrame = int Function(Pointer<Void>);

typedef FreeNativeFrameNative = Void Function(Pointer<Void>);
typedef FreeNativeFrame = void Function(Pointer<Void>);

typedef Toggle2xNative = Void Function(Pointer<Void>);
typedef Toggle2x = void Function(Pointer<Void>);

typedef RewindFramesNative = Void Function(Pointer<Void>, Uint8);
typedef RewindFrames = void Function(Pointer<Void>, int);

typedef ForwardFramesNative = Void Function(Pointer<Void>, Uint8);
typedef ForwardFrames = void Function(Pointer<Void>, int);

typedef PlayNative = Void Function(Pointer<Void>);
typedef Play = void Function(Pointer<Void>);

typedef PauseNative = Void Function(Pointer<Void>);
typedef Pause = void Function(Pointer<Void>);

typedef TogglePauseNative = Void Function(Pointer<Void>);
typedef TogglePause = void Function(Pointer<Void>);

typedef ResizeNative = Void Function(Pointer<Void>, Int, Int);
typedef Resize = void Function(Pointer<Void>, int, int);

typedef GetDefaultName = Pointer<Utf8> Function(Pointer<Void>);

typedef OpenVideoNative = Pointer<Void> Function(Pointer<Utf8>, Int, Int, Int);
typedef OpenVideo = Pointer<Void> Function(Pointer<Utf8>, int, int, int);

typedef DisposeVideoNative = Void Function(Pointer<Void>);
typedef DisposeVideo = void Function(Pointer<Void>);

typedef QuitNative = Void Function(Pointer<Void>);
typedef Quit = void Function(Pointer<Void>);

typedef CalculateTimeStampFromJumpNative = Int64 Function(
    Pointer<Void>, Int64, Int);
typedef CalculateTimeStampFromJump = int Function(Pointer<Void>, int, int);

typedef CalculateTimeStampNative = Int64 Function(Pointer<Void>, Int64);
typedef CalculateTimeStamp = int Function(Pointer<Void>, int);

typedef SeekTimeNative = Int Function(Pointer<Void>, Int64, Int);
typedef SeekTime = int Function(Pointer<Void>, int, int);

typedef SeekPreciseNative = Int Function(Pointer<Void>, Int64, Int);
typedef SeekPrecise = int Function(Pointer<Void>, int, int);

typedef GetSourcePictureNative = Void Function(
    Pointer<Void>); // Struct is PlayerFrame; // Or send this through pipe?
typedef GetSourcePicture = void Function(Pointer<Void>);

typedef FindEOFNative = Int64 Function(Pointer<Utf8>);
typedef FindEOF = int Function(Pointer<Utf8>);

class FrameNative extends Struct {
  @Int()
  external int size;

  @Int()
  external int width;

  @Int()
  external int height;

  @Int()
  external int format;

  external Pointer<Uint8> data;

  @Int64()
  external int pts;

  @Int()
  external int delay;

  @Int64()
  external int dts;

  @Int64()
  external int dtsProgress;

  @Int64()
  external int progress;

  @Int()
  external int exists;
}

class Metadata extends Struct {
  @Int64()
  external int startTime;

  @Int64()
  external int duration;

  @Int64()
  external int timescale;

  @Int()
  external int width;

  @Int()
  external int height;

  @Int()
  external int numStreams;
}

late DynamicLibrary dynLib;

late OpenVideo openVideo;

late SeekTime seekTime;

late GetMetadata getMetadata;

late MakeFrame makeFrame;

late DisposeVideo disposeVideo;

late CalculateTimeStampFromJump calculateTimeStampFromJump;

late CalculateTimeStamp calculateTimeStamp;

late SeekPrecise seekPrecise;

late RetrieveFrame retrieveFrame;

late FreeNativeFrame freeFrame;

late FindEOF findEOF;

late Resize resize;

/// Initializes the variables that hold the functions used by the decode isolate.
void initializeDecoder() {
  if (Platform.isWindows) {
    dynLib = DynamicLibrary.open(
        path.join(path.dirname(Platform.resolvedExecutable), 'libvidena.dll'));
  } else if (Platform.isLinux) {
    dynLib = DynamicLibrary.open('libvidena.so');
  }
  seekTime = dynLib.lookupFunction<SeekTimeNative, SeekTime>('seek_time');
  makeFrame = dynLib.lookupFunction<MakeFrameNative, MakeFrame>('make_frame');
  calculateTimeStamp =
      dynLib.lookupFunction<CalculateTimeStampNative, CalculateTimeStamp>(
          'calculateTimeStamp');
  calculateTimeStampFromJump = dynLib.lookupFunction<
      CalculateTimeStampFromJumpNative,
      CalculateTimeStampFromJump>('calculateTimeStampFromJump');
  seekPrecise =
      dynLib.lookupFunction<SeekPreciseNative, SeekPrecise>('seek_precise');
  retrieveFrame = dynLib
      .lookupFunction<RetrieveFrameNative, RetrieveFrame>('retrieveFrame');
  disposeVideo =
      dynLib.lookupFunction<DisposeVideoNative, DisposeVideo>('disposeVideo');
  findEOF = dynLib.lookupFunction<FindEOFNative, FindEOF>('findEOF');
  resize = dynLib.lookupFunction<ResizeNative, Resize>('resize');
}

/// Initializes the variables that hold the functions used by the main thread.
void initializeAPI() {
  if (Platform.isWindows) {
    dynLib = DynamicLibrary.open(
        path.join(path.dirname(Platform.resolvedExecutable), 'libvidena.dll'));
  } else if (Platform.isLinux) {
    dynLib = DynamicLibrary.open('libvidena.so');
  }
  openVideo = dynLib.lookupFunction<OpenVideoNative, OpenVideo>('openVideo');
  freeFrame = dynLib.lookupFunction<FreeNativeFrameNative, FreeNativeFrame>(
      'freeNativeFrame');
  disposeVideo =
      dynLib.lookupFunction<DisposeVideoNative, DisposeVideo>('disposeVideo');
  getMetadata = dynLib.lookupFunction<GetMetadata, GetMetadata>('getMetadata');
}

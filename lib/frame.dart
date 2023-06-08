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

import 'dart:async';
import 'dart:core';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// {@template imageFormat}
/// Used for specifying the desired pixel format of frames from the native decoder.
/// The [none] option will return the frames in the format they came from the decoder
/// and can be faster.
/// After frames have been transformed in dart and are no longer in the initial format they also use [none].
/// {@endtemplate}
enum ImageFormat { rgba, bgra, arbg, abgr, yuv420P, gray8A, gray16LE, none }

/// Object with the information that accompanied a [Frame].
///
/// [pts] and [dts] are in stream timebase.
/// [size] is in bytes.
class FrameMetadata {
  int? pts;
  int? dts;
  Duration? delay;
  int? size;

  FrameMetadata({this.pts, this.dts, this.delay, this.size});
}

/// Object with the information that accompanied a [VideoFrame].
class VideoFrameMetadata extends FrameMetadata {
  ImageFormat? imageFormat;
  int? width;
  int? height;

  VideoFrameMetadata(
      {super.pts,
      super.dts,
      super.delay,
      super.size,
      this.imageFormat,
      this.width,
      this.height});
}

abstract class Frame {
  int delay;
  int pts;
  int dts;
  int size;
  //fmt
  dynamic content;

  Frame(
      {required this.delay,
      required this.pts,
      required this.dts,
      required this.size,
      required this.content});
}

class VideoFrame extends Frame {
  int width;
  int height;
  ImageFormat format;
  VideoFrame(
      {required this.width,
      required this.height,
      required this.format,
      required super.delay,
      required super.pts,
      required super.dts,
      required super.size,
      required super.content});
}

Future<VideoFrame> processImageFromRgba(VideoFrame frame) async {
  Completer<ui.Image> callback = Completer<ui.Image>();
  ui.PixelFormat? pixelFormat;
  if (frame.format == ImageFormat.rgba) {
    pixelFormat = ui.PixelFormat.rgba8888;
  } else if (frame.format == ImageFormat.bgra) {
    pixelFormat = ui.PixelFormat.bgra8888;
  } else {
    return frame;
  }
  ui.decodeImageFromPixels(
      frame.content, frame.width, frame.height, pixelFormat, (ui.Image im) {
    callback.complete(im);
  });
  frame.content = RawImage(image: await callback.future);
  frame.format = ImageFormat.none;
  return frame;
}

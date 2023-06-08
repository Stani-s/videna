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

import 'dart:isolate';
import 'dart:core';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart';
import 'package:fraction/fraction.dart';
import 'ffi.dart';
import 'exceptions.dart';

/// Object for video information.
class MediaMetadata {
  String? filename;
  String? fileExtension;
  String? path;
  Duration duration;
  Fraction? dimensions;
  Fraction? aspectRatio;
  int numberOfStreams;

  MediaMetadata(
      {this.path,
      this.duration = Duration.zero,
      this.dimensions,
      this.numberOfStreams = 0}) {
    if (dimensions != null) {
      if (path != null) {
        filename = basenameWithoutExtension(path!);
        fileExtension = extension(path!);
      }
      aspectRatio = dimensions!.reduce();
    }
  }
}

MediaMetadata getMediaMetadataSync(String path) {
  Metadata m = getMetadata(path.toNativeUtf8());
  MediaMetadata metadata = MediaMetadata(
      path: path,
      duration: Duration(milliseconds: m.duration),
      dimensions: Fraction(m.width, m.height),
      numberOfStreams: m.numStreams);
  if (metadata.dimensions == Fraction(0)) {
    throw VideoFormatException();
  }
  return metadata;
}

Future<MediaMetadata> getMediaMetadata(String path) {
  return Isolate.run(() {
    initializeAPI();
    return getMediaMetadataSync(path);
  });
}

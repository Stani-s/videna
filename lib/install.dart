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

import 'dart:io';
import 'package:path/path.dart' as path;

bool isFFmpegInstalledWindows() {
  if (!File(path.join(
          path.dirname(Platform.resolvedExecutable), 'avcodec-59.dll'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(
          path.dirname(Platform.resolvedExecutable), 'avformat-59.dll'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(
          path.dirname(Platform.resolvedExecutable), 'avdevice-59.dll'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(
          path.dirname(Platform.resolvedExecutable), 'avfilter-8.dll'))
      .existsSync()) {
    return false;
  }
  if (!File(
          path.join(path.dirname(Platform.resolvedExecutable), 'avutil-57.dll'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(
          path.dirname(Platform.resolvedExecutable), 'swresample-4.dll'))
      .existsSync()) {
    return false;
  }
  if (!File(
          path.join(path.dirname(Platform.resolvedExecutable), 'swscale-6.dll'))
      .existsSync()) {
    return false;
  }
  return true;
}

bool isFFmpegInstalledLinux() {
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libavcodec.so.59.37.100'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libavformat.so.59.27.100'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libavdevice.so.59.7.100'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libavfilter.so.8.44.100'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libavutil.so.57.28.100'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libswresample.so.4.7.100'))
      .existsSync()) {
    return false;
  }
  if (!File(path.join(path.dirname(Platform.resolvedExecutable),
          'lib/libswscale.so.6.7.100'))
      .existsSync()) {
    return false;
  }
  return true;
}

bool isVidenaInstalledWindows() {
  if (!File(
          path.join(path.dirname(Platform.resolvedExecutable), 'libvidena.dll'))
      .existsSync()) {
    return false;
  }
  return true;
}

bool isVidenaInstalledLinux() {
  if (!File(path.join(
          path.dirname(Platform.resolvedExecutable), 'lib/libvidena.so'))
      .existsSync()) {
    return false;
  }
  return true;
}

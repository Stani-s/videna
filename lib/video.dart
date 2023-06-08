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

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'videna.dart';
export 'videna.dart';

class Snapshot {
  Uint8List image;
  String name;
  String format = 'png';
  Snapshot({required this.image, required this.name});
}

/// A widget that displays the progress in the player it is associated with.
/// Seeks are made with player.seekTime(duration).
class ProgressBarProvider extends StatefulWidget {
  final VidenaPlayer player;
  const ProgressBarProvider({super.key, required this.player});

  @override
  ProgressBarProviderState createState() => ProgressBarProviderState();
}

class ProgressBarProviderState extends State<ProgressBarProvider> {
  Duration progress = Duration.zero;
  Duration duration = Duration.zero;
  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    widget.player.registerProgress((event) {
      progress = event.progress;
      duration = event.duration;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProgressBar(
      progress: progress,
      total: duration,
      onSeek: (time) => {widget.player.seekTime(time)},
    );
  }
}

/// A widget that displays video through a [VidenaPlayer]
/// A progress bar for this [Video] is obtainable by calling [getProgressBar]
class Video extends StatefulWidget {
  final VidenaPlayer player = VidenaPlayer();

  Video({super.key});

  Future<void> open(String file) async {
    await player.open(file: file);
  }

  void pause() {
    player.pause();
  }

  void play() {
    player.play();
  }

  void togglePause() {
    player.togglePause();
  }

  void nFramesBackward(int n) {
    player.nFramesBackward(n);
  }

  void nFramesForward(int n) {
    player.nFramesForward(n);
  }

  void setPlaybackSpeed(double speed) {
    player.setPlaybackSpeed(speed);
  }

  void seekTime(Duration duration) {
    player.seekTime(duration);
  }

  /// {@macro seekPrecise}
  void seekPrecise(Duration duration) {
    player.seekPrecise(duration);
  }

  /// Pauses the video and returns a [Snapshot].
  Future<Snapshot?> getSnapshot() async {
    player.pause();
    VideoFrame? frame;
    final future = Completer();
    final sub = player.imageStream!.listen(null);
    sub.onData((event) {
      future.complete(event);
      sub.cancel();
    });
    player.pulse();

    frame = await future.future;
    Snapshot snapshot;
    if (frame != null && frame.size > 0) {
      snapshot = Snapshot(
        image: (await frame.content!.image
                .toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List(),
        name: '${player.metadata?.filename}-${frame.pts}',
      );
      return snapshot;
    }

    return null;
  }

  /// Pauses the video and saves a snapshot in the provided path.
  /// The snapshot will be saved as a png.
  Future<void> saveSnapshotTo(String path) async {
    Snapshot? snapshot = await getSnapshot();
    if (snapshot != null) {
      File(path).writeAsBytes(snapshot.image, flush: true);
    }
  }

  /// Pauses the video and saves a snapshot in the desired location.
  Future<void> takeSnapshot() async {
    Snapshot? snapshot = await getSnapshot();
    if (snapshot != null) {
      String? userPath = await FilePicker.platform
          .saveFile(fileName: "${snapshot.name}.${snapshot.format}");
      if (userPath != null) {
        File(userPath).writeAsBytes(snapshot.image, flush: true);
      }
    }
  }

  /// Creates a [ProgressBarProvider] that will update with the time of this [Video]
  ProgressBarProvider getProgressBar() {
    return ProgressBarProvider(player: player);
  }

  Future<void> dispose() async {
    player.close();
  }

  @override
  VideoState createState() => VideoState();
}

class VideoState extends State<Video> {
  RawImage? frame;
  void displayVideo() {
    widget.player.registerVideo((event) {
      if (event.content is RawImage) {
        frame = event.content;
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    displayVideo();
  }

  @override
  Widget build(BuildContext context) {
    if (frame == null) {
      return Container(
          width: 800,
          height: 450,
          //height: height ?? double.infinity,
          color: Colors.black);
    }
    return frame!;
  }
}

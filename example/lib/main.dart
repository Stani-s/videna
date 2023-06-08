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

import 'package:flutter/services.dart';
import 'package:videna/video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  Videna.initialize();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle("Videna Example");
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setBackgroundColor(Colors.white);
    await windowManager.show();
    await windowManager.setSkipTaskbar(false);
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Videna Example',
      theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color.fromARGB(255, 178, 150, 255)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WindowListener {
  int index = 0;

  Uint8List? snapshotArray;

  String? snapshotName;

  Video video = Video();

  late ProgressBarProvider progressBar;

  final viewKey = GlobalKey();

  @override
  void initState() {
    progressBar = video.getProgressBar();
    windowManager.addListener(this);
    _init();
    super.initState();
  }

  void _init() async {
    await windowManager.setPreventClose(true);
    setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): SeekBckIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): ToggleIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): SeekFwdIntent()
        },
        child: Actions(
            actions: {
              SeekBckIntent: SeekBckAction(video, 1),
              ToggleIntent: ToggleAction(video),
              SeekFwdIntent: SeekFwdAction(video, 1)
            },
            child: Scaffold(
                appBar: Tab(
                    child: Table(children: [
                  TableRow(children: [
                    OutlinedButton(
                        onPressed: () async {
                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles();
                          if (result != null) {
                            await video.open(result.files.single.path!);
                            progressBar = video.getProgressBar();
                            setState(() {});
                          } else {}
                        },
                        child: const Text('Open File')),
                    OutlinedButton(
                      onPressed: () {
                        video.takeSnapshot();
                      },
                      child: const Text('Snapshot'),
                    )
                  ])
                ])),
                body: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          fit: FlexFit.loose,
                          child: FractionallySizedBox(
                              heightFactor: 0.635, child: video)),
                      Table(children: [
                        TableRow(children: [Row(), progressBar, Row()]),
                        TableRow(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton(
                                  onPressed: () => {video.nFramesBackward(10)},
                                  child: const Text('-10')),
                              OutlinedButton(
                                  onPressed: () => {video.nFramesBackward(3)},
                                  child: const Text('-3')),
                              OutlinedButton(
                                  onPressed: () => {video.nFramesBackward(1)},
                                  child: const Text('-1'))
                            ],
                          ),
                          OutlinedButton(
                              onPressed: () => {video.togglePause()},
                              child: const Icon(Icons.play_arrow)),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton(
                                    onPressed: () => {video.nFramesForward(1)},
                                    child: const Text('1+')),
                                OutlinedButton(
                                    onPressed: () => {video.nFramesForward(3)},
                                    child: const Text('3+')),
                                OutlinedButton(
                                    onPressed: () => {video.nFramesForward(10)},
                                    child: const Text('10+')),
                              ])
                        ]),
                      ])
                    ]))));
  }

  @override
  void onWindowClose() async {
    await video.dispose();
    await windowManager.destroy();
  }
}

class ToggleIntent extends Intent {}

class ToggleAction extends Action<ToggleIntent> {
  final Video video;
  ToggleAction(this.video);
  @override
  Object? invoke(covariant ToggleIntent intent) {
    video.togglePause();
    return null;
  }
}

class SeekFwdIntent extends Intent {}

class SeekFwdAction extends Action<SeekFwdIntent> {
  final Video video;
  final int n;
  SeekFwdAction(this.video, this.n);
  @override
  Object? invoke(covariant SeekFwdIntent intent) {
    video.nFramesForward(n);
    return null;
  }
}

class SeekBckIntent extends Intent {}

class SeekBckAction extends Action<SeekBckIntent> {
  final Video video;
  final int n;
  SeekBckAction(this.video, this.n);
  @override
  Object? invoke(covariant SeekBckIntent intent) {
    video.nFramesBackward(n);
    return null;
  }
}

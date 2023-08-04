import 'package:flutter/services.dart';
import 'package:videna/video.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Videna.initialize();
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

class HomePageState extends State<HomePage> {
  int index = 0;

  Uint8List? snapshotArray;

  String? snapshotName;

  Video video = Video();

  late ProgressBarProvider progressBar;

  final viewKey = GlobalKey();

  @override
  void initState() {
    progressBar = video.getProgressBar();
    _init();
    super.initState();
  }

  void _init() async {
    setState(() {});
  }

  @override
  void dispose() {
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
                        TableRow(
                            children: [const Row(), progressBar, const Row()]),
                        TableRow(children: [
                          backwardButtons(video),
                          OutlinedButton(
                              onPressed: () => {video.togglePause()},
                              child: const Icon(Icons.play_arrow)),
                          forwardButtons(video)
                        ]),
                      ])
                    ]))));
  }
}

Widget backwardButtons(Video video) {
  if (Platform.isAndroid) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      OutlinedButton(
          onPressed: () => {video.nFramesBackward(10)},
          child: const Text('-10')),
      OutlinedButton(
          onPressed: () => {video.nFramesBackward(3)}, child: const Text('-3')),
      OutlinedButton(
          onPressed: () => {video.nFramesBackward(1)}, child: const Text('-1'))
    ],
  );
}

Widget forwardButtons(Video video) {
  if (Platform.isAndroid) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      verticalDirection: VerticalDirection.up,
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
      ],
    );
  }
  return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
    OutlinedButton(
        onPressed: () => {video.nFramesForward(1)}, child: const Text('1+')),
    OutlinedButton(
        onPressed: () => {video.nFramesForward(3)}, child: const Text('3+')),
    OutlinedButton(
        onPressed: () => {video.nFramesForward(10)}, child: const Text('10+')),
  ]);
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

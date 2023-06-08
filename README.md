# Videna

![Package Version](https://img.shields.io/pub/v/videna)
![License](https://img.shields.io/github/license/Stani-s/videna)
![Platform](https://img.shields.io/badge/platform-flutter-ff69b4)
 
Videna is a video decoding and playback library for flutter on Windows and Linux.


## Features

- Decode video files into frames
- Display frames in a Flutter widget
- Seek to specific frames in the video
- Retrieve video metadata (duration, resolution, etc.)
- Support for wide range of video formats

## Installation

To use this package, add `videna` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  videna: ^0.0.1
```
Then, run the following command in your terminal to fetch the package:

```bash
$ flutter pub get
```

## Usage

Import the package into your Dart file:

```dart
import 'package:videna/videna.dart';
```

To play a local video file, you can use the Video widget:

```dart
final video = Video();

video.open('path_to_video_file.mp4');
```

Similarly, to decode a video, use the videnaPlayer class:
```dart
final videna = VidenaPlayer(imageCallback: (videoFrame) {},
                        imageMetadataCallback: (videoFrameMetadata) {},
                        progressCallback: (progress) {});

videna.open(file: 'path_to_video_file.mp4',
          speed: double.infinity,
          imgFormat: ImageFormat.yuv420P);
```

To get metadata from a video file:

```dart
MediaMetadata m;
m = getMediaMetadataSync('path_to_video_file.mp4');
// Or
m = await getMediaMetadata('path_to_video_file.mp4');
```

### Example

For a complete example, please refer to the example directory in this repository.

## Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue on the GitHub repository.

## License

This project is licensed under the LGPL 2.1 License.

## Acknowledgments

  Thank you to the contributors of the Flutter framework for providing a robust platform for building cross-platform applications and also to contributors of the FFmpeg project for building such reliable tools.

## Contact

For any inquiries or support, please contact stalejko@gmail.com.

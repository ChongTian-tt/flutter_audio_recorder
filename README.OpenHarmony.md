<h1 align="center">flutter_audio_recorder</h1>

This project is developed based on [flutter_audio_recorder](https://github.com/shadow-app/flutter_audio_recorder).

## Introduction

`flutter_audio_recorder` is a Flutter audio recording plugin that provides initialization, start, pause, resume, stop, status query, and audio metering capabilities for OpenHarmony Flutter applications.

## Installation

Go to your project directory and add the dependency in `pubspec.yaml`:

```yaml
dependencies:
  flutter_audio_recorder:
    git:
      url: https://gitcode.com/org/OpenHarmony-Flutter/flutter_audio_recorder
      ref: master
```

Run:

```bash
flutter pub get
```

> TAG naming rule: `upstreamVersion-ohos-version-betax`. See `OHOSCHANGELOG.md` for changes between tags.

| Flutter Framework Version | TAG Name | Notes |
| ------------------------- | -------- | ----- |
| 3.7.12-ohos-1.0.6 | 0.5.5-ohos-1.0.0 |  |

## Constraints

### Compatibility

Verified on the following versions:

1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25;

### Permission Requirements

Open `entry/src/main/module.json5` and add:

```json
"requestPermissions": [
  {
    "name": "ohos.permission.MICROPHONE",
    "reason": "$string:app_name",
    "usedScene": {
      "abilities": [
        "EntryAbility"
      ],
      "when": "always"
    }
  }
]
```

## Usage Example

The following snippet shows the minimal usage:

```dart
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';

Future<void> simpleRecordDemo() async {
  // 1. Check and request permission
  final bool hasPermission = await FlutterAudioRecorder.hasPermissions;
  if (!hasPermission) {
    return;
  }

  // 2. Initialize recorder
  final FlutterAudioRecorder recorder = FlutterAudioRecorder(
    'file_path.wav',
    audioFormat: AudioFormat.WAV,
  );
  await recorder.initialized;

  // 3. Start recording
  await recorder.start();

  // 4. Stop and print output path
  final Recording result = await recorder.stop();
  print('record file: ${result.path}');
}
```

## Usage Guide

### 1. Permission Check

```dart
final bool hasPermission = await FlutterAudioRecorder.hasPermissions;
```

### 2. Initialize Recorder

```dart
final FlutterAudioRecorder recorder = FlutterAudioRecorder(
  'file_path.m4a',
  audioFormat: AudioFormat.AAC,
  sampleRate: 16000,
);
await recorder.initialized;
```

### 3. Recording Lifecycle

```dart
await recorder.start();
await recorder.pause();
await recorder.resume();
final Recording result = await recorder.stop();
```

### 4. Query Current State

```dart
final Recording current = await recorder.current(channel: 0);
```

## API Reference

### API

> [!TIP] In the `ohos Support` column: `yes` means supported on OpenHarmony, `no` means unsupported, and `partially` means partially supported.

| Name | Description | Type | Input | Output | ohos Support |
| --- | --- | --- | --- | --- | --- |
| `initialized` | Get recorder initialization future | Property | None | `Future` | yes |
| `recording` | Get current recording object | Property | None | `Recording` | yes |
| `hasPermissions` | Check and request recording permission | Property | None | `Future<bool>` | yes |
| `init()` | Recorder initialization logic (constructor initialization flow) | Function | `String path, AudioFormat audioFormat, int sampleRate` | `Future` | yes |
| `start()` | Start recording | Function | None | `Future<void>` | yes |
| `pause()` | Pause recording | Function | None | `Future<void>` | yes |
| `resume()` | Resume recording | Function | None | `Future<void>` | yes |
| `stop()` | Stop recording and return result | Function | None | `Future<Recording>` | yes |
| `current()` | Get recording state and metering data | Function | `channel(int)` | `Future<Recording>` | yes |

## Known Issues

None.

## Others

None.

## Directory Structure

```text
|---- flutter_audio_recorder
|     |---- android                      # Android adaptation code
|     |---- example                      # Multi-platform demo app
|           |---- lib                    # Demo Dart code
|           |---- ohos                   # OpenHarmony demo project
|     |---- ios                          # iOS adaptation code
|     |---- lib                          # Dart entry and API definitions
|     |---- ohos                         # OpenHarmony plugin implementation
|     |---- test                         # Unit tests
|     |---- README.OpenHarmony_CN.md     # OpenHarmony Chinese README
|     |---- README.OpenHarmony.md        # OpenHarmony English README
|     |---- pubspec.yaml                 # Plugin configuration
```

## Contributing

If you find any issue, feel free to submit an [Issue](https://gitcode.com/org/OpenHarmony-Flutter/fluttertpc_flutter_audio_recorder/issues). Pull requests are also welcome via [PR](https://gitcode.com/org/OpenHarmony-Flutter/fluttertpc_flutter_audio_recorder/pulls).

## License

This project is licensed under [MIT License](LICENSE).

# flutter_audio_recorder

This project is developed based on [flutter_audio_recorder](https://github.com/shadow-app/flutter_audio_recorder) to provide audio recording, recording pause/resume, stop recording, and audio level metering capabilities for OpenHarmony Flutter scenarios.

## 1. Installation and Usage

### 1.1 Installation

Navigate to your project directory and add the dependency to `pubspec.yaml`:

#### pubspec.yaml

```yaml
dependencies:
  flutter_audio_recorder:
    git:
      url: https://gitcode.com/org/OpenHarmony-Flutter/flutter_audio_recorder
      ref: master
```

Execute the following command:

```bash
flutter pub get
```

### 1.2 Usage Example

For usage examples, see [example](example/lib/main.dart).

The simplest usage:

```dart
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';

// Check and request permissions
bool hasPermission = await FlutterAudioRecorder.hasPermissions;
if (!hasPermission) {
  return;
}

// Initialize the recorder
FlutterAudioRecorder _recorder = FlutterAudioRecorder("file_path", audioFormat: AudioFormat.WAV);
await _recorder.initialized;

// Start recording
await _recorder.start();

// Pause recording
await _recorder.pause();

// Resume recording
await _recorder.resume();

// Stop recording
var result = await _recorder.stop();
print("Recording saved to: ${result.path}");
```

## 2. Constraints

1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。

## 3. Version and Framework Mapping

|       | 3.7 |
|-------|:---:|
| 1.0.0 |  ✅  |

## 4. API

> [!TIP] "ohos Support" column: yes = supported; no = not supported; partially = partially supported.

| Name | Description | Type | Input | Output | ohos Support |
| --- | --- | --- | --- | --- | --- |
| hasPermissions | Check if recording permission is granted | Property | None | Future\<bool\> | yes |
| start() | Start recording | Function | None | Future\<void\> | yes |
| pause() | Pause recording | Function | None | Future\<void\> | yes |
| resume() | Resume recording | Function | None | Future\<void\> | yes |
| stop() | Stop recording | Function | None | Future\<Recording\> | yes |
| current() | Get current recording status and metering data | Function | channel(int) | Future\<Recording\> | yes |

## 5. Open Source License

This project is open sourced under [MIT License](LICENSE).

# flutter_audio_recorder

本项目基于 [flutter_audio_recorder](https://github.com/shadow-app/flutter_audio_recorder) 开发，为 OpenHarmony Flutter 场景提供音频录音、录音暂停恢复、停止录音以及音频电平计量功能。

## 1. 安装与使用

### 1.1 安装方式

进入工程目录并在 `pubspec.yaml` 中添加依赖：

#### pubspec.yaml

```yaml
dependencies:
  flutter_audio_recorder:
    git:
      url: https://gitcode.com/org/OpenHarmony-Flutter/flutter_audio_recorder
      ref: master
```

执行命令：

```bash
flutter pub get
```

### 1.2 使用案例

使用案例详见 [example](example/lib/main.dart)。

最简单的调用方式：

```dart
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';

// 检查并请求权限
bool hasPermission = await FlutterAudioRecorder.hasPermissions;
if (!hasPermission) {
  return;
}

// 初始化录音器
FlutterAudioRecorder _recorder = FlutterAudioRecorder("file_path", audioFormat: AudioFormat.WAV);
await _recorder.initialized;

// 开始录音
await _recorder.start();

// 暂停录音
await _recorder.pause();

// 恢复录音
await _recorder.resume();

// 停止录音
var result = await _recorder.stop();
print("录音已保存至: ${result.path}");
```

## 2. 约束条件

1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。


## 3. 版本和框架对应关系

|       | 3.7 |
|-------|:---:|
| 1.0.0 |  ✅  |

## 4. API

> [!TIP] "ohos Support" 列：yes 表示支持；no 表示不支持；partially 表示部分支持。

| Name | Description | Type | Input | Output | ohos Support |
| --- | --- | --- | --- | --- | --- |
| hasPermissions | 检查是否已获得录音权限 | Property | 无 | Future\<bool\> | yes |
| start() | 开始录音 | Function | 无 | Future\<void\> | yes |
| pause() | 暂停录音 | Function | 无 | Future\<void\> | yes |
| resume() | 恢复录音 | Function | 无 | Future\<void\> | yes |
| stop() | 停止录音 | Function | 无 | Future\<Recording\> | yes |
| current() | 获取当前录音状态和计量数据 | Function | channel(int) | Future\<Recording\> | yes |

## 5. 开源协议

本项目基于 [MIT License](LICENSE) 开源。

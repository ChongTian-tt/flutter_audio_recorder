<h1 align="center">flutter_audio_recorder</h1>

本项目基于 [flutter_audio_recorder](https://github.com/shadow-app/flutter_audio_recorder) 开发。

## 简介

`flutter_audio_recorder` 是一个 Flutter 录音插件，提供录音初始化、开始、暂停、恢复、停止、状态查询与音频电平计量能力，适用于 OpenHarmony Flutter 应用语音采集场景。

## 下载安装

进入到工程目录并在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  flutter_audio_recorder:
    git:
      url: https://gitcode.com/org/OpenHarmony-Flutter/flutter_audio_recorder
      ref: master
```

执行命令

```bash
flutter pub get
```

> TAG 命名规则：`原库版本-ohos-版本号-betax`，不同 TAG 之间的变更详见 `OHOSCHANGELOG.md`。

| Flutter 框架版本 | TAG 名称 | 备注 |
| ---------------- | -------- | ---- |
| 3.7.12-ohos-1.0.6 | 0.5.5-ohos-1.0.0 |  |

## 约束与限制

### 兼容性

在以下版本中已测试通过：

1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25;

### 权限要求

打开 `entry/src/main/module.json5`，添加：

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

## 使用示例

以下片段是最简单的使用方式：

```dart
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';

Future<void> simpleRecordDemo() async {
  // 1. 检查并申请权限
  final bool hasPermission = await FlutterAudioRecorder.hasPermissions;
  if (!hasPermission) {
    return;
  }

  // 2. 初始化录音器
  final FlutterAudioRecorder recorder = FlutterAudioRecorder(
    'file_path.wav',
    audioFormat: AudioFormat.WAV,
  );
  await recorder.initialized;

  // 3. 开始录音
  await recorder.start();

  // 4. 停止录音并输出结果
  final Recording result = await recorder.stop();
  print('录音文件：${result.path}');
}
```

## 使用说明

### 1. 权限检查

```dart
final bool hasPermission = await FlutterAudioRecorder.hasPermissions;
```

### 2. 初始化录音器

```dart
final FlutterAudioRecorder recorder = FlutterAudioRecorder(
  'file_path.m4a',
  audioFormat: AudioFormat.AAC,
  sampleRate: 16000,
);
await recorder.initialized;
```

### 3. 录音生命周期

```dart
await recorder.start();
await recorder.pause();
await recorder.resume();
final Recording result = await recorder.stop();
```

### 4. 获取当前状态

```dart
final Recording current = await recorder.current(channel: 0);
```

## 接口说明

### API

> [!TIP] `ohos Support` 列：`yes` 表示 OpenHarmony 平台支持，`no` 表示不支持，`partially` 表示部分支持。

| Name | Description | Type | Input | Output | ohos Support |
| --- | --- | --- | --- | --- | --- |
| `initialized` | 获取初始化 Future | Property | 无 | `Future` | yes |
| `recording` | 获取当前录音对象 | Property | 无 | `Recording` | yes |
| `hasPermissions` | 检查并请求录音权限 | Property | 无 | `Future<bool>` | yes |
| `init()` | 录音器初始化逻辑（构造流程中的初始化能力） | Function | `String path, AudioFormat audioFormat, int sampleRate` | `Future` | yes |
| `start()` | 开始录音 | Function | 无 | `Future<void>` | yes |
| `pause()` | 暂停录音 | Function | 无 | `Future<void>` | yes |
| `resume()` | 恢复录音 | Function | 无 | `Future<void>` | yes |
| `stop()` | 停止录音并返回结果 | Function | 无 | `Future<Recording>` | yes |
| `current()` | 获取当前录音状态与计量数据 | Function | `channel(int)` | `Future<Recording>` | yes |

## 遗留问题

无。

## 其他

无。

## 目录结构

```text
|---- flutter_audio_recorder
|     |---- android                      # Android 适配代码
|     |---- example                      # 多平台示例应用
|           |---- lib                    # 示例 Dart 代码
|           |---- ohos                   # 鸿蒙示例工程
|     |---- ios                          # iOS 适配代码
|     |---- lib                          # Dart 入口与接口定义
|     |---- ohos                         # 鸿蒙插件实现
|     |---- test                         # 单元测试
|     |---- README.OpenHarmony_CN.md     # 鸿蒙中文文档
|     |---- README.OpenHarmony.md        # 鸿蒙英文文档
|     |---- pubspec.yaml                 # 插件配置
```

## 贡献代码

使用过程中发现任何问题都可以提 [Issue](https://gitcode.com/org/OpenHarmony-Flutter/fluttertpc_flutter_audio_recorder/issues) ，当然，也非常欢迎发 [PR](https://gitcode.com/org/OpenHarmony-Flutter/fluttertpc_flutter_audio_recorder/pulls) 共建。

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。

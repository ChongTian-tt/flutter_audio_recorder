# Flutter flutter_audio_recorder 接口规格说明

## 1. 三方库概述

| 字段 | 值 |
|------|----|
| 包名 | `flutter_audio_recorder` |
| 版本 | `0.5.5` |
| 描述 | Flutter Audio Record Plugin that supports Record Pause Resume Stop and provide access to audio level metering properties average power peak power. |
| 入口文件 | `lib/flutter_audio_recorder.dart` |

## 2. 入口文件与分析范围

- 入口文件：`lib/flutter_audio_recorder.dart`
- 导出方式：该入口文件直接定义对外接口，无 `export` 转发链
- 分析文件列表：
  - `lib/flutter_audio_recorder.dart`

## 3. 类规格说明

### 3.1 FlutterAudioRecorder

| 项目 | 规格 |
|------|------|
| 类型 | Class |
| 类名 | `FlutterAudioRecorder` |
| 继承/实现 | - |
| 功能描述 | Audio Recorder Plugin |

#### 构造函数

| 名称 | 参数 | 返回类型 | 描述 |
|------|------|----------|------|
| `FlutterAudioRecorder` | `String path, {AudioFormat audioFormat, int sampleRate = 16000}` | `FlutterAudioRecorder` | 创建录音器实例并触发初始化 |

#### 公开实例成员

| 名称 | 类型 | 参数 | 返回类型 | 描述 |
|------|------|------|----------|------|
| `init` | Method | `String path, {AudioFormat audioFormat, int sampleRate = 16000}` | `Future` | 初始化录音器（构造流程中的初始化能力） |
| `start` | Method | - | `Future` | 启动录音 |
| `pause` | Method | - | `Future` | 暂停录音 |
| `resume` | Method | - | `Future` | 恢复录音 |
| `stop` | Method | - | `Future<Recording>` | 停止录音并返回结果 |
| `current` | Method | `{int channel = 0}` | `Future<Recording>` | 获取当前录音状态 |

#### 公开静态成员

| 名称 | 类型 | 参数 | 返回类型 | 描述 |
|------|------|------|----------|------|
| `hasPermissions` | Getter | - | `Future<bool>` | 获取录音权限状态（必要时触发授权） |

### 3.2 Recording

| 项目 | 规格 |
|------|------|
| 类型 | Class |
| 类名 | `Recording` |
| 继承/实现 | - |
| 功能描述 | Recording Object - represent a recording file |

#### 公开属性

| 名称 | 类型 | 修饰 | 描述 |
|------|------|------|------|
| `path` | `String` | Field | 录音文件路径 |
| `extension` | `String` | Field | 扩展名 |
| `duration` | `Duration` | Field | 录音时长 |
| `audioFormat` | `AudioFormat` | Field | 音频格式 |
| `metering` | `AudioMetering` | Field | 电平计量信息 |
| `status` | `RecordingStatus` | Field | 录音状态 |

### 3.3 AudioMetering

| 项目 | 规格 |
|------|------|
| 类型 | Class |
| 类名 | `AudioMetering` |
| 继承/实现 | - |
| 功能描述 | Audio Metering Level - describe the metering level of microphone when recording |

#### 构造函数

| 名称 | 参数 | 返回类型 | 描述 |
|------|------|----------|------|
| `AudioMetering` | `{this.peakPower, this.averagePower, this.isMeteringEnabled}` | `AudioMetering` | 创建计量对象 |

#### 公开属性

| 名称 | 类型 | 修饰 | 描述 |
|------|------|------|------|
| `peakPower` | `double` | Field | 峰值电平 |
| `averagePower` | `double` | Field | 平均电平 |
| `isMeteringEnabled` | `bool` | Field | 是否开启计量 |

## 4. 枚举规格说明

| 枚举名 | 枚举值 | 功能描述 |
|--------|--------|----------|
| `RecordingStatus` | `Unset`, `Initialized`, `Recording`, `Paused`, `Stopped` | 表示录音生命周期状态 |
| `AudioFormat` | `AAC`, `WAV` | 表示录音格式 |

## 5. 函数规格说明

无对外导出的顶层函数。

## 6. 类型别名规格说明

无对外导出的 `typedef`。

## 7. 变量与常量规格说明

无对外导出的顶层变量/常量。

## 8. 扩展规格说明

无对外导出的 `extension`。

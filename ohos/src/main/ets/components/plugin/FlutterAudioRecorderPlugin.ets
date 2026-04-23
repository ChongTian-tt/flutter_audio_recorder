/*
 * Copyright (C) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 *
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  AbilityAware,
  AbilityPluginBinding,
  Log,
} from '@ohos/flutter_ohos';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import {
  AAC_CONTAINER_SUPPORT_API_LEVEL,
  AAC_FORMAT,
  AUDIO_FORMATS,
  ENCODED_METERING_INTERVAL_MS,
  RECORDER_BPP,
  RecorderFormat,
  TAG,
} from './RecorderConstants.js';

/** FlutterAudioRecorderPlugin **/
export default class FlutterAudioRecorderPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;

  // WAV 录音模式下使用的 AudioCapturer 相关状态。
  private audioCapturer: audio.AudioCapturer | null = null;
  private sampleRate: number = 16000;
  private filePath: string = '';
  private extension: string = '';
  private status: string = 'unset';
  private peakPower: number = -120;
  private averagePower: number = -120;
  private dataSize: number = 0;
  private tempFd: number = -1;
  private encodedOutputFd: number = -1;
  private isCapturing: boolean = false;
  private readLoopDone: Promise<void> | null = null;

  // AAC/M4A 录音模式下使用的 AVRecorder 相关状态。
  private avRecorder: media.AVRecorder | null = null;
  private currentFormat: RecorderFormat | null = null;
  private elapsedDurationMs: number = 0;
  private startedAtMs: number = 0;
  private lastEncodedMeteringAtMs: number = 0;

  getUniqueClassName(): string {
    return 'FlutterAudioRecorderPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'flutter_audio_recorder');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context as common.UIAbilityContext;
  }

  onDetachedFromAbility(): void {
    this.context = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'hasPermissions':
        this.handleHasPermissions(result);
        break;
      case 'init':
        this.handleInit(call, result);
        break;
      case 'start':
        this.handleStart(result);
        break;
      case 'pause':
        this.handlePause(result);
        break;
      case 'resume':
        this.handleResume(result);
        break;
      case 'current':
        this.handleCurrent(result);
        break;
      case 'stop':
        this.handleStop(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * 检查麦克风权限，并在宿主能力可用时发起权限申请。
   * @param result Flutter 方法通道返回结果对象，用于回传权限检查结果。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async handleHasPermissions(result: MethodResult): Promise<void> {
    try {
      Log.i(TAG, `hasPermission start`)
      let permission: Permissions = 'ohos.permission.MICROPHONE';
      let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      // 查询权限前先解析当前应用的访问令牌。
      let bundleInfo: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      let tokenId: number = bundleInfo.appInfo.accessTokenId;
      let grantStatus: abilityAccessCtrl.GrantStatus =
        atManager.checkAccessTokenSync(tokenId, permission);

      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        result.success(true);
        return;
      }

      // 运行时权限申请依赖 UIAbilityContext。
      if (this.context != null) {
        let reqResult =
          await atManager.requestPermissionsFromUser(this.context, [permission]);
        let granted: boolean = reqResult.authResults[0] === 0;
        result.success(granted);
      } else {
        Log.e(TAG, 'No UIAbilityContext for permission request');
        result.success(false);
      }
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'hasPermissions error: ' + error.message);
      result.success(false);
    }
  }

  /**
   * 根据请求的文件路径和音频格式初始化录音器。
   * @param call Flutter 方法通道调用对象，包含路径、扩展名和采样率参数。
   * @param result Flutter 方法通道返回结果对象，用于回传初始化结果。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async handleInit(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      // 准备新的录音会话前，先释放上一轮遗留资源。
      await this.releaseRecorder();

      let argsMap: Map<string, Object> = call.args as Map<string, Object>;
      this.sampleRate = Number(argsMap.get('sampleRate'));
      this.filePath = String(argsMap.get('path'));
      this.extension = String(argsMap.get('extension'));

      if (this.extension.toLowerCase() === '.aac' && !this.isAacContainerSupported()) {
        result.error(
          'unsupported_api_level',
          `.aac recording requires API ${AAC_CONTAINER_SUPPORT_API_LEVEL}+, current sdkApiVersion=${deviceInfo.sdkApiVersion}`,
          null
        );
        return;
      }

      // 将请求的扩展名解析为内部录音格式配置。
      const formatConfig = this.resolveRecorderFormat(this.extension);
      if (!formatConfig) {
        result.error('unsupported_format', `Unsupported audio format: ${this.extension}`, null);
        return;
      }

      this.currentFormat = formatConfig;
      this.extension = formatConfig.extension;
      this.filePath = this.resolveOutputPath(this.filePath, this.extension);
      // 按当前会话的格式准备 WAV 或 AAC 录音实现。
      if (formatConfig.kind === 'wav') {
        await this.initWAVFormat();
      } else {
        await this.initAACFormat();
      }

      this.status = 'initialized';

      result.success(this.buildRecordingResult(this.filePath));
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'init error: ' + error.message);
      result.error('init_error', error.message, null);
    }
  }

  /**
   * 创建用于 WAV 录音的 AudioCapturer 实例。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async initWAVFormat(): Promise<void> {
    if (this.currentFormat?.kind !== 'wav') {
      throw new Error('Not a WAV format');
    }

    // WAV 模式先写入原始 PCM 数据，停止时再补齐 WAV 头。
    let audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: this.mapSamplingRate(this.sampleRate),
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
    };

    let audioCapturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0,
    };

    let audioCapturerOptions: audio.AudioCapturerOptions = {
      streamInfo: audioStreamInfo,
      capturerInfo: audioCapturerInfo,
    };

    this.audioCapturer = await audio.createAudioCapturer(audioCapturerOptions);
  }

  /**
   * 创建并准备 AAC 录音所需的 AVRecorder 实例。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async initAACFormat(): Promise<void> {
    if (!this.currentFormat || this.currentFormat.kind !== 'encoded' || !this.currentFormat.codec || !this.currentFormat.fileFormat) {
      throw new Error('Not an encoded audio format');
    }

    try {
      const normalizedSampleRate: number = this.normalizeEncodedSampleRate(this.currentFormat, this.sampleRate);
      if (normalizedSampleRate !== this.sampleRate) {
        Log.w(TAG, `sampleRate ${this.sampleRate} is not supported by ${this.extension}, fallback to ${normalizedSampleRate}`);
        this.sampleRate = normalizedSampleRate;
      }

      // 使用按容器区分后的编码参数，使输出文件与扩展名保持一致。
      const audioProfile: media.AVRecorderProfile = {
        audioBitrate: this.currentFormat.audioBitrate ?? 128000,
        audioChannels: this.currentFormat.audioChannels ?? 1,
        audioCodec: this.currentFormat.codec,
        audioSampleRate: this.sampleRate,
        fileFormat: this.currentFormat.fileFormat,
      };

      const recorderConfig: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: audioProfile,
        url: this.openEncodedOutputUrl(),
      };

      this.avRecorder = await media.createAVRecorder();
      await this.avRecorder.prepare(recorderConfig);
    } catch (e) {
      this.closeEncodedOutputFd();
      const error: BusinessError = e as BusinessError;
      throw new Error(error.message);
    }
  }

  /**
   * 在当前生命周期状态合法时启动录音器。
   * @param result Flutter 方法通道返回结果对象，用于回传启动结果。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async handleStart(result: MethodResult): Promise<void> {
    try {
      if (this.status !== 'initialized') {
        result.error('invalid_state', 'Recorder not initialized', null);
        return;
      }

      this.status = 'recording';
      this.markRecordingStarted();

      // 按当前格式分派到对应的底层录音实现。
      if (this.currentFormat?.kind === 'wav') {
        await this.startWAVRecording();
      } else {
        await this.startAACRecording();
      }

      result.success(null);
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'start error: ' + error.message);
      result.error('start_error', error.message, null);
    }
  }

  /**
   * 通过创建临时 PCM 文件并启动读取循环来开始 WAV 录音。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async startWAVRecording(): Promise<void> {
    if (this.audioCapturer == null || this.currentFormat?.kind !== 'wav') {
      throw new Error('WAV format not properly initialized');
    }

    try {
      // 原始 PCM 先写入临时文件，停止时再转换为 WAV 文件。
      const tempPath: string = this.getTempFilename();
      const tempFileObj = fileIo.openSync(tempPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      this.tempFd = tempFileObj.fd;

      this.isCapturing = true;
      await this.audioCapturer.start();
      this.readLoopDone = this.startReadLoop();
    } catch (e) {
      const error: BusinessError = e as BusinessError;
      throw new Error(error.message);
    }
  }

  /**
   * 使用已准备好的 AVRecorder 启动 AAC 录音。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async startAACRecording(): Promise<void> {
    if (this.avRecorder == null) {
      throw new Error('Encoded audio format not properly initialized');
    }

    try {
      this.isCapturing = true;
      await this.avRecorder.start();
    } catch (e) {
      const error: BusinessError = e as BusinessError;
      throw new Error(error.message);
    }
  }

  /**
   * 在 WAV 录音期间持续从 AudioCapturer 读取 PCM 缓冲区。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async startReadLoop(): Promise<void> {
    if (this.audioCapturer == null) {
      return;
    }

    try {
      let bufferSize: number = await this.audioCapturer.getBufferSize();

      while (this.isCapturing && this.status === 'recording') {
        try {
          // 读取一段 PCM 数据，更新电平后追加到临时文件中。
          let buffer: ArrayBuffer = await this.audioCapturer.read(bufferSize, true);
          if (!this.isCapturing || this.status !== 'recording') {
            break;
          }

          this.dataSize += buffer.byteLength;
          this.updatePowers(buffer);

          if (this.tempFd >= 0) {
            fileIo.writeSync(this.tempFd, buffer);
          }
        } catch (e) {
          if (this.isCapturing && this.status === 'recording') {
            let error: BusinessError = e as BusinessError;
            Log.e(TAG, 'read error: ' + error.message);
          }
          break;
        }
      }
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'readLoop error: ' + error.message);
    }
  }

  /**
   * 暂停当前录音会话，并冻结当前电平值。
   * @param result Flutter 方法通道返回结果对象，用于回传暂停结果。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async handlePause(result: MethodResult): Promise<void> {
    try {
      if (this.status !== 'recording') {
        result.error('invalid_state', 'Cannot pause when not recording', null);
        return;
      }

      this.isCapturing = false;
      this.status = 'paused';
      this.peakPower = -120;
      this.averagePower = -120;

      // 暂停当前使用的底层录音实现，并等待挂起任务结束。
      if (this.currentFormat?.kind === 'wav') {
        if (this.audioCapturer != null) {
          await this.audioCapturer.stop();
        }
        
        // 等待读取循环完全退出，避免文件仍在写入。
        if (this.readLoopDone) {
          await this.readLoopDone;
          this.readLoopDone = null;
        }
      } else {
        if (this.avRecorder != null) {
          this.captureElapsedDuration();
          await this.avRecorder.pause();
        }
      }

      result.success(null);
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'pause error: ' + error.message);
      result.error('pause_error', error.message, null);
    }
  }

  /**
   * 使用当前底层录音实现恢复已暂停的录音会话。
   * @param result Flutter 方法通道返回结果对象，用于回传恢复结果。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async handleResume(result: MethodResult): Promise<void> {
    try {
      if (this.status !== 'paused') {
        result.error('invalid_state', 'Cannot resume when not paused', null);
        return;
      }

      this.status = 'recording';
      this.isCapturing = true;
      this.markRecordingStarted();

      // 按当前录音格式恢复对应的底层实现。
      if (this.currentFormat?.kind === 'wav') {
        if (this.audioCapturer == null) {
          throw new Error('Audio capturer not initialized');
        }

        await this.audioCapturer.start();
        this.readLoopDone = this.startReadLoop();
      } else {
        if (this.avRecorder == null) {
          throw new Error('AVRecorder not initialized');
        }
        
        await this.avRecorder.resume();
      }

      result.success(null);
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'resume error: ' + error.message);
      result.error('resume_error', error.message, null);
    }
  }

  /**
   * 返回 Dart 轮询接口使用的最新录音快照。
   * @param result Flutter 方法通道返回结果对象，用于回传当前录音快照。
   * @returns void，无直接返回值。
   */
  private async handleCurrent(result: MethodResult): Promise<void> {
    if (this.currentFormat?.kind === 'encoded' && this.status === 'recording') {
      await this.updateEncodedPowers();
    }

    result.success(this.buildRecordingResult(this.getCurrentOutputPath()));
  }

  /**
   * 停止当前录音器，构建最终返回结果，并释放相关资源。
   * @param result Flutter 方法通道返回结果对象，用于回传停止后的录音结果。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async handleStop(result: MethodResult): Promise<void> {
    try {
      if (this.status === 'stopped') {
        result.success(null);
        return;
      }

      this.isCapturing = false;
      this.status = 'stopped';

      // 停止当前底层录音实现，并完成格式相关的收尾处理。
      if (this.currentFormat?.kind === 'wav') {
        await this.stopWAVRecording();
      } else {
        await this.stopAACRecording();
      }

      // 在清空录音器状态前，先构建最终返回结果。
      const currentResult: Map<string, Object> = this.buildRecordingResult(this.filePath);

      // 释放本次录音会话占用的资源。
      await this.releaseRecorder();

      result.success(currentResult);
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'stop error: ' + error.message);
      result.error('stop_error', error.message, null);
    }
  }

  /**
   * 停止 WAV 采集，刷写临时 PCM 文件，并转换为最终 WAV 文件。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async stopWAVRecording(): Promise<void> {
    // 先停止 AudioCapturer，让读取循环能够退出。
    if (this.audioCapturer != null) {
      try {
        await this.audioCapturer.stop();
      } catch (e) {
        // 可能已经在暂停逻辑中提前停止。
      }
    }

    // 等待读取循环完全结束，确保缓存数据全部落盘。
    if (this.readLoopDone) {
      await this.readLoopDone;
      this.readLoopDone = null;
    }

    // 读取结束后再关闭临时文件句柄，避免写入竞争。
    if (this.tempFd >= 0) {
      try {
        fileIo.closeSync(this.tempFd);
      } catch (e) {
        Log.w(TAG, 'Failed to close temp file descriptor during stop');
      }
      this.tempFd = -1;
    }

    // 给采集到的 PCM 数据补上 WAV 头，生成最终输出文件。
    if (this.fileExists(this.getTempFilename())) {
      this.copyWaveFile(this.getTempFilename(), this.filePath);
      this.deleteTempFile();
    }
  }

  /**
   * 停止并释放 AAC 录音使用的 AVRecorder。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async stopAACRecording(): Promise<void> {
    if (this.avRecorder != null) {
      try {
        // 释放前先累积最后一段录音时长。
        this.captureElapsedDuration();
        await this.avRecorder.stop();
        await this.avRecorder.release();
        this.avRecorder = null;
      } catch (e) {
        let error: BusinessError = e as BusinessError;
        Log.e(TAG, 'AVRecorder stop error: ' + error.message);
      } finally {
        this.closeEncodedOutputFd();
      }
    }

    this.finalizeEncodedRecording();
  }

  /**
   * 清空内存中的录音状态，供下一次会话复用。
   * @returns void，无直接返回值。
   */
  private resetRecorder(): void {
    this.audioCapturer = null;
    this.avRecorder = null;
    this.currentFormat = null;
    this.filePath = '';
    this.extension = '';
    this.peakPower = -120;
    this.averagePower = -120;
    this.dataSize = 0;
    this.tempFd = -1;
    this.encodedOutputFd = -1;
    this.isCapturing = false;
    this.readLoopDone = null;
    this.status = 'unset';
    this.elapsedDurationMs = 0;
    this.startedAtMs = 0;
    this.lastEncodedMeteringAtMs = 0;
  }

  /**
   * 释放录音资源，并移除未完成的临时文件痕迹。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async releaseRecorder(): Promise<void> {
    // 如果当前是 WAV 录音，则释放 AudioCapturer。
    if (this.audioCapturer != null) {
      try {
        await this.audioCapturer.release();
      } catch (e) {
        Log.w(TAG, 'AudioCapturer release warning: ' + (e as BusinessError).message);
      }
      this.audioCapturer = null;
    }

    // 如果当前是 AAC/M4A 录音，则释放 AVRecorder。
    if (this.avRecorder != null) {
      try {
        await this.avRecorder.release();
      } catch (e) {
        Log.w(TAG, 'AVRecorder release warning: ' + (e as BusinessError).message);
      }
      this.avRecorder = null;
    }

    // 清理临时文件描述符，避免句柄泄漏。
    if (this.tempFd >= 0) {
      try {
        fileIo.closeSync(this.tempFd);
      } catch (e) {
        Log.w(TAG, 'Failed to close temp file descriptor');
      }
      this.tempFd = -1;
    }

    this.closeEncodedOutputFd();

    // 清理临时 PCM 文件。
    this.deleteTempFile();

    this.resetRecorder();
  }

  /**
   * 返回 WAV 录音过程中使用的临时 PCM 文件路径。
   * @returns string，临时 PCM 文件完整路径。
   */
  private getTempFilename(): string {
    return this.filePath + '.temp';
  }

  /**
   * 返回当前状态下应该暴露给 Dart 的输出路径。
   * @returns string，录音中返回临时文件路径，停止后返回最终路径。
   */
  private getCurrentOutputPath(): string {
    if (this.status === 'stopped') {
      return this.filePath;
    }
    return this.getTempFilename();
  }

  /**
   * 构建 Dart 侧消费的统一录音快照对象。
   * @param path 当前应返回的录音文件路径。
   * @returns Map<string, Object>，录音快照。
   */
  private buildRecordingResult(path: string): Map<string, Object> {
    let recordingResult: Map<string, Object> = new Map();
    recordingResult.set('duration', Math.floor(this.getDuration()) * 1000);
    recordingResult.set('path', path);
    recordingResult.set('audioFormat', this.extension);
    recordingResult.set('peakPower', this.peakPower);
    recordingResult.set('averagePower', this.averagePower);
    recordingResult.set('isMeteringEnabled', true);
    recordingResult.set('status', this.status);
    return recordingResult;
  }

  /**
   * 用规范化扩展名替换输出路径末尾的原始扩展名，保证容器与文件名一致。
   * @param originalPath Dart 侧传入的原始输出路径。
   * @param resolvedExtension 当前录音格式最终采用的扩展名。
   * @returns string，替换后的最终输出路径。
   */
  private resolveOutputPath(originalPath: string, resolvedExtension: string): string {
    const lastDotIndex: number = originalPath.lastIndexOf('.');
    const lastSeparatorIndex: number = Math.max(originalPath.lastIndexOf('/'), originalPath.lastIndexOf('\\'));
    if (lastDotIndex > lastSeparatorIndex) {
      return originalPath.substring(0, lastDotIndex) + resolvedExtension;
    }
    return originalPath + resolvedExtension;
  }

  /**
   * 按扩展名和设备 API 版本解析录音容器配置。
   * @param requestedExtension Dart 侧请求的文件扩展名。
   * @returns RecorderFormat | null，可用时返回容器配置，否则返回 null。
   */
  private resolveRecorderFormat(requestedExtension: string): RecorderFormat | null {
    const normalizedExtension: string = requestedExtension.toLowerCase();
    if (normalizedExtension === '.aac') {
      if (!this.isAacContainerSupported()) {
        Log.w(TAG,
          `.aac container requires API ${AAC_CONTAINER_SUPPORT_API_LEVEL}+, current sdkApiVersion=${deviceInfo.sdkApiVersion}`);
        return null;
      }
      return AAC_FORMAT;
    }

    return AUDIO_FORMATS.get(normalizedExtension) ?? null;
  }

  /**
   * 为编码录音创建输出文件并返回 AVRecorder 需要的 fd URL。
   * @returns string，可用于 AVRecorderConfig.url 的 fd:// 路径。
   */
  private openEncodedOutputUrl(): string {
    this.closeEncodedOutputFd();
    try {
      const outputFile = fileIo.openSync(this.getTempFilename(),
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      this.encodedOutputFd = outputFile.fd;
      return `fd://${this.encodedOutputFd}`;
    } catch (e) {
      const error: BusinessError = e as BusinessError;
      throw new Error(error.message);
    }
  }

  /**
   * 关闭编码录音使用的输出文件描述符。
   * @returns void，无直接返回值。
   */
  private closeEncodedOutputFd(): void {
    if (this.encodedOutputFd < 0) {
      return;
    }

    try {
      fileIo.closeSync(this.encodedOutputFd);
    } catch (e) {
      Log.w(TAG, 'Failed to close encoded output file descriptor');
    }
    this.encodedOutputFd = -1;
  }

  /**
   * 判断当前设备是否支持 AAC ADTS 容器录音。
   * @returns boolean，true 表示 API 版本满足要求。
   */
  private isAacContainerSupported(): boolean {
    return deviceInfo.sdkApiVersion >= AAC_CONTAINER_SUPPORT_API_LEVEL;
  }

  /**
   * 更新编码录音格式的平均功率和峰值功率。
   * @returns Promise<void>，异步执行完成后无直接返回值。
   */
  private async updateEncodedPowers(): Promise<void> {
    if (this.avRecorder == null) {
      return;
    }

    const now: number = Date.now();
    if (now - this.lastEncodedMeteringAtMs < ENCODED_METERING_INTERVAL_MS) {
      return;
    }

    try {
      const maxAmplitude: number = await this.avRecorder.getAudioCapturerMaxAmplitude();
      this.lastEncodedMeteringAtMs = now;
      const peakPower: number = this.amplitudeToPower(maxAmplitude);
      if (peakPower <= -120) {
        this.peakPower = -120;
        this.averagePower = -120;
        return;
      }

      this.peakPower = peakPower;
      if (this.averagePower <= -120) {
        this.averagePower = peakPower;
      } else {
        this.averagePower = this.averagePower * 0.8 + peakPower * 0.2;
      }
    } catch (e) {
      const error: BusinessError = e as BusinessError;
      Log.w(TAG, 'getAudioCapturerMaxAmplitude warning: ' + error.message);
    }
  }

  /**
   * 将编码录音的临时文件拷贝为最终输出文件。
   * @returns void，无直接返回值。
   */
  private finalizeEncodedRecording(): void {
    const tempFilename: string = this.getTempFilename();
    if (!this.fileExists(tempFilename)) {
      return;
    }

    try {
      fileIo.copyFileSync(tempFilename, this.filePath);
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'finalizeEncodedRecording error: ' + error.message);
    }
    this.deleteTempFile();
  }

  /**
   * 将请求的采样率调整到当前编码格式在官方文档中支持的取值范围内。
   * @param format 当前编码格式配置。
   * @param requestedSampleRate Dart 侧请求的采样率。
   * @returns number，可直接用于 AVRecorder 的采样率。
   */
  private normalizeEncodedSampleRate(format: RecorderFormat, requestedSampleRate: number): number {
    const supportedSampleRates: Array<number> = [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000, 64000, 88200, 96000];
    if (supportedSampleRates.indexOf(requestedSampleRate) >= 0) {
      return requestedSampleRate;
    }
    return 16000;
  }

  /**
   * 计算当前录音时长，单位为秒。
   * @returns number，当前录音时长，单位秒。
   */
  private getDuration(): number {
    if (this.currentFormat?.kind === 'wav') {
      // WAV 模式根据 PCM 数据大小估算时长。
      return this.dataSize / (this.sampleRate * 2 * 1);
    } else {
      const durationMs = this.elapsedDurationMs + this.getCurrentRunningDurationMs();
      return durationMs / 1000;
    }
  }

  /**
   * 将当前时刻标记为一段录音片段的开始时间。
   * @returns void，无直接返回值。
   */
  private markRecordingStarted(): void {
    this.startedAtMs = Date.now();
  }

  /**
   * 将当前正在运行的录音片段累加到总时长中。
   * @returns void，无直接返回值。
   */
  private captureElapsedDuration(): void {
    if (this.startedAtMs > 0) {
      this.elapsedDurationMs += Date.now() - this.startedAtMs;
      this.startedAtMs = 0;
    }
  }

  /**
   * 返回尚未累加进总时长的当前活跃录音片段时长。
   * @returns number，当前活跃录音片段的毫秒时长。
   */
  private getCurrentRunningDurationMs(): number {
    if (this.startedAtMs > 0 && this.status === 'recording') {
      return Date.now() - this.startedAtMs;
    }
    return 0;
  }

  /**
   * 将振幅值转换为接近 dBFS 的功率值。
   * @param amplitude 当前区间内采集到的最大振幅。
   * @returns number，转换后的功率值。
   */
  private amplitudeToPower(amplitude: number): number {
    if (amplitude <= 0) {
      return -120;
    }

    const normalizedAmplitude: number = amplitude > 1 ? amplitude / 32768.0 : amplitude;
    if (normalizedAmplitude <= 0) {
      return -120;
    }

    const iOSFactor: number = 0.25;
    return 20 * Math.log(normalizedAmplitude) * iOSFactor;
  }

  /**
   * 根据一段 PCM 音频数据更新平均功率和峰值功率。
   * @param buffer 本次读取到的 PCM 音频缓冲区。
   * @returns void，无直接返回值。
   */
  private updatePowers(buffer: ArrayBuffer): void {
    let dataView: DataView = new DataView(buffer);
    let sampleCount: number = Math.floor(buffer.byteLength / 2);
    if (sampleCount === 0) {
      return;
    }

    // 计算 RMS 作为平均功率基础，同时统计最大绝对振幅作为峰值基础。
    let sumSquares: number = 0;
    let maxAbsValue: number = 0;

    for (let i = 0; i < sampleCount; i++) {
      let sample: number = dataView.getInt16(i * 2, true);
      sumSquares += sample * sample;
      let absValue: number = Math.abs(sample);
      if (absValue > maxAbsValue) {
        maxAbsValue = absValue;
      }
    }

    let rms: number = Math.sqrt(sumSquares / sampleCount);

    if (rms === 0 || this.status !== 'recording') {
      this.averagePower = -120;
      this.peakPower = -120;
    } else {
      // 将振幅转换为接近 dBFS 的值，供 Dart 侧电平模型使用。
      let iOSFactor: number = 0.25;
      this.averagePower = 20 * Math.log(rms / 32768.0) * iOSFactor;
      this.peakPower = 20 * Math.log(maxAbsValue / 32768.0) * iOSFactor;
    }
  }

  /**
   * 为采集到的 PCM 文件补上 WAV 头，并写出最终输出文件。
   * @param inFilename 输入的临时 PCM 文件路径。
   * @param outFilename 输出的最终 WAV 文件路径。
   * @returns void，无直接返回值。
   */
  private copyWaveFile(inFilename: string, outFilename: string): void {
    try {
      let inFile = fileIo.openSync(inFilename, fileIo.OpenMode.READ_ONLY);
      let stat = fileIo.statSync(inFilename);
      let totalAudioLen: number = stat.size;
      let totalDataLen: number = totalAudioLen + 36;

      let outFile = fileIo.openSync(outFilename,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);

      // 先写入标准 44 字节 WAV 文件头。
      let header: Uint8Array = this.createWavHeader(totalAudioLen, totalDataLen);
      fileIo.writeSync(outFile.fd, header.buffer);

      // 再把原始 PCM 数据复制到目标文件后面。
      let copyBuffer: ArrayBuffer = new ArrayBuffer(4096);
      let bytesRead: number = fileIo.readSync(inFile.fd, copyBuffer);
      while (bytesRead > 0) {
        fileIo.writeSync(outFile.fd, copyBuffer, { length: bytesRead });
        bytesRead = fileIo.readSync(inFile.fd, copyBuffer);
      }

      fileIo.closeSync(inFile.fd);
      fileIo.closeSync(outFile.fd);
    } catch (e) {
      let error: BusinessError = e as BusinessError;
      Log.e(TAG, 'copyWaveFile error: ' + error.message);
    }
  }

  /**
   * 根据当前录音参数创建标准 44 字节 WAV 文件头。
   * @param totalAudioLen 原始音频数据总长度。
   * @param totalDataLen WAV 数据块总长度。
   * @returns Uint8Array，生成好的 WAV 文件头字节数组。
   */
  private createWavHeader(totalAudioLen: number, totalDataLen: number): Uint8Array {
    let channels: number = 1;
    let byteRate: number = RECORDER_BPP * this.sampleRate * channels / 8;
    let header: Uint8Array = new Uint8Array(44);

    // RIFF 文件头。
    header[0] = 0x52;  // 'R'
    header[1] = 0x49;  // 'I'
    header[2] = 0x46;  // 'F'
    header[3] = 0x46;  // 'F'
    header[4] = totalDataLen & 0xff;
    header[5] = (totalDataLen >> 8) & 0xff;
    header[6] = (totalDataLen >> 16) & 0xff;
    header[7] = (totalDataLen >> 24) & 0xff;
    header[8] = 0x57;  // 'W'
    header[9] = 0x41;  // 'A'
    header[10] = 0x56; // 'V'
    header[11] = 0x45; // 'E'
    // fmt 数据块。
    header[12] = 0x66; // 'f'
    header[13] = 0x6D; // 'm'
    header[14] = 0x74; // 't'
    header[15] = 0x20; // ' '
    header[16] = 16;   // chunk size = 16
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
    header[20] = 1;    // PCM format
    header[21] = 0;
    header[22] = channels;
    header[23] = 0;
    header[24] = this.sampleRate & 0xff;
    header[25] = (this.sampleRate >> 8) & 0xff;
    header[26] = (this.sampleRate >> 16) & 0xff;
    header[27] = (this.sampleRate >> 24) & 0xff;
    header[28] = byteRate & 0xff;
    header[29] = (byteRate >> 8) & 0xff;
    header[30] = (byteRate >> 16) & 0xff;
    header[31] = (byteRate >> 24) & 0xff;
    header[32] = 1;    // block align
    header[33] = 0;
    header[34] = RECORDER_BPP; // bits per sample
    header[35] = 0;
    // data 数据块。
    header[36] = 0x64; // 'd'
    header[37] = 0x61; // 'a'
    header[38] = 0x74; // 't'
    header[39] = 0x61; // 'a'
    header[40] = totalAudioLen & 0xff;
    header[41] = (totalAudioLen >> 8) & 0xff;
    header[42] = (totalAudioLen >> 16) & 0xff;
    header[43] = (totalAudioLen >> 24) & 0xff;

    return header;
  }

  /**
   * 在临时 PCM 文件不再需要时将其删除。
   * @returns void，无直接返回值。
   */
  private deleteTempFile(): void {
    try {
      fileIo.unlinkSync(this.getTempFilename());
    } catch (e) {
      // 文件可能已经不存在，直接忽略即可。
    }
  }

  /**
   * 检查指定路径对应的文件当前是否存在。
   * @param path 待检查的文件路径。
   * @returns boolean，文件存在时返回 true，否则返回 false。
   */
  private fileExists(path: string): boolean {
    try {
      fileIo.statSync(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * 将数值采样率映射为 HarmonyOS 对应的枚举值。
   * @param rate 数值形式的采样率。
   * @returns audio.AudioSamplingRate，对应的 HarmonyOS 采样率枚举值。
   */
  private mapSamplingRate(rate: number): audio.AudioSamplingRate {
    switch (rate) {
      case 8000:
        return audio.AudioSamplingRate.SAMPLE_RATE_8000;
      case 11025:
        return audio.AudioSamplingRate.SAMPLE_RATE_11025;
      case 12000:
        return audio.AudioSamplingRate.SAMPLE_RATE_12000;
      case 16000:
        return audio.AudioSamplingRate.SAMPLE_RATE_16000;
      case 22050:
        return audio.AudioSamplingRate.SAMPLE_RATE_22050;
      case 24000:
        return audio.AudioSamplingRate.SAMPLE_RATE_24000;
      case 32000:
        return audio.AudioSamplingRate.SAMPLE_RATE_32000;
      case 44100:
        return audio.AudioSamplingRate.SAMPLE_RATE_44100;
      case 48000:
        return audio.AudioSamplingRate.SAMPLE_RATE_48000;
      case 64000:
        return audio.AudioSamplingRate.SAMPLE_RATE_64000;
      case 96000:
        return audio.AudioSamplingRate.SAMPLE_RATE_96000;
      default:
        return audio.AudioSamplingRate.SAMPLE_RATE_16000;
    }
  }
}
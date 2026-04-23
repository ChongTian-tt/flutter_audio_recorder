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
import { media } from '@kit.MediaKit';

export const TAG: string = '[FlutterAudioRecorder]:';
export const RECORDER_BPP: number = 16;
export const AAC_CONTAINER_SUPPORT_API_LEVEL: number = 20;
export const ENCODED_METERING_INTERVAL_MS: number = 100;

export const WAV_FORMAT: RecorderFormat = {
  kind: 'wav',
  extension: '.wav',
};

export const M4A_FORMAT: RecorderFormat = {
  kind: 'encoded',
  codec: media.CodecMimeType.AUDIO_AAC,
  fileFormat: media.ContainerFormatType.CFT_MPEG_4A,
  audioBitrate: 128000,
  audioChannels: 1,
  extension: '.m4a',
};

export const MP4_AUDIO_FORMAT: RecorderFormat = {
  kind: 'encoded',
  codec: media.CodecMimeType.AUDIO_AAC,
  fileFormat: media.ContainerFormatType.CFT_MPEG_4,
  audioBitrate: 128000,
  audioChannels: 1,
  extension: '.mp4',
};

export const AAC_FORMAT: RecorderFormat = {
  kind: 'encoded',
  codec: media.CodecMimeType.AUDIO_AAC,
  fileFormat: media.ContainerFormatType.CFT_AAC,
  audioBitrate: 128000,
  audioChannels: 1,
  extension: '.aac',
};

export interface RecorderFormat {
  kind: RecorderFormatKind;
  codec?: media.CodecMimeType;
  fileFormat?: media.ContainerFormatType;
  audioBitrate?: number;
  audioChannels?: number;
  extension: string;
}

export type RecorderFormatKind = 'wav' | 'encoded';

export const AUDIO_FORMATS: Map<string, RecorderFormat> = new Map<string, RecorderFormat>();

AUDIO_FORMATS.set('.wav', WAV_FORMAT);
AUDIO_FORMATS.set('.m4a', M4A_FORMAT);
AUDIO_FORMATS.set('.mp4', MP4_AUDIO_FORMAT);
AUDIO_FORMATS.set('.aac', AAC_FORMAT);

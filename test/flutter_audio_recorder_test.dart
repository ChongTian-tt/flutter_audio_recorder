import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('flutter_audio_recorder');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'hasPermissions':
          return true;
        case 'init':
          return <String, dynamic>{
            'status': 'initialized',
          };
        case 'start':
        case 'pause':
        case 'resume':
          return null;
        case 'current':
          return <String, dynamic>{
            'duration': 123,
            'path': '/tmp/mock.temp',
            'audioFormat': '.wav',
            'peakPower': -10.5,
            'averagePower': -20.25,
            'isMeteringEnabled': true,
            'status': 'recording',
          };
        case 'stop':
          return <String, dynamic>{
            'duration': 456,
            'path': '/tmp/mock.wav',
            'audioFormat': '.wav',
            'peakPower': -11,
            'averagePower': -22,
            'isMeteringEnabled': true,
            'status': 'stopped',
          };
        default:
          throw PlatformException(
            code: 'unimplemented',
            message: 'Method ${methodCall.method} not mocked',
          );
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  group('FlutterAudioRecorder', () {
    test('hasPermissions returns true', () async {
      final hasPermission = await FlutterAudioRecorder.hasPermissions;
      expect(hasPermission, isTrue);
    });

    test('initialized completes and sets default metering', () async {
      final recorder = FlutterAudioRecorder(null);
      await recorder.initialized;

      expect(recorder.recording, isNotNull);
      expect(recorder.recording.status, RecordingStatus.Initialized);
      expect(recorder.recording.metering, isNotNull);
      expect(recorder.recording.metering.isMeteringEnabled, isTrue);
      expect(recorder.recording.metering.averagePower, -120);
      expect(recorder.recording.metering.peakPower, -120);
    });

    test('start/pause/resume invoke corresponding channel methods', () async {
      final calls = <MethodCall>[];
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        calls.add(methodCall);
        if (methodCall.method == 'init') {
          return <String, dynamic>{'status': 'initialized'};
        }
        return null;
      });

      final recorder = FlutterAudioRecorder(null);
      await recorder.initialized;
      await recorder.start();
      await recorder.pause();
      await recorder.resume();

      expect(calls.map((c) => c.method).toList(), <String>[
        'init',
        'start',
        'pause',
        'resume',
      ]);
    });

    test('current maps response into Recording', () async {
      final recorder = FlutterAudioRecorder(null, audioFormat: AudioFormat.WAV);
      await recorder.initialized;

      final current = await recorder.current(channel: 0);

      expect(current, isNotNull);
      expect(current.status, RecordingStatus.Recording);
      expect(current.path, '/tmp/mock.temp');
      expect(current.audioFormat, AudioFormat.WAV);
      expect(current.extension, '.wav');
      expect(current.duration, const Duration(milliseconds: 123));
      expect(current.metering.isMeteringEnabled, isTrue);
      expect(current.metering.peakPower, closeTo(-10.5, 0.0001));
      expect(current.metering.averagePower, closeTo(-20.25, 0.0001));
    });

    test('stop maps response into Recording and marks stopped', () async {
      final recorder = FlutterAudioRecorder(null, audioFormat: AudioFormat.WAV);
      await recorder.initialized;

      final stopped = await recorder.stop();

      expect(stopped, isNotNull);
      expect(stopped.status, RecordingStatus.Stopped);
      expect(stopped.path, '/tmp/mock.wav');
      expect(stopped.audioFormat, AudioFormat.WAV);
      expect(stopped.extension, '.wav');
      expect(stopped.duration, const Duration(milliseconds: 456));
    });
  });
}

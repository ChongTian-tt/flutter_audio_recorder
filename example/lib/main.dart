import 'dart:async';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  SystemChrome.setEnabledSystemUIOverlays([]);
  return runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        body: SafeArea(
          child: new RecorderExample(),
        ),
      ),
    );
  }
}

class RecorderExample extends StatefulWidget {
  RecorderExample();

  @override
  State<StatefulWidget> createState() => new RecorderExampleState();
}

class RecorderExampleState extends State<RecorderExample> {
  FlutterAudioRecorder _recorder;
  Recording _current;
  RecordingStatus _currentStatus = RecordingStatus.Unset;
  Timer _recordingTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // TEMP: 手动测试不同录音格式时使用，后续可直接删除。
  static const List<String> _testExtensions = <String>[
    '.wav',
    '.m4a',
    '.aac',
    '.mp4',
  ];
  // TEMP: 当前选中的录音扩展名，后续可直接删除。
  String _selectedExtension = '.wav';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new Padding(
        padding: new EdgeInsets.all(8.0),
        child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // TEMP: 手动切换录音格式的测试入口，后续可直接删除。
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Format:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedExtension,
                    onChanged: _currentStatus == RecordingStatus.Recording ||
                            _currentStatus == RecordingStatus.Paused
                        ? null
                        : (String newValue) {
                            if (newValue == null || newValue == _selectedExtension) {
                              return;
                            }
                            setState(() {
                              _selectedExtension = newValue;
                            });
                            _init();
                          },
                    items: _testExtensions
                      .map<DropdownMenuItem<String>>((String extension) => DropdownMenuItem<String>(
                              value: extension,
                              child: Text(extension),
                            ))
                        .toList(),
                  ),
                ],
              ),
              new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        print("[FlutterAudioRecorder]:_currentStatus: $_currentStatus");
                        switch (_currentStatus) {
                          case RecordingStatus.Initialized:
                            {
                              _start();
                              break;
                            }
                          case RecordingStatus.Recording:
                            {
                              _pause();
                              break;
                            }
                          case RecordingStatus.Paused:
                            {
                              _resume();
                              break;
                            }
                          case RecordingStatus.Stopped:
                            {
                              _init();
                              break;
                            }
                          case RecordingStatus.Unset:
                            {
                              _init();
                              break;
                            }
                          default:
                            break;
                        }
                      },
                      child: _buildText(_currentStatus),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _currentStatus != RecordingStatus.Unset ? _stop : null,
                    child:
                        new Text("Stop", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.5),
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  ElevatedButton(
                    onPressed: onPlayAudio,
                    child:
                        new Text("Play", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              new Text("Status : $_currentStatus"),
              new Text('Avg Power: ${_current?.metering?.averagePower}'),
              new Text('Peak Power: ${_current?.metering?.peakPower}'),
              new Text("File path of the record: ${_current?.path}"),
              new Text("Format: ${_current?.audioFormat}"),
              new Text(
                  "isMeteringEnabled: ${_current?.metering?.isMeteringEnabled}"),
              new Text("Extension : ${_current?.extension}"),
              new Text(
                  "Audio recording duration : ${_current?.duration.toString()}")
            ]),
      ),
    );
  }

  _init() async {
    try {
      await _recordingTimer?.cancel();
      await _audioPlayer.stop();

      if (await FlutterAudioRecorder.hasPermissions) {
        String customPath = '/flutter_audio_recorder_';
        io.Directory appDocDirectory;
//        io.Directory appDocDirectory = await getApplicationDocumentsDirectory();
        if (io.Platform.isIOS || io.Platform.operatingSystem == 'ohos') {
          appDocDirectory = await getApplicationDocumentsDirectory();
        } else {
          appDocDirectory = await getExternalStorageDirectory();
        }

        // can add extension like ".mp4" ".wav" ".m4a" ".aac"
        customPath = appDocDirectory.path +
          customPath +
          DateTime.now().millisecondsSinceEpoch.toString() +
          _selectedExtension;

        // .wav <---> AudioFormat.WAV
        // .mp4 .m4a .aac <---> AudioFormat.AAC
        // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.
        _recorder = FlutterAudioRecorder(customPath);

        await _recorder.initialized;
        // after initialization
        var current = await _recorder.current(channel: 0);
        print(current);
        // should be "Initialized", if all working fine
        setState(() {
          _current = current;
          _currentStatus = current.status;
          print(_currentStatus);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: new Text("You must accept permissions")));
      }
    } catch (e) {
      print(e);
    }
  }

  _start() async {
    try {
      await _recorder.start();
      var recording = await _recorder.current(channel: 0);
      setState(() {
        _current = recording;
        _currentStatus = recording.status;
      });

      const tick = const Duration(milliseconds: 50);
      _recordingTimer?.cancel();
      _recordingTimer = new Timer.periodic(tick, (Timer t) async {
        if (_currentStatus == RecordingStatus.Stopped) {
          t.cancel();
          return;
        }

        var current = await _recorder.current(channel: 0);
        // print(current.status);
        setState(() {
          _current = current;
          _currentStatus = _current.status;
        });
      });
    } catch (e) {
      print(e);
    }
  }

  _resume() async {
    await _recorder.resume();
    var current = await _recorder.current(channel: 0);
    setState(() {
      _current = current;
      _currentStatus = current.status;
    });
  }

  _pause() async {
    await _recorder.pause();
    var current = await _recorder.current(channel: 0);
    setState(() {
      _current = current;
      _currentStatus = current.status;
    });
  }

  _stop() async {
    _recordingTimer?.cancel();
    if (_currentStatus == RecordingStatus.Initialized) {
      setState(() {
        _current.status = RecordingStatus.Stopped;
        _currentStatus = RecordingStatus.Stopped;
      });
      return;
    }

    var result = await _recorder.stop();
    print("Stop recording: ${result.path}");
    print("Stop recording: ${result.duration}");
    setState(() {
      _current = result;
      _currentStatus = _current.status;
    });
  }

  Widget _buildText(RecordingStatus status) {
    var text = "";
    print("[FlutterAudioRecorder]:Status: $status");
    switch (_currentStatus) {
      case RecordingStatus.Unset:
        {
          text = 'Init';
          break;
        }
      case RecordingStatus.Initialized:
        {
          text = 'Start';
          break;
        }
      case RecordingStatus.Recording:
        {
          text = 'Pause';
          break;
        }
      case RecordingStatus.Paused:
        {
          text = 'Resume';
          break;
        }
      case RecordingStatus.Stopped:
        {
          text = 'Init';
          break;
        }
      default:
        break;
    }
    return Text(text, style: TextStyle(color: Colors.white));
  }

  void onPlayAudio() async {
    final path = _current?.path;
    if (path == null || path.isEmpty) {
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
  }
}
